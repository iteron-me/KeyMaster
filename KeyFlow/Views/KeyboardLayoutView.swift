import AppKit
import SwiftUI

struct KeyboardLayoutView: View {
    @EnvironmentObject private var appState: AppState
    @State private var editingKey: KeyboardKey?
    @State private var menuPresenter: KeyActionMenuPopoverPresenter?

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            VStack(alignment: .leading, spacing: Self.spacing) {
                keyRow(KeyCatalog.defaultRows[0])
                keyRow(KeyCatalog.defaultRows[1])
                keyRow(KeyCatalog.defaultRows[2])
                keyRow(KeyCatalog.defaultRows[3])
                bottomRow
            }

            activeModifierOverlay
        }
        .frame(width: Self.contentWidth, alignment: .leading)
        .padding(14)
        .overlay {
            permissionOverlay
        }
        .transaction { transaction in
            transaction.animation = nil
            transaction.disablesAnimations = true
        }
    }

    @ViewBuilder
    private var permissionOverlay: some View {
        if !appState.permissionStatus.canRunShortcutEngine {
            ZStack {
                RoundedRectangle(cornerRadius: LiquidGlassStyle.panelRadius, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: LiquidGlassStyle.panelRadius, style: .continuous)
                            .fill(Color.black.opacity(0.18))
                    )

                Button {
                    appState.requestMissingPermissions()
                } label: {
                    Label("Grant Permissions", systemImage: "lock.open")
                        .font(.system(size: 14, weight: .semibold))
                        .padding(.horizontal, 8)
                        .frame(height: 38)
                }
                .buttonBorderShape(.capsule)
                .liquidGlassButtonStyle(isProminent: true)
                .help(permissionHelpText)
                .accessibilityLabel(permissionHelpText)
            }
            .contentShape(Rectangle())
        }
    }

    private var permissionHelpText: String {
        let missingPermissions = appState.permissionStatus.missingRequiredPermissionNames

        if missingPermissions.isEmpty {
            return "Permissions Granted"
        }

        return "Grant \(missingPermissions.joined(separator: " and ")) permission"
    }

    @ViewBuilder
    private var activeModifierOverlay: some View {
        if !appState.activeModifiers.isEmpty {
            ActiveModifierWatermark(modifiers: appState.activeModifiers)
                .padding(.leading, 12)
                .padding(.bottom, 8)
                .transition(.opacity)
                .allowsHitTesting(false)
        }
    }

    @ViewBuilder
    private func keyRow(_ keys: [KeyboardKey]) -> some View {
        HStack(spacing: Self.spacing) {
            ForEach(keys.indices, id: \.self) { index in
                let key = keys[index]

                keyButton(
                    key,
                    width: Self.keyWidth(
                        for: key,
                        at: index,
                        in: keys
                    )
                )
            }
        }
    }

    private var bottomRow: some View {
        HStack(alignment: .bottom, spacing: Self.spacing) {
            ForEach(Self.bottomLeftKeys) { key in
                keyButton(key)
            }

            keyButton(Self.spaceKey, width: Self.spaceKeyWidth)

            ForEach(Self.bottomRightKeys) { key in
                keyButton(key)
            }

            arrowCluster
        }
    }

    private var arrowCluster: some View {
        HStack(spacing: Self.spacing) {
            keyButton(Self.leftKey)

            VStack(spacing: Self.arrowStackSpacing) {
                keyButton(Self.upKey, height: Self.arrowHalfHeight)
                keyButton(Self.downKey, height: Self.arrowHalfHeight)
            }

            keyButton(Self.rightKey)
        }
    }

    private func keyButton(
        _ key: KeyboardKey,
        width: CGFloat? = nil,
        height: CGFloat = Self.keyHeight
    ) -> some View {
        let visibleRules = appState.visibleRules(for: key)
        let hasRules = appState.hasRules(for: key)

        return KeyButton(
            key: key,
            visibleRules: visibleRules,
            hasRules: hasRules,
            isLayerActive: !appState.activeModifiers.isEmpty,
            isModifierActive: isModifierKeyActive(key),
            isEditing: editingKey == key,
            openEditor: { sourceView in
                openEditor(for: key, from: sourceView)
            }
        )
        .frame(width: width ?? Self.keyWidth(for: key), height: height)
    }

    private func isModifierKeyActive(_ key: KeyboardKey) -> Bool {
        guard let modifier = key.activeModifier else {
            return false
        }

        if !appState.activeModifierKeyCodes.isEmpty {
            return appState.activeModifierKeyCodes.contains(key.keyCode)
        }

        return appState.activeModifiers.contains(modifier)
    }

    private func openEditor(for key: KeyboardKey, from sourceView: NSView) {
        var transaction = Transaction()
        transaction.disablesAnimations = true
        transaction.animation = nil

        withTransaction(transaction) {
            appState.select(key)
            editingKey = key
        }

        if menuPresenter == nil {
            menuPresenter = KeyActionMenuPopoverPresenter()
        }

        menuPresenter?.present(
            key: key,
            appState: appState,
            from: sourceView,
            close: closeEditor
        )
    }

    private func closeEditor() {
        var transaction = Transaction()
        transaction.disablesAnimations = true
        transaction.animation = nil

        withTransaction(transaction) {
            editingKey = nil
        }

        if menuPresenter != nil {
            let presenter = menuPresenter
            menuPresenter = nil
            presenter?.close()
        }
    }

    private static func keyWidth(for key: KeyboardKey) -> CGFloat {
        max(keyHeight, CGFloat(key.width) * keyUnitWidth)
    }

    private static func keyWidth(
        for key: KeyboardKey,
        at index: Int,
        in row: [KeyboardKey]
    ) -> CGFloat {
        let baseWidth = keyWidth(for: key)

        guard index == row.indices.last else {
            return baseWidth
        }

        return baseWidth + max(0, contentWidth - rowWidth(for: row))
    }

    static let keyUnitWidth: CGFloat = 46
    static let keyHeight: CGFloat = 46
    static let spacing: CGFloat = 6
    static let horizontalPadding: CGFloat = 14
    static let arrowStackSpacing: CGFloat = 2
    static let arrowHalfHeight: CGFloat = (keyHeight - arrowStackSpacing) / 2
    static let contentWidth: CGFloat = [
        rowWidth(for: KeyCatalog.defaultRows[0]),
        rowWidth(for: KeyCatalog.defaultRows[1]),
        rowWidth(for: KeyCatalog.defaultRows[2]),
        rowWidth(for: KeyCatalog.defaultRows[3])
    ].max() ?? 0
    static let panelWidth: CGFloat = contentWidth + horizontalPadding * 2
    static let panelHeight: CGFloat = keyHeight * 5 + spacing * 4 + horizontalPadding * 2

    private static let bottomRowKeys = KeyCatalog.defaultRows[4]
    private static let bottomLeftKeys = Array(bottomRowKeys.prefix(4))
    private static let spaceKey = bottomRowKeys[4]
    private static let bottomRightKeys = Array(bottomRowKeys[5...6])
    private static let leftKey = bottomRowKeys[7]
    private static let downKey = bottomRowKeys[8]
    private static let upKey = bottomRowKeys[9]
    private static let rightKey = bottomRowKeys[10]

    private static var arrowClusterWidth: CGFloat {
        keyHeight * 3 + spacing * 2
    }

    private static var spaceKeyWidth: CGFloat {
        contentWidth - fixedBottomRowWidthExcludingSpace
    }

    private static var fixedBottomRowWidthExcludingSpace: CGFloat {
        rowWidth(for: bottomLeftKeys)
            + rowWidth(for: bottomRightKeys)
            + arrowClusterWidth
            + spacing * 3
    }

    private static func rowWidth(for keys: [KeyboardKey]) -> CGFloat {
        guard !keys.isEmpty else {
            return 0
        }

        let keysWidth = keys.reduce(CGFloat.zero) { partialResult, key in
            partialResult + keyWidth(for: key)
        }

        return keysWidth + CGFloat(keys.count - 1) * spacing
    }
}

private struct KeyButton: View {
    let key: KeyboardKey
    let visibleRules: [KeyRule]
    let hasRules: Bool
    let isLayerActive: Bool
    let isModifierActive: Bool
    let isEditing: Bool
    let openEditor: (NSView) -> Void

    @GestureState private var isPressed = false
    @State private var isHovered = false
    @State private var sourceView: NSView?

    var body: some View {
        ZStack(alignment: .topTrailing) {
            KeyLegendView(key: key)
                .allowsHitTesting(false)

            if !isLayerActive, visibleRules.count > 1 {
                RuleBadgeStack(rules: visibleRules)
                    .padding(.top, 3)
                    .padding(.trailing, 4)
                    .allowsHitTesting(false)
            } else if let primaryRule = visibleRules.first {
                ActionBadge(action: primaryRule.action)
                    .padding(5)
                    .allowsHitTesting(false)
            }
        }
        .foregroundStyle(.primary)
        .keyboardKeySurface(
            tint: visibleRules.first?.action.kind.tint ?? (hasRules ? .secondary : nil),
            isPressed: isPressed,
            isHovered: isHovered
        )
        .overlay {
            activeModifierHighlight
                .allowsHitTesting(false)
        }
        .overlay {
            ruleBorder
                .allowsHitTesting(false)
        }
        .overlay {
            editingBorder
                .allowsHitTesting(false)
        }
        .background {
            KeyMenuSourceView(sourceView: $sourceView)
                .allowsHitTesting(false)
        }
        .gesture(pressGesture)
        .onHover { isHovered = $0 }
        .accessibilityElement()
        .accessibilityLabel(key.label)
        .accessibilityAddTraits(.isButton)
        .accessibilityAction {
            openEditorIfPossible()
        }
    }

    @ViewBuilder
    private var ruleBorder: some View {
        if let rule = visibleRules.first {
            keyShape
                .strokeBorder(rule.action.kind.tint.opacity(0.64), lineWidth: 1.4)
        } else if hasRules {
            keyShape
                .strokeBorder(Color.secondary.opacity(0.34), lineWidth: 1)
        }
    }

    @ViewBuilder
    private var activeModifierHighlight: some View {
        if isModifierActive {
            keyShape
                .fill(Color.accentColor.opacity(0.18))
                .overlay(
                    keyShape
                        .strokeBorder(Color.accentColor.opacity(0.82), lineWidth: 1.8)
                )
                .shadow(color: Color.accentColor.opacity(0.24), radius: 7, y: 2)
        }
    }

    @ViewBuilder
    private var editingBorder: some View {
        if isEditing {
            keyShape
                .strokeBorder(Color.accentColor.opacity(0.88), lineWidth: 2)
                .shadow(color: Color.accentColor.opacity(0.30), radius: 8)
        }
    }

    private var keyShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: LiquidGlassStyle.keyRadius, style: .continuous)
    }

    private var pressGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .updating($isPressed) { _, state, _ in
                state = true
            }
            .onEnded { value in
                guard value.translation.width.magnitude < 12,
                      value.translation.height.magnitude < 12
                else {
                    return
                }

                openEditorIfPossible()
            }
    }

    private func openEditorIfPossible() {
        guard let sourceView else {
            return
        }

        openEditor(sourceView)
    }

}

private struct KeyMenuSourceView: NSViewRepresentable {
    @Binding var sourceView: NSView?

    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        DispatchQueue.main.async {
            if sourceView !== view {
                sourceView = view
            }
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            if sourceView !== nsView {
                sourceView = nsView
            }
        }
    }
}

private struct KeyLegendView: View {
    let key: KeyboardKey

    var body: some View {
        Group {
            if key.usesCornerSymbolLegend {
                cornerSymbolLegend
            } else {
                inlineLegend
                    .frame(
                        maxWidth: .infinity,
                        maxHeight: .infinity,
                        alignment: key.labelAlignment
                    )
                    .padding(.horizontal, key.labelHorizontalPadding)
            }
        }
    }

    @ViewBuilder
    private var inlineLegend: some View {
        if let systemImage = key.systemImage {
            Image(systemName: systemImage)
                .font(.system(size: key.legendFontSize, weight: .medium))
                .symbolRenderingMode(.hierarchical)
        } else if let symbol = key.modifierSymbol {
            HStack(spacing: 4) {
                if key.isRightAligned {
                    legendText(key.label)
                    legendText(symbol, size: key.symbolFontSize)
                } else {
                    legendText(symbol, size: key.symbolFontSize)
                    legendText(key.label)
                }
            }
        } else {
            legendText(key.label)
        }
    }

    private var cornerSymbolLegend: some View {
        ZStack(alignment: .topTrailing) {
            legendText(key.label)
                .frame(
                    maxWidth: .infinity,
                    maxHeight: .infinity,
                    alignment: key.bottomLabelAlignment
                )
                .padding(.horizontal, key.labelHorizontalPadding)
                .padding(.bottom, 6)

            if let symbol = key.modifierSymbol {
                legendText(symbol, size: key.symbolFontSize)
                    .foregroundStyle(.secondary)
                    .padding(.top, 5)
                    .padding(.trailing, 7)
            }
        }
    }

    private func legendText(_ text: String, size: CGFloat? = nil) -> some View {
        Text(text)
            .font(.system(size: size ?? key.legendFontSize, weight: .medium))
            .lineLimit(1)
            .minimumScaleFactor(0.82)
    }
}

private struct ActionBadge: View {
    let action: KeyAction

    @State private var appIcon: NSImage?

    var body: some View {
        switch action {
        case .openApp(let bundleIdentifier, _):
            appBadge(bundleIdentifier: bundleIdentifier)
        case .openURL(let name, _):
            labelBadge(
                systemImage: ActionKind.url.systemImage,
                text: name,
                tint: .green
            )
        case .runCommand(let name, _):
            labelBadge(
                systemImage: ActionKind.command.systemImage,
                text: name,
                tint: .orange
            )
        case .sendKeyStroke(let keyStroke):
            labelBadge(
                systemImage: ActionKind.mapping.systemImage,
                text: keyStroke.displayTitle,
                tint: .purple
            )
        }
    }

    private func appBadge(bundleIdentifier: String) -> some View {
        Group {
            if let appIcon {
                Image(nsImage: appIcon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .padding(2)
            } else {
                Image(systemName: ActionKind.app.systemImage)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.white)
            }
        }
        .frame(width: 20, height: 20)
        .background(.thinMaterial, in: Circle())
        .overlay(
            Circle()
                .strokeBorder(Color.white.opacity(0.62), lineWidth: 0.8)
        )
        .shadow(color: .black.opacity(0.10), radius: 2, y: 1)
        .onAppear {
            loadAppIcon(bundleIdentifier: bundleIdentifier)
        }
        .onChange(of: bundleIdentifier) { _, newBundleIdentifier in
            loadAppIcon(bundleIdentifier: newBundleIdentifier)
        }
    }

    private func labelBadge(
        systemImage: String,
        text: String,
        tint: Color
    ) -> some View {
        HStack(spacing: 2) {
            Image(systemName: systemImage)
                .font(.system(size: 7, weight: .bold))
                .frame(width: 8)

            Text(text.badgeAbbreviation)
                .font(.system(size: 8, weight: .bold, design: .rounded))
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .foregroundStyle(.white)
        .frame(width: 38, height: 18)
        .background(tint.gradient, in: Capsule())
        .overlay(
            Capsule()
                .strokeBorder(Color.white.opacity(0.56), lineWidth: 0.8)
        )
        .shadow(color: .black.opacity(0.10), radius: 2, y: 1)
    }

    private func loadAppIcon(bundleIdentifier: String) {
        appIcon = nil

        AppIconCache.shared.icon(forBundleIdentifier: bundleIdentifier) { icon in
            appIcon = icon
        }
    }
}

private struct ActiveModifierWatermark: View {
    let modifiers: Set<ModifierKey>
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            ForEach(Self.outlineOffsets.indices, id: \.self) { index in
                let offset = Self.outlineOffsets[index]

                watermarkText
                    .foregroundStyle(outlineColor)
                    .offset(x: offset.x, y: offset.y)
            }

            watermarkText
                .foregroundStyle(fillColor)
        }
        .shadow(color: shadowColor, radius: 5, y: 2)
        .opacity(0.92)
        .compositingGroup()
        .lineLimit(1)
        .minimumScaleFactor(0.7)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(modifiers.displayTitle)
    }

    private var watermarkText: some View {
        Text(modifiers.displaySymbols)
            .font(.system(size: 34, weight: .bold, design: .rounded))
            .accessibilityLabel(modifiers.displayTitle)
    }

    private var fillColor: Color {
        if colorScheme == .dark {
            return Color.white.opacity(0.46)
        }

        return Color.black.opacity(0.30)
    }

    private var outlineColor: Color {
        if colorScheme == .dark {
            return Color.black.opacity(0.34)
        }

        return Color.white.opacity(0.64)
    }

    private var shadowColor: Color {
        colorScheme == .dark ? Color.black.opacity(0.24) : Color.black.opacity(0.08)
    }

    private static let outlineOffsets: [CGPoint] = [
        CGPoint(x: -1, y: -1),
        CGPoint(x: 0, y: -1),
        CGPoint(x: 1, y: -1),
        CGPoint(x: -1, y: 0),
        CGPoint(x: 1, y: 0),
        CGPoint(x: -1, y: 1),
        CGPoint(x: 0, y: 1),
        CGPoint(x: 1, y: 1)
    ]
}

private struct RuleBadgeStack: View {
    let rules: [KeyRule]

    var body: some View {
        VStack(alignment: .trailing, spacing: -3) {
            ForEach(Array(visibleRules.enumerated()), id: \.element.id) { _, rule in
                CompactActionBadge(action: rule.action)
            }

            if overflowCount > 0 {
                OverflowRuleBadge(count: overflowCount)
            }
        }
        .frame(width: 16, alignment: .topTrailing)
        .accessibilityLabel(accessibilityTitle)
    }

    private var visibleRules: [KeyRule] {
        let limit = rules.count > Self.visibleRuleLimit ? Self.overflowVisibleRuleLimit : Self.visibleRuleLimit
        return Array(rules.prefix(limit))
    }

    private var overflowCount: Int {
        max(rules.count - visibleRules.count, 0)
    }

    private var accessibilityTitle: String {
        "\(rules.count) assigned actions"
    }

    private static let visibleRuleLimit = 3
    private static let overflowVisibleRuleLimit = 2
}

private struct CompactActionBadge: View {
    let action: KeyAction

    var body: some View {
        Image(systemName: action.kind.systemImage)
            .font(.system(size: 8, weight: .bold))
            .symbolVariant(.fill)
            .symbolRenderingMode(.monochrome)
            .foregroundStyle(.white)
            .frame(width: 16, height: 16)
            .background(action.kind.tint.gradient, in: Circle())
            .overlay(
                Circle()
                    .strokeBorder(Color.white.opacity(0.58), lineWidth: 0.8)
            )
            .shadow(color: .black.opacity(0.10), radius: 2, y: 1)
            .help(action.displayTitle)
    }
}

private struct OverflowRuleBadge: View {
    let count: Int

    var body: some View {
        Text("+\(count)")
            .font(.system(size: 6.5, weight: .bold, design: .rounded))
            .foregroundStyle(.white)
            .lineLimit(1)
            .minimumScaleFactor(0.72)
            .frame(width: 16, height: 13)
            .background(Color.secondary.gradient, in: Capsule())
            .overlay(
                Capsule()
                    .strokeBorder(Color.white.opacity(0.56), lineWidth: 0.8)
            )
            .shadow(color: .black.opacity(0.10), radius: 2, y: 1)
    }
}

private extension String {
    var badgeAbbreviation: String {
        let words = split { !$0.isLetter && !$0.isNumber }
        let abbreviation: String

        if words.count >= 2 {
            abbreviation = words
                .prefix(2)
                .compactMap(\.first)
                .map(String.init)
                .joined()
        } else {
            abbreviation = String(prefix(3))
        }

        let trimmed = abbreviation.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "--" : trimmed.uppercased()
    }
}

private extension KeyboardKey {
    var systemImage: String? {
        switch id {
        case "left":
            "chevron.left"
        case "down":
            "chevron.down"
        case "up":
            "chevron.up"
        case "right":
            "chevron.right"
        default:
            nil
        }
    }

    var legendFontSize: CGFloat {
        if systemImage != nil {
            return 12
        }

        if modifierSymbol != nil && !usesCornerSymbolLegend {
            return 11
        }

        if Self.longLegendKeyIDs.contains(id) {
            return 12
        }

        return 14
    }

    var labelAlignment: Alignment {
        if isLeftAligned {
            return .leading
        }

        if isRightAligned {
            return .trailing
        }

        return .center
    }

    var bottomLabelAlignment: Alignment {
        if isRightAligned {
            return .bottomTrailing
        }

        return .bottomLeading
    }

    var labelHorizontalPadding: CGFloat {
        isLeftAligned || isRightAligned ? 10 : 0
    }

    var modifierSymbol: String? {
        switch id {
        case "tab":
            "⇥"
        case "caps":
            "⇪"
        case "shiftLeft", "shiftRight":
            "⇧"
        case "control":
            "⌃"
        case "option", "optionRight":
            "⌥"
        case "commandLeft", "commandRight":
            "⌘"
        case "delete":
            "⌫"
        case "return":
            "↩"
        default:
            nil
        }
    }

    var symbolFontSize: CGFloat {
        switch id {
        case "commandLeft", "commandRight":
            13
        default:
            12
        }
    }

    var activeModifier: ModifierKey? {
        switch id {
        case "control":
            .control
        case "option", "optionRight":
            .option
        case "commandLeft", "commandRight":
            .command
        case "shiftLeft", "shiftRight":
            .shift
        default:
            nil
        }
    }

    var isLeftAligned: Bool {
        Self.leftAlignedKeyIDs.contains(id)
    }

    var isRightAligned: Bool {
        Self.rightAlignedKeyIDs.contains(id)
    }

    var usesCornerSymbolLegend: Bool {
        Self.cornerSymbolKeyIDs.contains(id)
    }

    private static let leftAlignedKeyIDs: Set<String> = [
        "tab",
        "caps",
        "shiftLeft",
        "fn",
        "control",
        "option",
        "commandLeft"
    ]

    private static let rightAlignedKeyIDs: Set<String> = [
        "delete",
        "backslash",
        "return",
        "shiftRight",
        "commandRight",
        "optionRight"
    ]

    private static let cornerSymbolKeyIDs: Set<String> = [
        "control",
        "option",
        "commandLeft",
        "commandRight",
        "optionRight"
    ]

    private static let longLegendKeyIDs = leftAlignedKeyIDs
        .union(rightAlignedKeyIDs)
        .union(["space"])
}
