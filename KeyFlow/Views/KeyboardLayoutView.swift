import SwiftUI

struct KeyboardLayoutView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: Self.spacing) {
            keyRow(KeyCatalog.defaultRows[0])
            keyRow(KeyCatalog.defaultRows[1])
            keyRow(KeyCatalog.defaultRows[2])
            keyRow(KeyCatalog.defaultRows[3])
            bottomRow
        }
        .frame(width: Self.contentWidth, alignment: .leading)
        .padding(14)
        .liquidGlassPanel(
            cornerRadius: LiquidGlassStyle.panelRadius,
            tint: .white.opacity(0.08),
            isElevated: true
        )
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
        let rule = appState.rule(for: key)

        return KeyButton(
            key: key,
            rule: rule
        )
        .frame(width: width ?? Self.keyWidth(for: key), height: height)
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
    @EnvironmentObject private var appState: AppState
    @State private var isShowingEditor = false

    let key: KeyboardKey
    let rule: KeyRule?

    var body: some View {
        Button {
            appState.select(key)
            isShowingEditor = true
        } label: {
            ZStack(alignment: .topTrailing) {
                KeyLegendView(key: key)

                if let rule {
                    ActionBadge(kind: rule.action.kind)
                        .padding(5)
                }
            }
        }
        .foregroundStyle(.primary)
        .buttonStyle(KeyboardKeyButtonStyle(tint: rule?.action.kind.tint))
        .overlay(ruleBorder)
        .popover(isPresented: $isShowingEditor, arrowEdge: .bottom) {
            KeyActionPopover(key: key)
                .environmentObject(appState)
                .frame(width: 360)
        }
    }

    @ViewBuilder
    private var ruleBorder: some View {
        if let rule {
            keyShape
                .strokeBorder(rule.action.kind.tint.opacity(0.64), lineWidth: 1.4)
        }
    }

    private var keyShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: LiquidGlassStyle.keyRadius, style: .continuous)
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
    let kind: ActionKind

    var body: some View {
        Image(systemName: kind.systemImage)
            .font(.system(size: 10, weight: .bold))
            .foregroundStyle(.white)
            .frame(width: 18, height: 18)
            .background(kind.tint.gradient, in: Circle())
            .overlay(
                Circle()
                    .strokeBorder(.white.opacity(0.55), lineWidth: 0.8)
            )
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

private struct KeyActionPopover: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss

    let key: KeyboardKey

    @State private var selectedKind: ActionKind = .app
    @State private var selectedAppIdentifier = ""
    @State private var webName = "Website"
    @State private var webURL = "https://"
    @State private var commandName = "Lock Screen"
    @State private var command = "/System/Library/CoreServices/Menu\\ Extras/User.menu/Contents/Resources/CGSession -suspend"

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("\(appState.launcherKey.displayName) + \(key.label)")
                    .font(.headline)
                Spacer()
                if appState.rule(for: key) != nil {
                    Button(role: .destructive) {
                        appState.deleteRule(for: key)
                        dismiss()
                    } label: {
                        Image(systemName: "trash")
                    }
                    .buttonStyle(.borderless)
                }
            }

            Picker("Action", selection: $selectedKind) {
                ForEach(ActionKind.allCases) { kind in
                    Label(kind.title, systemImage: kind.systemImage)
                        .tag(kind)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            form

            HStack {
                Spacer()
                Button("Cancel") {
                    dismiss()
                }
                Button("Save") {
                    appState.saveRule(for: key, action: buildAction())
                    dismiss()
                }
                .liquidGlassButtonStyle(isProminent: true)
                .disabled(!canSave)
            }
        }
        .padding(18)
        .liquidGlassPanel(
            cornerRadius: 20,
            tint: .white.opacity(0.04),
            isElevated: true
        )
        .onAppear(perform: loadCurrentRule)
    }

    @ViewBuilder
    private var form: some View {
        switch selectedKind {
        case .app:
            Picker("App", selection: $selectedAppIdentifier) {
                ForEach(appState.installedApps) { app in
                    Text(app.name).tag(app.bundleIdentifier)
                }
            }
            .labelsHidden()
            .frame(maxWidth: .infinity)

            if appState.installedApps.isEmpty {
                Text("No apps found.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        case .url:
            TextField("Name", text: $webName)
            TextField("URL", text: $webURL)
        case .command:
            TextField("Name", text: $commandName)
            TextField("Command", text: $command, axis: .vertical)
                .lineLimit(3...6)
        }
    }

    private var canSave: Bool {
        switch selectedKind {
        case .app:
            !selectedAppIdentifier.isEmpty
        case .url:
            !webName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                && URL(string: webURL) != nil
        case .command:
            !commandName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                && !command.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }

    private func buildAction() -> KeyAction {
        switch selectedKind {
        case .app:
            let app = appState.installedApps.first { $0.bundleIdentifier == selectedAppIdentifier }
            return .openApp(
                bundleIdentifier: selectedAppIdentifier,
                displayName: app?.name ?? selectedAppIdentifier
            )
        case .url:
            return .openURL(name: webName, url: webURL)
        case .command:
            return .runCommand(name: commandName, command: command)
        }
    }

    private func loadCurrentRule() {
        if selectedAppIdentifier.isEmpty {
            selectedAppIdentifier = appState.installedApps.first?.bundleIdentifier ?? ""
        }

        guard let rule = appState.rule(for: key) else {
            return
        }

        selectedKind = rule.action.kind

        switch rule.action {
        case .openApp(let bundleIdentifier, _):
            selectedAppIdentifier = bundleIdentifier
        case .openURL(let name, let url):
            webName = name
            webURL = url
        case .runCommand(let name, let value):
            commandName = name
            command = value
        }
    }
}

private extension ActionKind {
    var tint: Color {
        switch self {
        case .app: .blue
        case .url: .green
        case .command: .orange
        }
    }
}
