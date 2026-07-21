import AppKit
import ApplicationServices
import CoreGraphics
import Foundation

@MainActor
final class AccessibilityElementScanner {
    private let permissionService: PermissionService
    private let ownProcessID = ProcessInfo.processInfo.processIdentifier

    init(permissionService: PermissionService = PermissionService()) {
        self.permissionService = permissionService
    }

    func scanFrontmostApplication() -> ScreenNavigationScanResult {
        guard permissionService.currentStatus().isAccessibilityTrusted else {
            return .permissionRequired
        }

        guard let application = frontmostApplication() else {
            return .noFrontmostApplication
        }

        let appElement = AXUIElementCreateApplication(application.processIdentifier)
        let roots = rootElements(from: appElement)
        guard !roots.isEmpty else {
            return .noCandidates
        }

        let candidates = scanCandidates(from: roots)
        let filteredCandidates = filteredOverlappingCandidates(candidates)
            .sorted(by: visualOrder)
            .prefix(Self.maxCandidates)

        let elements = Array(filteredCandidates)
        return elements.isEmpty ? .noCandidates : .success(
            processID: application.processIdentifier,
            elements: elements
        )
    }

    private func rootElements(from appElement: AXUIElement) -> [AXUIElement] {
        var roots: [AXUIElement] = []

        if let focusedWindow = elementAttribute(appElement, kAXFocusedWindowAttribute) {
            roots.append(focusedWindow)
        }

        for window in elementArrayAttribute(appElement, kAXWindowsAttribute) where !contains(roots, window) {
            roots.append(window)
        }

        return roots
    }

    private func frontmostApplication() -> NSRunningApplication? {
        if let application = NSWorkspace.shared.frontmostApplication,
           isInspectableApplication(application) {
            return application
        }

        if let application = topmostWindowOwnerApplication() {
            return application
        }

        return NSWorkspace.shared.runningApplications.first { application in
            application.isActive && isInspectableApplication(application)
        }
    }

    private func topmostWindowOwnerApplication() -> NSRunningApplication? {
        let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        guard let windowInfoList = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
            return nil
        }

        for windowInfo in windowInfoList {
            guard let ownerPID = windowInfo[kCGWindowOwnerPID as String] as? pid_t,
                  ownerPID != ownProcessID,
                  let layer = windowInfo[kCGWindowLayer as String] as? Int,
                  layer == 0,
                  let alpha = windowInfo[kCGWindowAlpha as String] as? Double,
                  alpha > 0,
                  let bounds = windowInfo[kCGWindowBounds as String] as? [String: CGFloat],
                  let width = bounds["Width"],
                  let height = bounds["Height"],
                  width >= Self.minimumWindowSize,
                  height >= Self.minimumWindowSize,
                  let application = NSRunningApplication(processIdentifier: ownerPID),
                  isInspectableApplication(application)
            else {
                continue
            }

            return application
        }

        return nil
    }

    private func isInspectableApplication(_ application: NSRunningApplication) -> Bool {
        application.processIdentifier != ownProcessID
            && !application.isTerminated
            && application.activationPolicy != .prohibited
    }

    private func scanCandidates(from roots: [AXUIElement]) -> [ScreenNavigationElement] {
        var candidates: [ScreenNavigationElement] = []
        var queue = roots.map { root in
            QueuedElement(element: root, depth: 0, windowFrame: frame(of: root))
        }
        var visited = Set<CFHashCode>()
        var visitedCount = 0

        while !queue.isEmpty, visitedCount < Self.maxVisitedElements, candidates.count < Self.maxRawCandidates {
            let item = queue.removeFirst()
            let hash = CFHash(item.element)
            guard !visited.contains(hash) else {
                continue
            }

            visited.insert(hash)
            visitedCount += 1

            if let candidate = candidate(from: item.element, windowFrame: item.windowFrame) {
                candidates.append(candidate)
            }

            guard item.depth < Self.maxTraversalDepth else {
                continue
            }

            for child in children(of: item.element) {
                queue.append(
                    QueuedElement(
                        element: child,
                        depth: item.depth + 1,
                        windowFrame: item.windowFrame
                    )
                )
            }
        }

        return candidates
    }

    private func candidate(from element: AXUIElement, windowFrame: CGRect?) -> ScreenNavigationElement? {
        guard let role = stringAttribute(element, kAXRoleAttribute),
              isEnabled(element),
              !isHidden(element),
              let frame = frame(of: element),
              isUsable(frame, role: role, windowFrame: windowFrame)
        else {
            return nil
        }

        let actions = actionNames(of: element)
        let supportsPress = actions.contains(kAXPressAction)
        let prefersFocus = Self.focusRoles.contains(role)
        let hasExplicitRole = Self.actionableRoles.contains(role)
        let hasAction = hasExplicitRole || supportsPress || prefersFocus

        guard hasAction else {
            return nil
        }

        return ScreenNavigationElement(
            role: role,
            title: title(of: element),
            frame: frame,
            supportsPress: supportsPress,
            prefersFocus: prefersFocus,
            element: element
        )
    }

    private func children(of element: AXUIElement) -> [AXUIElement] {
        var children = elementArrayAttribute(element, kAXChildrenAttribute)

        if let contents = attributeValue(element, kAXContentsAttribute) as? [AXUIElement] {
            children.append(contentsOf: contents)
        }

        return children
    }

    private func frame(of element: AXUIElement) -> CGRect? {
        guard let position = pointAttribute(element, kAXPositionAttribute),
              let size = sizeAttribute(element, kAXSizeAttribute)
        else {
            return nil
        }

        return CGRect(origin: position, size: size)
    }

    private func title(of element: AXUIElement) -> String? {
        for attribute in [kAXTitleAttribute, kAXDescriptionAttribute, kAXHelpAttribute, kAXValueAttribute] {
            if let value = stringAttribute(element, attribute), !value.isEmpty {
                return value
            }
        }

        return nil
    }

    private func isEnabled(_ element: AXUIElement) -> Bool {
        boolAttribute(element, kAXEnabledAttribute) ?? true
    }

    private func isHidden(_ element: AXUIElement) -> Bool {
        boolAttribute(element, kAXHiddenAttribute) ?? false
    }

    private func isUsable(_ frame: CGRect, role: String, windowFrame: CGRect?) -> Bool {
        guard frame.width >= Self.minimumElementSize,
              frame.height >= Self.minimumElementSize,
              frame.isFinite
        else {
            return false
        }

        if isOversizedTextTarget(frame, role: role, windowFrame: windowFrame) {
            return false
        }

        return NSScreen.screens.contains { screen in
            !screen.frame.intersection(frame).isNull
        }
    }

    private func isOversizedTextTarget(
        _ frame: CGRect,
        role: String,
        windowFrame: CGRect?
    ) -> Bool {
        guard Self.largeTextTargetRoles.contains(role),
              let windowFrame,
              windowFrame.width > 0,
              windowFrame.height > 0
        else {
            return false
        }

        let widthRatio = frame.width / windowFrame.width
        let heightRatio = frame.height / windowFrame.height
        let areaRatio = area(of: frame) / area(of: windowFrame)

        return areaRatio > 0.28 || (widthRatio > 0.55 && heightRatio > 0.35)
    }

    private func filteredOverlappingCandidates(
        _ candidates: [ScreenNavigationElement]
    ) -> [ScreenNavigationElement] {
        var kept: [ScreenNavigationElement] = []

        for candidate in candidates.sorted(by: { area(of: $0.frame) < area(of: $1.frame) }) {
            let isNearDuplicate = kept.contains { existing in
                let intersection = existing.frame.intersection(candidate.frame)
                guard !intersection.isNull else {
                    return false
                }

                let overlap = area(of: intersection) / min(area(of: existing.frame), area(of: candidate.frame))
                return overlap > 0.88
            }

            if !isNearDuplicate {
                kept.append(candidate)
            }
        }

        return kept
    }

    private func visualOrder(_ lhs: ScreenNavigationElement, _ rhs: ScreenNavigationElement) -> Bool {
        let yDelta = abs(lhs.frame.minY - rhs.frame.minY)

        if yDelta > 8 {
            return lhs.frame.minY < rhs.frame.minY
        }

        return lhs.frame.minX < rhs.frame.minX
    }

    private func area(of rect: CGRect) -> CGFloat {
        max(0, rect.width) * max(0, rect.height)
    }

    private func attributeValue(_ element: AXUIElement, _ attribute: String) -> AnyObject? {
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, attribute as CFString, &value)
        guard result == .success else {
            return nil
        }

        return value as AnyObject?
    }

    private func stringAttribute(_ element: AXUIElement, _ attribute: String) -> String? {
        attributeValue(element, attribute) as? String
    }

    private func boolAttribute(_ element: AXUIElement, _ attribute: String) -> Bool? {
        attributeValue(element, attribute) as? Bool
    }

    private func elementAttribute(_ element: AXUIElement, _ attribute: String) -> AXUIElement? {
        guard let value = attributeValue(element, attribute),
              CFGetTypeID(value) == AXUIElementGetTypeID()
        else {
            return nil
        }

        return (value as! AXUIElement)
    }

    private func elementArrayAttribute(_ element: AXUIElement, _ attribute: String) -> [AXUIElement] {
        attributeValue(element, attribute) as? [AXUIElement] ?? []
    }

    private func pointAttribute(_ element: AXUIElement, _ attribute: String) -> CGPoint? {
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

    private func sizeAttribute(_ element: AXUIElement, _ attribute: String) -> CGSize? {
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

    private func actionNames(of element: AXUIElement) -> [String] {
        var actionNames: CFArray?
        let result = AXUIElementCopyActionNames(element, &actionNames)
        guard result == .success else {
            return []
        }

        return actionNames as? [String] ?? []
    }

    private func contains(_ elements: [AXUIElement], _ target: AXUIElement) -> Bool {
        let targetHash = CFHash(target)
        return elements.contains { CFHash($0) == targetHash }
    }

    private struct QueuedElement {
        let element: AXUIElement
        let depth: Int
        let windowFrame: CGRect?
    }

    private static let maxCandidates = 120
    private static let maxRawCandidates = 180
    private static let maxVisitedElements = 1_200
    private static let maxTraversalDepth = 10
    private static let minimumElementSize: CGFloat = 6
    private static let minimumWindowSize: CGFloat = 24

    private static let actionableRoles: Set<String> = [
        kAXButtonRole,
        "AXLink",
        kAXTextFieldRole,
        kAXTextAreaRole,
        kAXCheckBoxRole,
        kAXRadioButtonRole,
        kAXPopUpButtonRole,
        kAXMenuButtonRole,
        kAXMenuItemRole
    ]

    private static let focusRoles: Set<String> = [
        kAXTextFieldRole,
        kAXTextAreaRole
    ]

    private static let largeTextTargetRoles: Set<String> = [
        kAXTextAreaRole
    ]
}

private extension CGRect {
    var isFinite: Bool {
        origin.x.isFinite
            && origin.y.isFinite
            && size.width.isFinite
            && size.height.isFinite
    }
}
