import AppKit
import ApplicationServices
import CoreGraphics
import Foundation

@MainActor
enum AccessibilityElementExecutor {
    enum ScrollDirection {
        case up
        case down

        var accessibilityActionCandidates: [String] {
            switch self {
            case .up: ["AXScrollUpByPage", "AXScrollUp"]
            case .down: ["AXScrollDownByPage", "AXScrollDown"]
            }
        }

        var wheelDelta: Int32 {
            switch self {
            case .up: Self.scrollUpDelta
            case .down: Self.scrollDownDelta
            }
        }

        private static let scrollUpDelta: Int32 = 9
        private static let scrollDownDelta: Int32 = -9
    }

    static func execute(_ element: ScreenNavigationElement) {
        if element.supportsPress,
           AXUIElementPerformAction(element.element, kAXPressAction as CFString) == .success {
            return
        }

        if element.prefersFocus,
           AXUIElementSetAttributeValue(
               element.element,
               kAXFocusedAttribute as CFString,
               kCFBooleanTrue
           ) == .success {
            return
        }

        clickCenter(of: element.frame)
    }

    static func scrollApplication(processID: pid_t, direction: ScrollDirection) async {
        let appElement = AXUIElementCreateApplication(processID)
        performAccessibilityScroll(in: appElement, direction: direction)

        let scrollPoint = focusedWindowCenter(for: appElement) ?? NSScreen.main.map {
            CGPoint(x: $0.frame.midX, y: $0.frame.midY)
        }

        if let scrollPoint {
            for _ in 0..<Self.scrollPulseCount {
                postScrollWheel(delta: direction.wheelDelta, at: scrollPoint)
                try? await Task.sleep(for: .milliseconds(Self.scrollPulseDelayMilliseconds))
            }
        }

        let currentMousePoint = NSEvent.mouseLocation
        for _ in 0..<Self.scrollPulseCount {
            postScrollWheel(delta: direction.wheelDelta, at: currentMousePoint)
            try? await Task.sleep(for: .milliseconds(Self.scrollPulseDelayMilliseconds))
        }
    }

    private static func performAccessibilityScroll(in appElement: AXUIElement, direction: ScrollDirection) {
        for action in direction.accessibilityActionCandidates {
            if performFirstMatchingAction(action, in: scrollSearchRoots(for: appElement)) {
                return
            }
        }
    }

    private static func scrollSearchRoots(for appElement: AXUIElement) -> [AXUIElement] {
        var roots: [AXUIElement] = []

        if let focusedElement = elementAttribute(appElement, kAXFocusedUIElementAttribute) {
            roots.append(focusedElement)
        }

        if let focusedWindow = elementAttribute(appElement, kAXFocusedWindowAttribute),
           !contains(roots, focusedWindow) {
            roots.append(focusedWindow)
        }

        for window in elementArrayAttribute(appElement, kAXWindowsAttribute) where !contains(roots, window) {
            roots.append(window)
        }

        return roots
    }

    private static func performFirstMatchingAction(_ action: String, in roots: [AXUIElement]) -> Bool {
        var queue = roots.map { QueuedElement(element: $0, depth: 0) }
        var visited = Set<CFHashCode>()
        var visitedCount = 0

        while !queue.isEmpty, visitedCount < Self.maxScrollActionVisitedElements {
            let item = queue.removeFirst()
            let hash = CFHash(item.element)
            guard !visited.contains(hash) else {
                continue
            }

            visited.insert(hash)
            visitedCount += 1

            if actionNames(of: item.element).contains(action),
               AXUIElementPerformAction(item.element, action as CFString) == .success {
                return true
            }

            guard item.depth < Self.maxScrollActionTraversalDepth else {
                continue
            }

            for child in children(of: item.element) {
                queue.append(QueuedElement(element: child, depth: item.depth + 1))
            }
        }

        return false
    }

    private static func postScrollWheel(delta: Int32, at point: CGPoint) {
        let source = CGEventSource(stateID: .hidSystemState)
        guard let event = CGEvent(
            scrollWheelEvent2Source: source,
            units: .line,
            wheelCount: 1,
            wheel1: delta,
            wheel2: 0,
            wheel3: 0
        ) else {
            return
        }

        event.location = point
        event.setIntegerValueField(.eventSourceUserData, value: KeyboardEventEngine.syntheticEventMarker)
        event.post(tap: .cghidEventTap)
    }

    private static func attributeValue(_ element: AXUIElement, _ attribute: String) -> AnyObject? {
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, attribute as CFString, &value)
        guard result == .success else {
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

    private static func elementArrayAttribute(_ element: AXUIElement, _ attribute: String) -> [AXUIElement] {
        attributeValue(element, attribute) as? [AXUIElement] ?? []
    }

    private static func children(of element: AXUIElement) -> [AXUIElement] {
        var children = elementArrayAttribute(element, kAXChildrenAttribute)

        if let contents = attributeValue(element, kAXContentsAttribute) as? [AXUIElement] {
            children.append(contentsOf: contents)
        }

        return children
    }

    private static func actionNames(of element: AXUIElement) -> [String] {
        var actionNames: CFArray?
        let result = AXUIElementCopyActionNames(element, &actionNames)
        guard result == .success else {
            return []
        }

        return actionNames as? [String] ?? []
    }

    private static func contains(_ elements: [AXUIElement], _ target: AXUIElement) -> Bool {
        let targetHash = CFHash(target)
        return elements.contains { CFHash($0) == targetHash }
    }

    private static func focusedWindowCenter(for appElement: AXUIElement) -> CGPoint? {
        if let focusedWindow = elementAttribute(appElement, kAXFocusedWindowAttribute),
           let frame = frame(of: focusedWindow) {
            return CGPoint(x: frame.midX, y: frame.midY)
        }

        for window in elementArrayAttribute(appElement, kAXWindowsAttribute) {
            if let frame = frame(of: window) {
                return CGPoint(x: frame.midX, y: frame.midY)
            }
        }

        return nil
    }

    private static func frame(of element: AXUIElement) -> CGRect? {
        guard let position = pointAttribute(element, kAXPositionAttribute),
              let size = sizeAttribute(element, kAXSizeAttribute)
        else {
            return nil
        }

        return CGRect(origin: position, size: size)
    }

    private static func pointAttribute(_ element: AXUIElement, _ attribute: String) -> CGPoint? {
        guard let value = attributeValue(element, attribute),
              CFGetTypeID(value) == AXValueGetTypeID()
        else {
            return nil
        }

        var point = CGPoint.zero
        guard AXValueGetValue(value as! AXValue, .cgPoint, &point) else {
            return nil
        }

        return point
    }

    private static func sizeAttribute(_ element: AXUIElement, _ attribute: String) -> CGSize? {
        guard let value = attributeValue(element, attribute),
              CFGetTypeID(value) == AXValueGetTypeID()
        else {
            return nil
        }

        var size = CGSize.zero
        guard AXValueGetValue(value as! AXValue, .cgSize, &size) else {
            return nil
        }

        return size
    }

    private static func clickCenter(of frame: CGRect) {
        let point = CGPoint(x: frame.midX, y: frame.midY)
        let source = CGEventSource(stateID: .hidSystemState)

        postMouseEvent(.leftMouseDown, at: point, source: source)
        postMouseEvent(.leftMouseUp, at: point, source: source)
    }

    private static func postMouseEvent(
        _ type: CGEventType,
        at point: CGPoint,
        source: CGEventSource?
    ) {
        guard let event = CGEvent(
            mouseEventSource: source,
            mouseType: type,
            mouseCursorPosition: point,
            mouseButton: .left
        ) else {
            return
        }

        event.setIntegerValueField(.eventSourceUserData, value: KeyboardEventEngine.syntheticEventMarker)
        event.post(tap: .cghidEventTap)
    }

    private struct QueuedElement {
        let element: AXUIElement
        let depth: Int
    }

    private static let scrollPulseCount = 4
    private static let scrollPulseDelayMilliseconds = 12
    private static let maxScrollActionVisitedElements = 900
    private static let maxScrollActionTraversalDepth = 12
}
