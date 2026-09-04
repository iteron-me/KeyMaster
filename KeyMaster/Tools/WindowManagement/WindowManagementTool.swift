import AppKit
import ApplicationServices
import Foundation

enum WindowManagementOperation: String, CaseIterable, Identifiable {
    case leftHalf
    case rightHalf
    case fill
    case center
    case nextDisplay
    case restore

    static let toolID = "window.management"
    static let configurationKey = "operation"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .leftHalf: "Left Half"
        case .rightHalf: "Right Half"
        case .fill: "Fill"
        case .center: "Center"
        case .nextDisplay: "Next Display"
        case .restore: "Restore"
        }
    }

    var systemImage: String {
        switch self {
        case .leftHalf: "rectangle.lefthalf.filled"
        case .rightHalf: "rectangle.righthalf.filled"
        case .fill: "rectangle.inset.filled"
        case .center: "rectangle.center.inset.filled"
        case .nextDisplay: "rectangle.on.rectangle"
        case .restore: "arrow.uturn.backward"
        }
    }

    var invocation: ToolInvocation {
        ToolInvocation(
            toolID: Self.toolID,
            displayName: title,
            configuration: ToolConfigurationPayload(
                values: [Self.configurationKey: .string(rawValue)]
            )
        )
    }

    init?(invocation: ToolInvocation) {
        guard invocation.toolID == Self.toolID,
              case .string(let rawValue) = invocation.configuration.values[Self.configurationKey]
        else {
            return nil
        }
        self.init(rawValue: rawValue)
    }
}

struct WindowManagementTool: KeyMasterTool {
    let id = WindowManagementOperation.toolID
    let title = "Window Management"
    let subtitle = "Move and resize the focused window"
    let systemImage = "rectangle.split.2x1"

    var defaultInvocation: ToolInvocation {
        WindowManagementOperation.leftHalf.invocation
    }

    @MainActor
    func run(_ invocation: ToolInvocation) async throws {
        guard let operation = WindowManagementOperation(invocation: invocation) else {
            return
        }
        WindowManagementExecutor.shared.perform(operation)
    }
}

enum WindowManagementGeometry {
    static func frame(
        for operation: WindowManagementOperation,
        windowFrame: CGRect,
        visibleFrame: CGRect
    ) -> CGRect? {
        switch operation {
        case .leftHalf:
            CGRect(
                x: visibleFrame.minX,
                y: visibleFrame.minY,
                width: visibleFrame.width / 2,
                height: visibleFrame.height
            )
        case .rightHalf:
            CGRect(
                x: visibleFrame.midX,
                y: visibleFrame.minY,
                width: visibleFrame.width / 2,
                height: visibleFrame.height
            )
        case .fill:
            visibleFrame
        case .center:
            clamped(
                CGRect(
                    x: visibleFrame.midX - min(windowFrame.width, visibleFrame.width) / 2,
                    y: visibleFrame.midY - min(windowFrame.height, visibleFrame.height) / 2,
                    width: min(windowFrame.width, visibleFrame.width),
                    height: min(windowFrame.height, visibleFrame.height)
                ),
                inside: visibleFrame
            )
        case .nextDisplay, .restore:
            nil
        }
    }

    static func movedFrame(
        _ windowFrame: CGRect,
        from sourceFrame: CGRect,
        to destinationFrame: CGRect
    ) -> CGRect {
        let width = min(windowFrame.width, destinationFrame.width)
        let height = min(windowFrame.height, destinationFrame.height)
        let sourceTravelX = max(sourceFrame.width - windowFrame.width, 0)
        let sourceTravelY = max(sourceFrame.height - windowFrame.height, 0)
        let xRatio = sourceTravelX > 0 ? (windowFrame.minX - sourceFrame.minX) / sourceTravelX : 0.5
        let yRatio = sourceTravelY > 0 ? (windowFrame.minY - sourceFrame.minY) / sourceTravelY : 0.5
        let destinationTravelX = max(destinationFrame.width - width, 0)
        let destinationTravelY = max(destinationFrame.height - height, 0)

        return clamped(
            CGRect(
                x: destinationFrame.minX + destinationTravelX * xRatio,
                y: destinationFrame.minY + destinationTravelY * yRatio,
                width: width,
                height: height
            ),
            inside: destinationFrame
        )
    }

    private static func clamped(_ frame: CGRect, inside bounds: CGRect) -> CGRect {
        CGRect(
            x: min(max(frame.minX, bounds.minX), bounds.maxX - frame.width),
            y: min(max(frame.minY, bounds.minY), bounds.maxY - frame.height),
            width: frame.width,
            height: frame.height
        )
    }
}

@MainActor
final class WindowManagementExecutor {
    static let shared = WindowManagementExecutor()

    private var restoreFrames: [WindowIdentity: CGRect] = [:]

    func perform(_ operation: WindowManagementOperation) {
        guard PermissionService().currentStatus().isAccessibilityTrusted,
              let target = focusedWindow()
        else {
            return
        }

        let identity = WindowIdentity(processID: target.processID, accessibilityHash: CFHash(target.element))
        if operation == .restore {
            guard let frame = restoreFrames[identity], setFrame(frame, of: target.element) else {
                return
            }
            restoreFrames.removeValue(forKey: identity)
            return
        }

        guard let sourceScreen = screen(containing: target.frame) else {
            return
        }

        let destinationFrame: CGRect?
        if operation == .nextDisplay {
            guard let destinationScreen = nextScreen(after: sourceScreen) else {
                return
            }
            destinationFrame = WindowManagementGeometry.movedFrame(
                target.frame,
                from: accessibilityVisibleFrame(for: sourceScreen),
                to: accessibilityVisibleFrame(for: destinationScreen)
            )
        } else {
            destinationFrame = WindowManagementGeometry.frame(
                for: operation,
                windowFrame: target.frame,
                visibleFrame: accessibilityVisibleFrame(for: sourceScreen)
            )
        }

        guard let destinationFrame else {
            return
        }
        if setFrame(destinationFrame, of: target.element) {
            restoreFrames[identity] = target.frame
        }
    }

    private func focusedWindow() -> FocusedWindow? {
        let ownProcessID = ProcessInfo.processInfo.processIdentifier
        let processID: pid_t?
        if let application = NSWorkspace.shared.frontmostApplication,
           application.processIdentifier != ownProcessID,
           !application.isTerminated {
            processID = application.processIdentifier
        } else {
            processID = topmostWindowOwner(excluding: ownProcessID)
        }

        guard let processID else {
            return nil
        }
        let applicationElement = AXUIElementCreateApplication(processID)
        guard let window = elementAttribute(applicationElement, kAXFocusedWindowAttribute),
              let frame = frame(of: window),
              frame.width > 0,
              frame.height > 0
        else {
            return nil
        }
        return FocusedWindow(processID: processID, element: window, frame: frame)
    }

    private func topmostWindowOwner(excluding processID: pid_t) -> pid_t? {
        let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        guard let windows = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
            return nil
        }
        return windows.first { window in
            guard let owner = window[kCGWindowOwnerPID as String] as? pid_t,
                  owner != processID,
                  let layer = window[kCGWindowLayer as String] as? Int,
                  layer == 0,
                  let alpha = window[kCGWindowAlpha as String] as? Double,
                  alpha > 0
            else {
                return false
            }
            return true
        }?[kCGWindowOwnerPID as String] as? pid_t
    }

    private func screen(containing frame: CGRect) -> NSScreen? {
        guard let screen = NSScreen.screens.max(by: { lhs, rhs in
            intersectionArea(frame, displayBounds(for: lhs)) < intersectionArea(frame, displayBounds(for: rhs))
        }), intersectionArea(frame, displayBounds(for: screen)) > 0 else {
            return nil
        }
        return screen
    }

    private func nextScreen(after current: NSScreen) -> NSScreen? {
        let screens = NSScreen.screens.sorted {
            let lhs = displayBounds(for: $0)
            let rhs = displayBounds(for: $1)
            return lhs.minX == rhs.minX ? lhs.minY < rhs.minY : lhs.minX < rhs.minX
        }
        guard screens.count > 1,
              let index = screens.firstIndex(where: { $0 === current })
        else {
            return nil
        }
        return screens[(index + 1) % screens.count]
    }

    private func accessibilityVisibleFrame(for screen: NSScreen) -> CGRect {
        let displayFrame = displayBounds(for: screen)
        let visibleFrame = screen.visibleFrame
        return CGRect(
            x: displayFrame.minX + visibleFrame.minX - screen.frame.minX,
            y: displayFrame.minY + screen.frame.maxY - visibleFrame.maxY,
            width: visibleFrame.width,
            height: visibleFrame.height
        )
    }

    private func displayBounds(for screen: NSScreen) -> CGRect {
        let key = NSDeviceDescriptionKey("NSScreenNumber")
        guard let number = screen.deviceDescription[key] as? NSNumber else {
            return screen.frame
        }
        return CGDisplayBounds(CGDirectDisplayID(number.uint32Value))
    }

    private func intersectionArea(_ lhs: CGRect, _ rhs: CGRect) -> CGFloat {
        let intersection = lhs.intersection(rhs)
        return intersection.isNull ? 0 : intersection.width * intersection.height
    }

    private func setFrame(_ frame: CGRect, of element: AXUIElement) -> Bool {
        var position = frame.origin
        var size = frame.size
        guard let positionValue = AXValueCreate(.cgPoint, &position),
              let sizeValue = AXValueCreate(.cgSize, &size)
        else {
            return false
        }
        let sizeResult = AXUIElementSetAttributeValue(element, kAXSizeAttribute as CFString, sizeValue)
        let positionResult = AXUIElementSetAttributeValue(element, kAXPositionAttribute as CFString, positionValue)
        return sizeResult == .success && positionResult == .success
    }

    private func frame(of element: AXUIElement) -> CGRect? {
        guard let positionValue = attributeValue(element, kAXPositionAttribute),
              CFGetTypeID(positionValue) == AXValueGetTypeID(),
              let sizeValue = attributeValue(element, kAXSizeAttribute),
              CFGetTypeID(sizeValue) == AXValueGetTypeID()
        else {
            return nil
        }
        var position = CGPoint.zero
        var size = CGSize.zero
        guard AXValueGetValue(positionValue as! AXValue, .cgPoint, &position),
              AXValueGetValue(sizeValue as! AXValue, .cgSize, &size)
        else {
            return nil
        }
        return CGRect(origin: position, size: size)
    }

    private func attributeValue(_ element: AXUIElement, _ attribute: String) -> AnyObject? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success else {
            return nil
        }
        return value as AnyObject?
    }

    private func elementAttribute(_ element: AXUIElement, _ attribute: String) -> AXUIElement? {
        guard let value = attributeValue(element, attribute),
              CFGetTypeID(value) == AXUIElementGetTypeID()
        else {
            return nil
        }
        return (value as! AXUIElement)
    }
}

private struct FocusedWindow {
    let processID: pid_t
    let element: AXUIElement
    let frame: CGRect
}

private struct WindowIdentity: Hashable {
    let processID: pid_t
    let accessibilityHash: CFHashCode
}
