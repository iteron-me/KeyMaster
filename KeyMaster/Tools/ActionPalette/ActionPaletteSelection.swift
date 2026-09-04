import AppKit
import ApplicationServices
import Foundation

struct ActionPaletteCapture {
    let processID: pid_t?
    let text: String?
    let selectionFrame: CGRect?
    let screen: NSScreen
    let errorMessage: String?
}

@MainActor
enum ActionPaletteSelectionReader {
    static func capture() -> ActionPaletteCapture? {
        guard let fallbackScreen = NSScreen.main ?? NSScreen.screens.first else {
            return nil
        }

        let ownProcessID = ProcessInfo.processInfo.processIdentifier
        guard let application = NSWorkspace.shared.frontmostApplication,
              application.processIdentifier != ownProcessID,
              !application.isTerminated
        else {
            return failure("No active app", on: fallbackScreen)
        }

        let processID = application.processIdentifier
        let applicationElement = AXUIElementCreateApplication(processID)
        guard PermissionService().currentStatus().isAccessibilityTrusted else {
            return ActionPaletteCapture(
                processID: processID,
                text: nil,
                selectionFrame: nil,
                screen: fallbackScreen,
                errorMessage: "Accessibility required"
            )
        }

        let focusedElement = elementAttribute(applicationElement, kAXFocusedUIElementAttribute)
        let accessibilityBounds = focusedElement.flatMap(selectionBounds)
        let screen = accessibilityBounds.flatMap(screenContaining)
            ?? targetScreen(applicationElement: applicationElement)
            ?? fallbackScreen
        let appKitSelectionFrame = accessibilityBounds.map {
            ActionPaletteGeometry.appKitRect(
                fromAccessibilityRect: $0,
                displayBounds: displayBounds(for: screen),
                screenFrame: screen.frame
            )
        }

        guard let focusedElement,
              let rawText = attributeValue(focusedElement, kAXSelectedTextAttribute) as? String,
              let text = ActionPaletteSupport.selectedText(from: rawText)
        else {
            return ActionPaletteCapture(
                processID: processID,
                text: nil,
                selectionFrame: appKitSelectionFrame,
                screen: screen,
                errorMessage: "No selected text"
            )
        }

        return ActionPaletteCapture(
            processID: processID,
            text: text,
            selectionFrame: appKitSelectionFrame,
            screen: screen,
            errorMessage: nil
        )
    }

    private static func failure(_ message: String, on screen: NSScreen) -> ActionPaletteCapture {
        ActionPaletteCapture(
            processID: nil,
            text: nil,
            selectionFrame: nil,
            screen: screen,
            errorMessage: message
        )
    }

    private static func targetScreen(applicationElement: AXUIElement) -> NSScreen? {
        guard let window = elementAttribute(applicationElement, kAXFocusedWindowAttribute),
              let frame = frame(of: window)
        else {
            return nil
        }
        return screenContaining(frame)
    }

    private static func screenContaining(_ accessibilityFrame: CGRect) -> NSScreen? {
        guard let screen = NSScreen.screens.max(by: { lhs, rhs in
            intersectionArea(accessibilityFrame, displayBounds(for: lhs))
                < intersectionArea(accessibilityFrame, displayBounds(for: rhs))
        }), intersectionArea(accessibilityFrame, displayBounds(for: screen)) > 0 else {
            return nil
        }
        return screen
    }

    private static func displayBounds(for screen: NSScreen) -> CGRect {
        let key = NSDeviceDescriptionKey("NSScreenNumber")
        guard let number = screen.deviceDescription[key] as? NSNumber else {
            return screen.frame
        }
        return CGDisplayBounds(CGDirectDisplayID(number.uint32Value))
    }

    private static func intersectionArea(_ lhs: CGRect, _ rhs: CGRect) -> CGFloat {
        let intersection = lhs.intersection(rhs)
        return intersection.isNull ? 0 : intersection.width * intersection.height
    }

    private static func selectionBounds(of element: AXUIElement) -> CGRect? {
        guard let rangeValue = attributeValue(element, kAXSelectedTextRangeAttribute),
              CFGetTypeID(rangeValue) == AXValueGetTypeID()
        else {
            return nil
        }

        var value: CFTypeRef?
        guard AXUIElementCopyParameterizedAttributeValue(
            element,
            kAXBoundsForRangeParameterizedAttribute as CFString,
            rangeValue,
            &value
        ) == .success,
        let value,
        CFGetTypeID(value) == AXValueGetTypeID()
        else {
            return nil
        }

        var rect = CGRect.zero
        guard AXValueGetValue(value as! AXValue, .cgRect, &rect),
              rect.width.isFinite,
              rect.height.isFinite,
              !rect.isEmpty
        else {
            return nil
        }
        return rect
    }

    private static func frame(of element: AXUIElement) -> CGRect? {
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

    private static func attributeValue(_ element: AXUIElement, _ attribute: String) -> AnyObject? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success else {
            return nil
        }
        return value as AnyObject?
    }

    private static func elementAttribute(_ element: AXUIElement, _ attribute: String) -> AXUIElement? {
        guard let value = attributeValue(element, attribute),
              CFGetTypeID(value) == AXUIElementGetTypeID()
        else {
            return nil
        }
        return (value as! AXUIElement)
    }
}

enum ActionPaletteSupport {
    static func selectedText(from value: String) -> String? {
        let text = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return text.isEmpty ? nil : text
    }

    static func googleSearchURL(for text: String) -> URL? {
        guard let text = selectedText(from: text) else {
            return nil
        }

        var components = URLComponents(string: "https://www.google.com/search")
        components?.queryItems = [URLQueryItem(name: "q", value: text)]
        return components?.url
    }
}

enum ActionPaletteGeometry {
    static func appKitRect(
        fromAccessibilityRect rect: CGRect,
        displayBounds: CGRect,
        screenFrame: CGRect
    ) -> CGRect {
        CGRect(
            x: screenFrame.minX + rect.minX - displayBounds.minX,
            y: screenFrame.maxY - (rect.maxY - displayBounds.minY),
            width: rect.width,
            height: rect.height
        )
    }

    static func chooserFrame(
        selectionFrame: CGRect?,
        visibleFrame: CGRect,
        size: CGSize
    ) -> CGRect {
        let minX = visibleFrame.minX + edgePadding
        let maxX = max(minX, visibleFrame.maxX - size.width - edgePadding)
        let minY = visibleFrame.minY + edgePadding
        let maxY = max(minY, visibleFrame.maxY - size.height - edgePadding)
        let fallbackY = maxY - min(72, visibleFrame.height * 0.12)

        guard let selectionFrame,
              selectionFrame.intersects(visibleFrame)
        else {
            return CGRect(
                x: clamp(visibleFrame.midX - size.width / 2, min: minX, max: maxX),
                y: clamp(fallbackY, min: minY, max: maxY),
                width: size.width,
                height: size.height
            )
        }

        let belowY = selectionFrame.minY - gap - size.height
        let aboveY = selectionFrame.maxY + gap
        let y: CGFloat
        if belowY >= minY {
            y = belowY
        } else if aboveY <= maxY {
            y = aboveY
        } else {
            y = fallbackY
        }

        return CGRect(
            x: clamp(selectionFrame.midX - size.width / 2, min: minX, max: maxX),
            y: clamp(y, min: minY, max: maxY),
            width: size.width,
            height: size.height
        )
    }

    static func previewFrame(visibleFrame: CGRect, preferredSize: CGSize) -> CGRect {
        let width = min(preferredSize.width, visibleFrame.width - edgePadding * 2)
        let height = min(preferredSize.height, visibleFrame.height - edgePadding * 2)
        return CGRect(
            x: visibleFrame.midX - width / 2,
            y: visibleFrame.midY - height / 2,
            width: width,
            height: height
        )
    }

    private static func clamp(_ value: CGFloat, min minimum: CGFloat, max maximum: CGFloat) -> CGFloat {
        Swift.min(Swift.max(value, minimum), maximum)
    }

    private static let edgePadding: CGFloat = 12
    private static let gap: CGFloat = 8
}

enum ActionPaletteKeyCommand: Equatable {
    case execute
    case moveSelection(Int)
    case close

    init?(keyCode: UInt16) {
        switch keyCode {
        case 36, 76:
            self = .execute
        case 123:
            self = .moveSelection(-1)
        case 124:
            self = .moveSelection(1)
        case 53:
            self = .close
        default:
            return nil
        }
    }
}
