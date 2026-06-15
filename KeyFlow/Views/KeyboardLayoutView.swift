import SwiftUI

struct KeyboardLayoutView: View {
    @EnvironmentObject private var appState: AppState
    @State private var editingKey: KeyboardKey?

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
        .overlayPreferenceValue(KeyBoundsPreferenceKey.self) { keyBounds in
            GeometryReader { proxy in
                editorOverlay(keyBounds: keyBounds, in: proxy)
            }
        }
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
    private func editorOverlay(
        keyBounds: [String: Anchor<CGRect>],
        in proxy: GeometryProxy
    ) -> some View {
        if let editingKey, let keyAnchor = keyBounds[editingKey.id] {
            let keyFrame = proxy[keyAnchor]
            let placement = editorPlacement(for: keyFrame, in: proxy.size)

            ZStack(alignment: .topLeading) {
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture(perform: closeEditor)

                VStack(alignment: .leading, spacing: 0) {
                    if placement.arrowEdge == .top {
                        KeyEditorArrow()
                            .frame(width: Self.editorArrowWidth, height: Self.editorArrowHeight)
                            .offset(x: placement.arrowX - Self.editorArrowWidth / 2)
                    }

                    KeyActionPopover(
                        key: editingKey,
                        initialRule: appState.rule(for: editingKey),
                        launcherDisplayName: appState.launcherKey.displayName,
                        defaultAppIdentifier: appState.installedApps.first?.bundleIdentifier ?? "",
                        close: closeEditor
                    )
                    .id(editorID(for: editingKey))
                    .environmentObject(appState)
                    .frame(width: Self.editorWidth)
                    .liquidGlassPanel(
                        cornerRadius: 18,
                        tint: .white.opacity(0.09),
                        isElevated: true
                    )

                    if placement.arrowEdge == .bottom {
                        KeyEditorArrow()
                            .rotationEffect(.degrees(180))
                            .frame(width: Self.editorArrowWidth, height: Self.editorArrowHeight)
                            .offset(x: placement.arrowX - Self.editorArrowWidth / 2)
                    }
                }
                .frame(width: Self.editorWidth, alignment: .leading)
                .offset(x: placement.origin.x, y: placement.origin.y)
            }
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
        let rule = appState.rule(for: key)

        return KeyButton(
            key: key,
            rule: rule,
            isEditing: editingKey == key,
            openEditor: {
                openEditor(for: key)
            }
        )
        .frame(width: width ?? Self.keyWidth(for: key), height: height)
        .anchorPreference(key: KeyBoundsPreferenceKey.self, value: .bounds) { anchor in
            [key.id: anchor]
        }
    }

    private func openEditor(for key: KeyboardKey) {
        var transaction = Transaction()
        transaction.disablesAnimations = true
        transaction.animation = nil

        withTransaction(transaction) {
            appState.select(key)
            editingKey = key
        }
    }

    private func closeEditor() {
        var transaction = Transaction()
        transaction.disablesAnimations = true
        transaction.animation = nil

        withTransaction(transaction) {
            editingKey = nil
        }
    }

    private func editorID(for key: KeyboardKey) -> String {
        "\(appState.launcherKey.keyCode)-\(key.id)"
    }

    private func editorPlacement(
        for keyFrame: CGRect,
        in containerSize: CGSize
    ) -> KeyEditorPlacement {
        let totalHeight = Self.editorHeight + Self.editorArrowHeight
        let preferredX = keyFrame.midX - Self.editorWidth / 2
        let maxX = max(Self.editorMargin, containerSize.width - Self.editorWidth - Self.editorMargin)
        let originX = min(max(preferredX, Self.editorMargin), maxX)
        let arrowX = min(
            max(keyFrame.midX - originX, Self.editorArrowWidth),
            Self.editorWidth - Self.editorArrowWidth
        )

        let belowY = keyFrame.maxY + Self.editorKeyGap
        let aboveY = keyFrame.minY - Self.editorKeyGap - totalHeight

        if belowY + totalHeight <= containerSize.height - Self.editorMargin {
            return KeyEditorPlacement(
                origin: CGPoint(x: originX, y: belowY),
                arrowX: arrowX,
                arrowEdge: .top
            )
        }

        if aboveY >= Self.editorMargin {
            return KeyEditorPlacement(
                origin: CGPoint(x: originX, y: aboveY),
                arrowX: arrowX,
                arrowEdge: .bottom
            )
        }

        return KeyEditorPlacement(
            origin: CGPoint(
                x: originX,
                y: max(
                    Self.editorMargin,
                    min(
                        containerSize.height - Self.editorHeight - Self.editorMargin,
                        containerSize.height / 2 - Self.editorHeight / 2
                    )
                )
            ),
            arrowX: arrowX,
            arrowEdge: .none
        )
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
    static let editorWidth: CGFloat = 360
    static let editorHeight: CGFloat = 360
    static let editorArrowWidth: CGFloat = 18
    static let editorArrowHeight: CGFloat = 9
    static let editorKeyGap: CGFloat = 8
    static let editorMargin: CGFloat = 10
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
    let key: KeyboardKey
    let rule: KeyRule?
    let isEditing: Bool
    let openEditor: () -> Void

    var body: some View {
        Button {
            openEditor()
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
        .overlay(editingBorder)
    }

    @ViewBuilder
    private var ruleBorder: some View {
        if let rule {
            keyShape
                .strokeBorder(rule.action.kind.tint.opacity(0.64), lineWidth: 1.4)
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
}

private struct KeyBoundsPreferenceKey: PreferenceKey {
    static let defaultValue: [String: Anchor<CGRect>] = [:]

    static func reduce(
        value: inout [String: Anchor<CGRect>],
        nextValue: () -> [String: Anchor<CGRect>]
    ) {
        value.merge(nextValue(), uniquingKeysWith: { _, newValue in newValue })
    }
}

private struct KeyEditorPlacement {
    let origin: CGPoint
    let arrowX: CGFloat
    let arrowEdge: KeyEditorArrowEdge
}

private enum KeyEditorArrowEdge {
    case top
    case bottom
    case none
}

private struct KeyEditorArrow: View {
    var body: some View {
        KeyEditorArrowShape()
            .fill(.regularMaterial)
            .overlay {
                KeyEditorArrowShape()
                    .strokeBorder(.white.opacity(0.32), lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.08), radius: 3, y: 1)
    }
}

private struct KeyEditorArrowShape: InsettableShape {
    var insetAmount: CGFloat = 0

    func path(in rect: CGRect) -> Path {
        let rect = rect.insetBy(dx: insetAmount, dy: insetAmount)
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }

    func inset(by amount: CGFloat) -> KeyEditorArrowShape {
        var shape = self
        shape.insetAmount += amount
        return shape
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

    let key: KeyboardKey
    let initialRule: KeyRule?
    let launcherDisplayName: String
    let close: () -> Void

    @State private var selectedKind: ActionKind
    @State private var selectedAppIdentifier: String
    @State private var webName: String
    @State private var webURL: String
    @State private var commandName: String
    @State private var command: String

    init(
        key: KeyboardKey,
        initialRule: KeyRule?,
        launcherDisplayName: String,
        defaultAppIdentifier: String,
        close: @escaping () -> Void
    ) {
        self.key = key
        self.initialRule = initialRule
        self.launcherDisplayName = launcherDisplayName
        self.close = close

        var kind = ActionKind.app
        var appIdentifier = defaultAppIdentifier
        var urlName = "Website"
        var urlValue = "https://"
        var commandTitle = "Lock Screen"
        var commandValue = "/System/Library/CoreServices/Menu\\ Extras/User.menu/Contents/Resources/CGSession -suspend"

        if let initialRule {
            kind = initialRule.action.kind

            switch initialRule.action {
            case .openApp(let bundleIdentifier, _):
                appIdentifier = bundleIdentifier
            case .openURL(let name, let url):
                urlName = name
                urlValue = url
            case .runCommand(let name, let value):
                commandTitle = name
                commandValue = value
            }
        }

        _selectedKind = State(initialValue: kind)
        _selectedAppIdentifier = State(initialValue: appIdentifier)
        _webName = State(initialValue: urlName)
        _webURL = State(initialValue: urlValue)
        _commandName = State(initialValue: commandTitle)
        _command = State(initialValue: commandValue)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(launcherDisplayName) + \(key.label)")
                        .font(.system(size: 14, weight: .semibold))
                        .lineLimit(1)

                    Text(actionSummary)
                        .font(.system(size: 11, weight: .regular))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                if initialRule != nil {
                    Button(role: .destructive) {
                        appState.deleteRule(for: key)
                        close()
                    } label: {
                        Image(systemName: "trash")
                    }
                    .buttonStyle(.borderless)
                    .controlSize(.small)
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
            .controlSize(.small)

            form

            HStack(spacing: 8) {
                Spacer()
                Button("Cancel") {
                    close()
                }
                .controlSize(.small)

                Button("Save") {
                    appState.saveRule(for: key, action: buildAction())
                    close()
                }
                .liquidGlassButtonStyle(isProminent: true)
                .controlSize(.small)
                .disabled(!canSave)
            }
        }
        .padding(14)
        .onChange(of: appState.installedApps) { _, apps in
            if selectedKind == .app, selectedAppIdentifier.isEmpty {
                selectedAppIdentifier = apps.first?.bundleIdentifier ?? ""
            }
        }
    }

    @ViewBuilder
    private var form: some View {
        switch selectedKind {
        case .app:
            AppSelectionField(
                apps: appState.installedApps,
                selectedAppIdentifier: $selectedAppIdentifier
            )
        case .url:
            TextField("Name", text: $webName)
                .controlSize(.small)
            TextField("URL", text: $webURL)
                .controlSize(.small)
        case .command:
            TextField("Name", text: $commandName)
                .controlSize(.small)
            TextField("Command", text: $command, axis: .vertical)
                .lineLimit(2...4)
                .controlSize(.small)
        }
    }

    private var actionSummary: String {
        switch selectedKind {
        case .app:
            "Open application"
        case .url:
            "Open web link"
        case .command:
            "Run shell command"
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
}

private struct AppSelectionField: View {
    let apps: [InstalledApp]
    @Binding var selectedAppIdentifier: String

    @State private var query = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextField("Search apps", text: $query)
                .textFieldStyle(.roundedBorder)

            if apps.isEmpty {
                Text("No apps found.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else if visibleApps.isEmpty {
                Text("No matching apps.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                ScrollView {
                    LazyVStack(spacing: 2) {
                        ForEach(visibleApps) { app in
                            appRow(app)
                        }
                    }
                }
                .frame(maxHeight: 190)
            }
        }
    }

    private var visibleApps: [InstalledApp] {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let matches: [InstalledApp]

        if trimmedQuery.isEmpty {
            matches = apps
        } else {
            matches = apps.filter { app in
                app.name.localizedCaseInsensitiveContains(trimmedQuery)
                    || app.bundleIdentifier.localizedCaseInsensitiveContains(trimmedQuery)
            }
        }

        var visible = matches

        if
            let selectedApp,
            !visible.contains(where: { $0.bundleIdentifier == selectedApp.bundleIdentifier })
        {
            visible.insert(selectedApp, at: 0)
        }

        return visible
    }

    private var selectedApp: InstalledApp? {
        apps.first { $0.bundleIdentifier == selectedAppIdentifier }
    }

    private func appRow(_ app: InstalledApp) -> some View {
        Button {
            selectedAppIdentifier = app.bundleIdentifier
        } label: {
            HStack(spacing: 8) {
                Image(systemName: selectedAppIdentifier == app.bundleIdentifier ? "checkmark.circle.fill" : "app")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(selectedAppIdentifier == app.bundleIdentifier ? Color.accentColor : Color.secondary)
                    .frame(width: 18)

                Text(app.name)
                    .lineLimit(1)

                Spacer(minLength: 8)
            }
            .font(.system(size: 13))
            .padding(.horizontal, 8)
            .frame(height: 28)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background {
            if selectedAppIdentifier == app.bundleIdentifier {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Color.accentColor.opacity(0.12))
            }
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
