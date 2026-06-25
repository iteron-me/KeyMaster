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

    static func capture(rect: CGRect) async throws -> NSImage {
        let image: CGImage = try await withCheckedThrowingContinuation { continuation in
            SCScreenshotManager.captureImage(in: rect) { image, error in
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

        return NSImage(cgImage: image, size: NSSize(width: image.width, height: image.height))
    }

    static func copyToPasteboard(_ image: NSImage) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.writeObjects([image])
    }
}

enum ScreenshotError: LocalizedError {
    case emptyCapture

    var errorDescription: String? {
        switch self {
        case .emptyCapture:
            "The selected screen area could not be captured."
        }
    }
}
