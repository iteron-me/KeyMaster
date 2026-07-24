import ApplicationServices
import Foundation

struct ApplicationMenuCommand: Identifiable, Equatable, Sendable {
    let id: UUID
    let title: String
    let path: [String]
    let isEnabled: Bool
    let shortcut: String?
    let order: Int

    init(
        id: UUID = UUID(),
        title: String,
        path: [String],
        isEnabled: Bool = true,
        shortcut: String? = nil,
        order: Int
    ) {
        self.id = id
        self.title = title
        self.path = path
        self.isEnabled = isEnabled
        self.shortcut = shortcut
        self.order = order
    }

    var pathLabel: String {
        path.joined(separator: " > ")
    }
}

enum ApplicationMenuSearch {
    static func results(
        for query: String,
        in commands: [ApplicationMenuCommand],
        limit: Int = .max
    ) -> [ApplicationMenuCommand] {
        let tokens = query
            .split(whereSeparator: \.isWhitespace)
            .map { normalize(String($0)) }

        guard !tokens.isEmpty, limit > 0 else {
            return []
        }

        let normalizedQuery = tokens.joined(separator: " ")

        return commands
            .compactMap { command -> (ApplicationMenuCommand, Int)? in
                let title = normalize(command.title)
                let path = normalize(command.path.joined(separator: " "))

                guard tokens.allSatisfy({ title.contains($0) || path.contains($0) }) else {
                    return nil
                }

                let rank: Int
                if title == normalizedQuery {
                    rank = 0
                } else if title.hasPrefix(normalizedQuery) {
                    rank = 1
                } else if tokens.allSatisfy(title.contains) {
                    rank = 2
                } else {
                    rank = 3
                }

                return (command, rank)
            }
            .sorted { lhs, rhs in
                lhs.1 == rhs.1 ? lhs.0.order < rhs.0.order : lhs.1 < rhs.1
            }
            .prefix(limit)
            .map(\.0)
    }

    static func isExecutableLeaf(
        role: String?,
        title: String?,
        hasSubmenu: Bool,
        supportsExecution: Bool
    ) -> Bool {
        role == kAXMenuItemRole
            && !(title?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
            && !hasSubmenu
            && supportsExecution
    }

    static func preferredExecutionAction(in actions: [String]) -> String? {
        if actions.contains(kAXPickAction) {
            return kAXPickAction
        }
        return actions.contains(kAXPressAction) ? kAXPressAction : nil
    }

    static func isSystemAppleMenu(role: String?, title: String?, identifier: String?) -> Bool {
        role == kAXMenuBarItemRole
            && title == "Apple"
            && (identifier?.isEmpty ?? true)
    }

    static func shortcutCharacterLabel(_ character: String?) -> String? {
        guard let character = character?.trimmingCharacters(in: .whitespacesAndNewlines),
              !character.isEmpty
        else {
            return nil
        }

        switch character {
        case "\u{F700}": return "↑"
        case "\u{F701}": return "↓"
        case "\u{F702}": return "←"
        case "\u{F703}": return "→"
        default:
            if let scalar = character.unicodeScalars.first,
               character.unicodeScalars.count == 1,
               (0xF704...0xF726).contains(scalar.value) {
                return "F\(scalar.value - 0xF703)"
            }
            guard !character.unicodeScalars.contains(where: {
                (0xE000...0xF8FF).contains($0.value)
            }) else {
                return nil
            }
            return character.uppercased()
        }
    }

    private static func normalize(_ value: String) -> String {
        value.folding(options: [.caseInsensitive], locale: nil)
    }
}

actor ApplicationMenuSession {
    private let processID: pid_t
    private var locatorsByID: [UUID: MenuItemLocator] = [:]

    init(processID: pid_t) {
        self.processID = processID
    }

    func scan() -> [ApplicationMenuCommand] {
        locatorsByID.removeAll()

        let application = AXUIElementCreateApplication(processID)
        guard let menuBar = elementAttribute(application, kAXMenuBarAttribute) else {
            return []
        }

        var commands: [ApplicationMenuCommand] = []
        var stack = children(of: menuBar)
            .enumerated()
            .filter {
                !ApplicationMenuSearch.isSystemAppleMenu(
                    role: stringAttribute($0.element, kAXRoleAttribute),
                    title: stringAttribute($0.element, kAXTitleAttribute),
                    identifier: stringAttribute($0.element, kAXIdentifierAttribute)
                )
            }
            .reversed()
            .map {
                PendingElement(
                    element: $0.element,
                    path: [],
                    childIndexes: [$0.offset],
                    depth: 0
                )
            }
        var visited = Set<CFHashCode>()
        var visitedCount = 0

        while let pending = stack.popLast(),
              visitedCount < Self.maxVisitedElements,
              commands.count < Self.maxCommands {
            guard !Task.isCancelled else {
                break
            }

            let hash = CFHash(pending.element)
            guard visited.insert(hash).inserted else {
                continue
            }
            visitedCount += 1

            let role = stringAttribute(pending.element, kAXRoleAttribute)
            let title = stringAttribute(pending.element, kAXTitleAttribute)
            let children = children(of: pending.element)
            let hasSubmenu = children.contains {
                let childRole = stringAttribute($0, kAXRoleAttribute)
                return childRole == kAXMenuRole || childRole == kAXMenuItemRole
            }
            let executionAction = ApplicationMenuSearch.preferredExecutionAction(
                in: actionNames(of: pending.element)
            )

            if ApplicationMenuSearch.isExecutableLeaf(
                role: role,
                title: title,
                hasSubmenu: hasSubmenu,
                supportsExecution: executionAction != nil
            ), let title {
                let id = UUID()
                locatorsByID[id] = MenuItemLocator(
                    childIndexes: pending.childIndexes,
                    title: title
                )
                commands.append(
                    ApplicationMenuCommand(
                        id: id,
                        title: title,
                        path: pending.path,
                        isEnabled: boolAttribute(pending.element, kAXEnabledAttribute) ?? true,
                        shortcut: shortcutLabel(for: pending.element),
                        order: commands.count
                    )
                )
            }

            guard pending.depth < Self.maxTraversalDepth else {
                continue
            }

            var childPath = pending.path
            if let title,
               !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
               role == kAXMenuBarItemRole || (role == kAXMenuItemRole && hasSubmenu) {
                childPath.append(title)
            }

            for (index, child) in children.enumerated().reversed() {
                stack.append(
                    PendingElement(
                        element: child,
                        path: childPath,
                        childIndexes: pending.childIndexes + [index],
                        depth: pending.depth + 1
                    )
                )
            }
        }

        return commands
    }

    func perform(commandID: UUID) -> Bool {
        let application = AXUIElementCreateApplication(processID)
        guard let locator = locatorsByID[commandID],
              let menuBar = elementAttribute(application, kAXMenuBarAttribute),
              let element = element(at: locator.childIndexes, from: menuBar),
              stringAttribute(element, kAXTitleAttribute) == locator.title,
              let action = ApplicationMenuSearch.preferredExecutionAction(
                  in: actionNames(of: element)
              )
        else {
            return false
        }

        return AXUIElementPerformAction(element, action as CFString) == .success
    }

    func clear() {
        locatorsByID.removeAll()
    }

    private func element(at childIndexes: [Int], from root: AXUIElement) -> AXUIElement? {
        var element = root
        for index in childIndexes {
            let children = children(of: element)
            guard children.indices.contains(index) else {
                return nil
            }
            element = children[index]
        }
        return element
    }

    private func shortcutLabel(for element: AXUIElement) -> String? {
        let character = stringAttribute(element, kAXMenuItemCmdCharAttribute)
        let glyph = integerAttribute(element, kAXMenuItemCmdGlyphAttribute)
        let virtualKey = integerAttribute(element, kAXMenuItemCmdVirtualKeyAttribute)
        let key = ApplicationMenuSearch.shortcutCharacterLabel(character)
            ?? glyph.flatMap(Self.glyphLabel)
            ?? virtualKey.map(KeyCatalog.displayName)

        guard let key else {
            return nil
        }

        let modifiers = integerAttribute(element, kAXMenuItemCmdModifiersAttribute) ?? 0
        var label = ""
        if modifiers & 4 != 0 { label += "⌃" }
        if modifiers & 2 != 0 { label += "⌥" }
        if modifiers & 1 != 0 { label += "⇧" }
        if modifiers & 8 == 0 { label += "⌘" }
        return label + key
    }

    private func children(of element: AXUIElement) -> [AXUIElement] {
        attributeValue(element, kAXChildrenAttribute) as? [AXUIElement] ?? []
    }

    private func actionNames(of element: AXUIElement) -> [String] {
        var names: CFArray?
        guard AXUIElementCopyActionNames(element, &names) == .success else {
            return []
        }
        return names as? [String] ?? []
    }

    private func attributeValue(_ element: AXUIElement, _ attribute: String) -> AnyObject? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success else {
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

    private func integerAttribute(_ element: AXUIElement, _ attribute: String) -> Int? {
        (attributeValue(element, attribute) as? NSNumber)?.intValue
    }

    private func elementAttribute(_ element: AXUIElement, _ attribute: String) -> AXUIElement? {
        guard let value = attributeValue(element, attribute),
              CFGetTypeID(value) == AXUIElementGetTypeID()
        else {
            return nil
        }
        return (value as! AXUIElement)
    }

    private struct PendingElement {
        let element: AXUIElement
        let path: [String]
        let childIndexes: [Int]
        let depth: Int
    }

    private struct MenuItemLocator {
        let childIndexes: [Int]
        let title: String
    }

    private static func glyphLabel(_ glyph: Int) -> String? {
        switch glyph {
        case 0x04, 0x0B, 0x0C, 0x0D: "↩"
        case 0x09: "Space"
        case 0x0A: "⌦"
        case 0x17: "⌫"
        case 0x1B: "Esc"
        case 0x62: "Page Up"
        case 0x64: "←"
        case 0x65: "→"
        case 0x68: "↑"
        case 0x6A: "↓"
        case 0x6B: "Page Down"
        case 0x6F...0x7A: "F\(glyph - 0x6E)"
        default: nil
        }
    }

    private static let maxVisitedElements = 4_000
    private static let maxTraversalDepth = 16
    private static let maxCommands = 2_000
}
