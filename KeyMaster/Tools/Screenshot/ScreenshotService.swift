import AppKit
import CoreGraphics
import Foundation
import ScreenCaptureKit

enum ScreenshotService {
    static func requestScreenCaptureAccessIfNeeded() -> Bool {
        if CGPreflightScreenCaptureAccess() {
            return true
        }

        return CGRequestScreenCaptureAccess()
    }

    static func capture(
        rect requestedRect: CGRect,
        annotations: [ScreenshotAnnotation] = [],
        from screenImage: CGImage,
        displaySize: CGSize
    ) throws -> NSImage {
        guard displaySize.width > 0, displaySize.height > 0 else {
            throw ScreenshotError.emptyCapture
        }

        let scaleX = CGFloat(screenImage.width) / displaySize.width
        let scaleY = CGFloat(screenImage.height) / displaySize.height
        let clampedRect = clamped(requestedRect, to: displaySize)
        let pixelRect = CGRect(
            x: floor(clampedRect.minX * scaleX),
            y: floor(clampedRect.minY * scaleY),
            width: ceil(clampedRect.maxX * scaleX) - floor(clampedRect.minX * scaleX),
            height: ceil(clampedRect.maxY * scaleY) - floor(clampedRect.minY * scaleY)
        )
        guard pixelRect.width > 0, pixelRect.height > 0 else {
            throw ScreenshotError.emptySelection
        }
        guard let cgImage = screenImage.cropping(to: pixelRect) else {
            throw ScreenshotError.emptyCapture
        }

        let captureRect = CGRect(
            x: pixelRect.minX / scaleX,
            y: pixelRect.minY / scaleY,
            width: pixelRect.width / scaleX,
            height: pixelRect.height / scaleY
        )
        let image = NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
        guard !annotations.isEmpty else {
            return image
        }

        return try annotatedImage(
            image,
            annotations: annotations,
            requestedRect: requestedRect,
            captureRect: captureRect
        )
    }

    static func previewImage(size: CGSize, on displayID: CGDirectDisplayID) async throws -> CGImage {
        let content = try await SCShareableContent.current
        guard let display = content.displays.first(where: { $0.displayID == displayID }) else {
            throw ScreenshotError.displayNotFound
        }

        let filter = SCContentFilter(display: display, excludingWindows: [])
        let scale = max(CGFloat(filter.pointPixelScale), 1)
        let captureRect = pixelAligned(
            clamped(CGRect(origin: .zero, size: size), to: size),
            scale: scale
        )
        let configuration = SCStreamConfiguration()
        configuration.sourceRect = captureRect
        configuration.width = max(Int((captureRect.width * scale).rounded(.toNearestOrAwayFromZero)), 1)
        configuration.height = max(Int((captureRect.height * scale).rounded(.toNearestOrAwayFromZero)), 1)
        configuration.showsCursor = false

        return try await withCheckedThrowingContinuation { continuation in
            SCScreenshotManager.captureImage(contentFilter: filter, configuration: configuration) { image, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let image else {
                    continuation.resume(throwing: ScreenshotError.emptyCapture)
                    return
                }

                continuation.resume(returning: image)
            }
        }
    }

    static func copyToPasteboard(
        _ image: NSImage,
        pasteboard: NSPasteboard = .general
    ) throws {
        guard let pngData = pngData(from: image) else {
            throw ScreenshotError.exportFailed
        }

        let tiffData = image.tiffRepresentation
        pasteboard.clearContents()
        pasteboard.declareTypes(tiffData == nil ? [.png] : [.png, .tiff], owner: nil)
        guard pasteboard.setData(pngData, forType: .png) else {
            throw ScreenshotError.exportFailed
        }
        if let tiffData {
            pasteboard.setData(tiffData, forType: .tiff)
        }
    }

    private static func clamped(_ rect: CGRect, to size: CGSize) -> CGRect {
        let minX = min(max(rect.minX, 0), size.width)
        let minY = min(max(rect.minY, 0), size.height)
        let maxX = min(max(rect.maxX, 0), size.width)
        let maxY = min(max(rect.maxY, 0), size.height)

        return CGRect(
            x: minX,
            y: minY,
            width: max(maxX - minX, 0),
            height: max(maxY - minY, 0)
        )
    }

    private static func pixelAligned(_ rect: CGRect, scale: CGFloat) -> CGRect {
        let minX = floor(rect.minX * scale) / scale
        let minY = floor(rect.minY * scale) / scale
        let maxX = ceil(rect.maxX * scale) / scale
        let maxY = ceil(rect.maxY * scale) / scale

        return CGRect(
            x: minX,
            y: minY,
            width: max(maxX - minX, 0),
            height: max(maxY - minY, 0)
        )
    }

    private static func annotatedImage(
        _ image: NSImage,
        annotations: [ScreenshotAnnotation],
        requestedRect: CGRect,
        captureRect: CGRect
    ) throws -> NSImage {
        let imageSize = image.size
        let scaleX = imageSize.width / max(captureRect.width, 1)
        let scaleY = imageSize.height / max(captureRect.height, 1)
        let lineWidth = max(max(scaleX, scaleY) * 2, 3)
        let sourceRect = CGRect(origin: .zero, size: imageSize)
        let renderedAnnotations = annotations.map {
            renderedAnnotation(
                $0,
                requestedRect: requestedRect,
                captureRect: captureRect,
                scaleX: scaleX,
                scaleY: scaleY
            )
        }

        // Rasterize immediately. Lazy drawing-handler images often fail to encode
        // PNG/TIFF for large annotated crops, so chat apps paste nothing.
        return try rasterizedImage(size: imageSize) { targetRect in
            image.draw(
                in: targetRect,
                from: sourceRect,
                operation: .copy,
                fraction: 1,
                respectFlipped: true,
                hints: nil
            )

            NSColor.systemRed.setStroke()
            renderedAnnotations.forEach { annotation in
                switch annotation {
                case .rectangle(let rect):
                    let path = NSBezierPath(rect: rect.insetBy(dx: lineWidth / 2, dy: lineWidth / 2))
                    path.lineWidth = lineWidth
                    path.stroke()
                case .text(let text):
                    drawText(text)
                }
            }
        }
    }

    private static func rasterizedImage(
        size: CGSize,
        draw: (CGRect) -> Void
    ) throws -> NSImage {
        let width = max(Int(size.width.rounded(.toNearestOrAwayFromZero)), 1)
        let height = max(Int(size.height.rounded(.toNearestOrAwayFromZero)), 1)
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            throw ScreenshotError.exportFailed
        }

        // Match NSImage(flipped: true): y = 0 is the top edge. The flipped
        // flag alone does not change the CGContext CTM, so flip it explicitly.
        context.translateBy(x: 0, y: CGFloat(height))
        context.scaleBy(x: 1, y: -1)

        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: true)
        defer {
            NSGraphicsContext.restoreGraphicsState()
        }

        draw(CGRect(x: 0, y: 0, width: width, height: height))
        guard let cgImage = context.makeImage() else {
            throw ScreenshotError.exportFailed
        }

        return NSImage(cgImage: cgImage, size: CGSize(width: width, height: height))
    }

    private static func pngData(from image: NSImage) -> Data? {
        if let bitmap = image.representations.compactMap({ $0 as? NSBitmapImageRep }).first,
           let pngData = bitmap.representation(using: .png, properties: [:]) {
            return pngData
        }

        var proposedRect = NSRect(origin: .zero, size: image.size)
        if let cgImage = image.cgImage(forProposedRect: &proposedRect, context: nil, hints: nil) {
            let bitmap = NSBitmapImageRep(cgImage: cgImage)
            if let pngData = bitmap.representation(using: .png, properties: [:]) {
                return pngData
            }
        }

        guard
            let tiffData = image.tiffRepresentation,
            let bitmap = NSBitmapImageRep(data: tiffData)
        else {
            return nil
        }

        return bitmap.representation(using: .png, properties: [:])
    }

    private static func renderedAnnotation(
        _ annotation: ScreenshotAnnotation,
        requestedRect: CGRect,
        captureRect: CGRect,
        scaleX: CGFloat,
        scaleY: CGFloat
    ) -> RenderedScreenshotAnnotation {
        switch annotation.content {
        case .rectangle(let rect):
            let displayRect = rect.offsetBy(dx: requestedRect.minX, dy: requestedRect.minY)
            return .rectangle(
                CGRect(
                    x: (displayRect.minX - captureRect.minX) * scaleX,
                    y: (displayRect.minY - captureRect.minY) * scaleY,
                    width: displayRect.width * scaleX,
                    height: displayRect.height * scaleY
                )
            )
        case .text(let text):
            let displayOrigin = CGPoint(
                x: requestedRect.minX + text.origin.x,
                y: requestedRect.minY + text.origin.y
            )
            return .text(
                RenderedTextAnnotation(
                    text: text.text,
                    origin: CGPoint(
                        x: (displayOrigin.x - captureRect.minX) * scaleX,
                        y: (displayOrigin.y - captureRect.minY) * scaleY
                    ),
                    fontSize: 18 * min(scaleX, scaleY)
                )
            )
        }
    }

    private static func drawText(_ annotation: RenderedTextAnnotation) {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineBreakMode = .byWordWrapping

        let font = NSFont.systemFont(
            ofSize: max(annotation.fontSize, 12),
            weight: .semibold
        )
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor.systemRed,
            .paragraphStyle: paragraphStyle,
            .shadow: textShadow()
        ]
        let attributedString = NSAttributedString(string: annotation.text, attributes: attributes)
        let proposedSize = CGSize(width: 360 * max(annotation.fontSize / 18, 1), height: CGFloat.greatestFiniteMagnitude)
        let measuredSize = attributedString.boundingRect(
            with: proposedSize,
            options: [.usesLineFragmentOrigin, .usesFontLeading]
        ).integral.size
        let rect = CGRect(
            origin: annotation.origin,
            size: CGSize(
                width: max(measuredSize.width + 10, 1),
                height: max(measuredSize.height + 6, 1)
            )
        )

        attributedString.draw(with: rect, options: [.usesLineFragmentOrigin, .usesFontLeading])
    }

    private static func textShadow() -> NSShadow {
        let shadow = NSShadow()
        shadow.shadowColor = NSColor.white.withAlphaComponent(0.92)
        shadow.shadowBlurRadius = 1.8
        shadow.shadowOffset = .zero
        return shadow
    }
}

private enum RenderedScreenshotAnnotation {
    case rectangle(CGRect)
    case text(RenderedTextAnnotation)
}

private struct RenderedTextAnnotation {
    var text: String
    var origin: CGPoint
    var fontSize: CGFloat
}

enum ScreenshotError: LocalizedError {
    case displayNotFound
    case emptySelection
    case emptyCapture
    case exportFailed

    var errorDescription: String? {
        switch self {
        case .displayNotFound:
            "找不到所选屏幕。"
        case .emptySelection:
            "所选截图区域为空。"
        case .emptyCapture:
            "无法截取所选区域。"
        case .exportFailed:
            "图片未能保存到剪贴板，请缩小选区后重试。"
        }
    }
}
