import AppKit
import SwiftUI

@MainActor
final class ScreenshotOverlayController {
    static let shared = ScreenshotOverlayController()

    private var windows: [ScreenshotOverlayWindow] = []
    private var captureSessionID: UUID?

    func beginCapture() {
        guard ScreenshotService.requestScreenCaptureAccessIfNeeded() else {
            return
        }

        closeSelection()

        let sessionID = UUID()
        captureSessionID = sessionID
        let targets = NSScreen.screens.map {
            ScreenshotOverlayTarget(screen: $0, displayID: $0.displayID, size: $0.frame.size)
        }

        Task { @MainActor [weak self] in
            let previews = await Self.previewImages(for: targets)
            guard self?.captureSessionID == sessionID else {
                return
            }

            self?.showSelectionWindows(for: targets, previews: previews)
        }
    }

    private func showSelectionWindows(
        for targets: [ScreenshotOverlayTarget],
        previews: [CGDirectDisplayID: CGImage]
    ) {
        windows = targets.map { target in
            let displayID = target.displayID
            let view = ScreenshotSelectionView(
                screenImage: previews[displayID],
                copy: { [weak self] rect, annotations in
                    self?.copySelection(rect, annotations: annotations, on: displayID)
                },
                pin: { [weak self] rect, annotations in
                    self?.pinSelection(rect, annotations: annotations, on: displayID, screenFrame: target.screen.frame)
                },
                cancel: { [weak self] in
                    self?.closeSelection()
                }
            )

            let controller = NSHostingController(rootView: view)
            controller.view.frame = NSRect(origin: .zero, size: target.screen.frame.size)

            let window = ScreenshotOverlayWindow(
                contentRect: target.screen.frame,
                styleMask: .borderless,
                backing: .buffered,
                defer: false,
                screen: target.screen
            )
            window.contentViewController = controller
            window.isReleasedWhenClosed = false
            window.isOpaque = false
            window.backgroundColor = .clear
            window.hasShadow = false
            window.level = .screenSaver
            window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
            window.ignoresMouseEvents = false
            window.orderFrontRegardless()
            return window
        }

        NSApp.activate(ignoringOtherApps: true)
        windows.first?.makeKeyAndOrderFront(nil)
    }

    private static func previewImages(for targets: [ScreenshotOverlayTarget]) async -> [CGDirectDisplayID: CGImage] {
        var previews: [CGDirectDisplayID: CGImage] = [:]

        for target in targets {
            do {
                let preview = try await ScreenshotService.previewImage(
                    size: target.size,
                    on: target.displayID
                )
                previews[target.displayID] = preview
            } catch {
                assertionFailure("Failed to capture screenshot preview: \(error)")
            }
        }

        return previews
    }

    private func copySelection(
        _ rect: CGRect,
        annotations: [ScreenshotAnnotation],
        on displayID: CGDirectDisplayID
    ) {
        closeSelection()

        Task { @MainActor in
            do {
                try await Task.sleep(for: .milliseconds(80))
                let image = try await ScreenshotService.capture(
                    rect: rect,
                    annotations: annotations,
                    on: displayID
                )
                ScreenshotService.copyToPasteboard(image)
            } catch {
                assertionFailure("Failed to capture screenshot: \(error)")
            }
        }
    }

    private func pinSelection(
        _ rect: CGRect,
        annotations: [ScreenshotAnnotation],
        on displayID: CGDirectDisplayID,
        screenFrame: CGRect
    ) {
        closeSelection()

        Task { @MainActor in
            do {
                try await Task.sleep(for: .milliseconds(80))
                let image = try await ScreenshotService.capture(
                    rect: rect,
                    annotations: annotations,
                    on: displayID
                )
                ScreenshotPinController.shared.pin(image, sourceRect: rect, screenFrame: screenFrame)
            } catch {
                assertionFailure("Failed to pin screenshot: \(error)")
            }
        }
    }

    private func closeSelection() {
        captureSessionID = nil
        windows.forEach { $0.close() }
        windows = []
    }
}

private struct ScreenshotOverlayTarget {
    var screen: NSScreen
    var displayID: CGDirectDisplayID
    var size: CGSize
}

private extension NSScreen {
    var displayID: CGDirectDisplayID {
        let number = deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber
        return number?.uint32Value ?? CGMainDisplayID()
    }
}

final class ScreenshotOverlayWindow: NSWindow {
    override var canBecomeKey: Bool { true }
}
