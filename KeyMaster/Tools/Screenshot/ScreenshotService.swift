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
        on displayID: CGDirectDisplayID
    ) async throws -> NSImage {
        let content = try await SCShareableContent.current
        guard let display = content.displays.first(where: { $0.displayID == displayID }) else {
            throw ScreenshotError.displayNotFound
        }

        let filter = SCContentFilter(display: display, excludingWindows: [])
        let scale = max(CGFloat(filter.pointPixelScale), 1)
        let captureRect = pixelAligned(
            clamped(requestedRect, to: CGSize(width: display.width, height: display.height)),
            scale: scale
        )
        guard captureRect.width > 0, captureRect.height > 0 else {
            throw ScreenshotError.emptySelection
        }

        let configuration = SCStreamConfiguration()
        configuration.sourceRect = captureRect
        configuration.width = max(Int((captureRect.width * scale).rounded(.toNearestOrAwayFromZero)), 1)
        configuration.height = max(Int((captureRect.height * scale).rounded(.toNearestOrAwayFromZero)), 1)
        configuration.showsCursor = false

        let cgImage: CGImage = try await withCheckedThrowingContinuation { continuation in
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

        let image = NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
        guard !annotations.isEmpty else {
            return image
        }

        return annotatedImage(
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

    static func copyToPasteboard(_ image: NSImage) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.writeObjects([image])
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
    ) -> NSImage {
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

        return NSImage(size: imageSize, flipped: true) { targetRect in
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
            return true
        }
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

    var errorDescription: String? {
        switch self {
        case .displayNotFound:
            "The selected display could not be found."
        case .emptySelection:
            "The selected screen area is empty."
        case .emptyCapture:
            "The selected screen area could not be captured."
        }
    }
}
