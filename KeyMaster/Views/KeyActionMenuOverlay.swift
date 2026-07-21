import AppKit
import SwiftUI

struct KeyActionMenuContent: View {
    let key: KeyboardKey
    let placementEdge: NSRectEdge
    let close: () -> Void
    var activeKindChanged: (ActionKind?) -> Void = { _ in }

    @EnvironmentObject private var appState: AppState
    @State private var activeKind: ActionKind?
    @State private var editingModifiers: Set<ModifierKey> = [.control]

    var body: some View {
        HStack(alignment: .top, spacing: ActionMenuMetrics.menuGap) {
            if isLeadingSubmenu {
                submenuSlot
            }

            ActionKindMenu(
                key: key,
                modifiers: $editingModifiers,
                activeKind: $activeKind,
                submenuPlacementEdge: placementEdge,
                close: close
            )

            if !isLeadingSubmenu {
                submenuSlot
            }
        }
        .frame(
            width: ActionMenuMetrics.contentWidth(hasSubmenu: true),
            height: ActionMenuMetrics.maxHeight,
            alignment: .leading
        )
        .padding(ActionMenuMetrics.contentPadding)
        .contentShape(Rectangle())
        .onChange(of: activeKind) { _, newValue in
            activeKindChanged(newValue)
        }
        .onAppear {
            if !appState.activeModifiers.isEmpty {
                editingModifiers = appState.activeModifiers
            } else {
                editingModifiers = [.control]
            }
        }
    }

    @ViewBuilder
    private var submenuSlot: some View {
        if let activeKind {
            ActionKindSubmenu(
                key: key,
                modifiers: editingModifiers,
                kind: activeKind,
                close: close
            )
        } else {
            Color.clear
                .frame(
                    width: ActionMenuMetrics.submenuOuterWidth,
                    height: ActionMenuMetrics.submenuHeight
                )
        }
    }

    private var isLeadingSubmenu: Bool {
        placementEdge == .minX
    }
}

private struct ActionKindMenu: View {
    let key: KeyboardKey
    @Binding var modifiers: Set<ModifierKey>
    @Binding var activeKind: ActionKind?
    let submenuPlacementEdge: NSRectEdge
    let close: () -> Void

    @EnvironmentObject private var appState: AppState
    @State private var isRemoveHovered = false

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            RuleBindingStrip(
                key: key,
                selectedModifiers: modifiers,
                currentRule: currentRule,
                select: { selectedModifiers in
                    modifiers = selectedModifiers
                    activeKind = appState.rule(for: key, modifiers: selectedModifiers)?.action.kind
                }
            )
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .onHover { isHovering in
                if isHovering {
                    activeKind = nil
                }
            }

            Divider()

            ForEach(ActionKind.allCases) { kind in
                ActionMenuKindRow(
                    kind: kind,
                    isActive: activeKind == kind,
                    submenuPlacementEdge: submenuPlacementEdge,
                    hover: { isHovering in
                        if isHovering {
                            activeKind = kind
                        }
                    },
                    select: {
                        activeKind = kind
                    }
                )
            }

            if currentRule != nil {
                Divider()

                Button {
                    appState.deleteRule(for: key, modifiers: modifiers)
                    close()
                } label: {
                    Label("Remove", systemImage: "trash")
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)
                .foregroundStyle(isRemoveHovered ? .white : .red)
                .padding(.horizontal, 10)
                .frame(height: 30)
                .contentShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                .background {
                    if isRemoveHovered {
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(Color.red)
                    }
                }
                .onHover { isHovering in
                    isRemoveHovered = isHovering

                    if isHovering {
                        activeKind = nil
                    }
                }
            }
        }
        .frame(width: ActionMenuMetrics.primaryWidth, alignment: .leading)
        .padding(6)
        .actionMenuSurface()
    }

    private var currentRule: KeyRule? {
        appState.rule(for: key, modifiers: modifiers)
    }
}

private struct RuleBindingStrip: View {
    let key: KeyboardKey
    let selectedModifiers: Set<ModifierKey>
    let currentRule: KeyRule?
    let select: (Set<ModifierKey>) -> Void

    @EnvironmentObject private var appState: AppState

    var body: some View {
        FlowLayout(spacing: 5, rowSpacing: 5) {
            if !hasSelectedRule {
                BindingSummaryCapsule(
                    trigger: selectedTrigger,
                    action: nil,
                    tint: .secondary,
                    isSelected: true,
                    select: {}
                )
            }

            ForEach(rules) { rule in
                BindingSummaryCapsule(
                    trigger: rule.trigger,
                    action: rule.action,
                    tint: rule.action.kind.tint,
                    isSelected: rule.trigger.modifiers == selectedModifiers,
                    select: {
                        select(rule.trigger.modifiers)
                    }
                )
            }
        }
        .frame(width: ActionMenuMetrics.bindingStripWidth, alignment: .leading)
    }

    private var rules: [KeyRule] {
        appState.rules(for: key)
    }

    private var hasSelectedRule: Bool {
        currentRule != nil
    }

    private var selectedTrigger: KeyTrigger {
        KeyTrigger(
            modifiers: selectedModifiers,
            keyCode: key.keyCode,
            keyDisplayName: key.label
        )
    }
}

private struct BindingSummaryCapsule: View {
    let trigger: KeyTrigger
    let action: KeyAction?
    let tint: Color
    let isSelected: Bool
    let select: () -> Void

    var body: some View {
        Button {
            select()
        } label: {
            HStack(spacing: 5) {
                Text(trigger.badgeTitle)
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)

                Image(systemName: "arrow.right")
                    .font(.system(size: 9, weight: .bold))
                    .imageScale(.small)
                    .opacity(0.82)

                BindingActionSummary(action: action, tint: tint, isSelected: isSelected)
            }
            .foregroundStyle(isSelected ? .white : tint)
            .padding(.horizontal, 7)
            .frame(height: ActionMenuMetrics.bindingCapsuleHeight)
            .background {
                Capsule()
                    .fill(isSelected ? tint : tint.opacity(0.13))
            }
            .overlay {
                Capsule()
                    .strokeBorder(tint.opacity(isSelected ? 0.20 : 0.26), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .help(helpTitle)
    }

    private var helpTitle: String {
        if let action {
            return "\(trigger.displayTitle) -> \(action.displayTitle)"
        }

        return "\(trigger.displayTitle) -> No action"
    }
}

private struct BindingActionSummary: View {
    let action: KeyAction?
    let tint: Color
    let isSelected: Bool

    var body: some View {
        Group {
            switch action {
            case .openApp(let bundleIdentifier, let displayName):
                BindingAppIcon(bundleIdentifier: bundleIdentifier)
                    .help(displayName)
            case .openURL(let name, _):
                titledAction(kind: .url, title: name)
            case .runCommand(let name, _):
                titledAction(kind: .command, title: name)
            case .runTool(let invocation):
                toolAction(invocation)
            case .lockScreen:
                titledAction(kind: .command, title: KeyAction.lockScreenDisplayTitle)
            case .sendKeyStroke(let keyStroke):
                Text(keyStroke.compactDisplayTitle)
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
            case nil:
                Image(systemName: "circle.dashed")
                    .font(.system(size: 10, weight: .semibold))
                    .frame(width: 14, height: 14)
            }
        }
        .foregroundStyle(isSelected ? .white : tint)
    }

    private func titledAction(kind: ActionKind, title: String) -> some View {
        HStack(spacing: 3) {
            ActionKindIcon(
                kind: kind,
                color: isSelected ? .white : kind.tint,
                size: 13
            )

            Text(title)
                .font(.system(size: 11, weight: .bold))
                .lineLimit(1)
                .minimumScaleFactor(0.78)
                .frame(maxWidth: ActionMenuMetrics.bindingTitleMaxWidth, alignment: .leading)
        }
    }

    private func toolAction(_ invocation: ToolInvocation) -> some View {
        HStack(spacing: 3) {
            Image(systemName: ToolRegistry.shared.tool(for: invocation.toolID)?.systemImage ?? "wrench.and.screwdriver.fill")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(isSelected ? .white : ActionKind.command.tint)
                .frame(width: 13, height: 13)

            Text(invocation.displayName)
                .font(.system(size: 11, weight: .bold))
                .lineLimit(1)
                .minimumScaleFactor(0.78)
                .frame(maxWidth: ActionMenuMetrics.bindingTitleMaxWidth, alignment: .leading)
        }
    }
}

private struct BindingAppIcon: View {
    let bundleIdentifier: String

    @State private var appIcon: NSImage?

    var body: some View {
        Group {
            if let appIcon {
                Image(nsImage: appIcon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } else {
                Image(systemName: ActionKind.app.systemImage)
                    .font(.system(size: 11, weight: .semibold))
                    .symbolVariant(.fill)
            }
        }
        .frame(width: 16, height: 16)
        .onAppear {
            loadAppIcon(bundleIdentifier: bundleIdentifier)
        }
        .onChange(of: bundleIdentifier) { _, newBundleIdentifier in
            loadAppIcon(bundleIdentifier: newBundleIdentifier)
        }
    }

    private func loadAppIcon(bundleIdentifier: String) {
        appIcon = nil

        AppIconCache.shared.icon(forBundleIdentifier: bundleIdentifier) { icon in
            appIcon = icon
        }
    }
}

private struct FlowLayout: Layout {
    let spacing: CGFloat
    let rowSpacing: CGFloat

    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout Void
    ) -> CGSize {
        layout(
            subviews: subviews,
            width: proposal.width ?? .infinity
        )
        .size
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout Void
    ) {
        let result = layout(subviews: subviews, width: bounds.width)

        for item in result.items {
            subviews[item.index].place(
                at: CGPoint(
                    x: bounds.minX + item.origin.x,
                    y: bounds.minY + item.origin.y
                ),
                proposal: ProposedViewSize(item.size)
            )
        }
    }

    private func layout(subviews: Subviews, width: CGFloat) -> FlowLayoutResult {
        guard !subviews.isEmpty else {
            return FlowLayoutResult(size: .zero, items: [])
        }

        let maxWidth = width.isFinite ? width : CGFloat.greatestFiniteMagnitude
        var items: [FlowLayoutResult.Item] = []
        var origin = CGPoint.zero
        var rowHeight = CGFloat.zero
        var layoutWidth = CGFloat.zero

        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)

            if origin.x > 0, origin.x + size.width > maxWidth {
                origin.x = 0
                origin.y += rowHeight + rowSpacing
                rowHeight = 0
            }

            items.append(
                FlowLayoutResult.Item(
                    index: index,
                    origin: origin,
                    size: size
                )
            )

            layoutWidth = max(layoutWidth, origin.x + size.width)
            origin.x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }

        return FlowLayoutResult(
            size: CGSize(width: min(layoutWidth, maxWidth), height: origin.y + rowHeight),
            items: items
        )
    }
}

private struct FlowLayoutResult {
    struct Item {
        var index: Int
        var origin: CGPoint
        var size: CGSize
    }

    var size: CGSize
    var items: [Item]
}

private struct ActionKindIcon: View {
    let kind: ActionKind
    let color: Color
    let size: CGFloat

    var body: some View {
        Image(systemName: kind.systemImage)
            .font(.system(size: symbolSize, weight: .semibold))
            .symbolVariant(.fill)
            .symbolRenderingMode(.monochrome)
            .foregroundStyle(color)
            .frame(width: size, height: size)
            .imageScale(.medium)
    }

    private var symbolSize: CGFloat {
        size * 0.82
    }
}

private struct ActionMenuKindRow: View {
    let kind: ActionKind
    let isActive: Bool
    let submenuPlacementEdge: NSRectEdge
    let hover: (Bool) -> Void
    let select: () -> Void

    @State private var isHovered = false

    private var isHighlighted: Bool {
        isHovered || isActive
    }

    var body: some View {
        Button {
            select()
        } label: {
            rowLabel
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
        .onHover { hovering in
            guard hovering != isHovered else {
                return
            }

            isHovered = hovering
            hover(hovering)
        }
    }

    private var rowLabel: some View {
        HStack(spacing: 8) {
            if isLeadingSubmenu {
                submenuChevron
            }

            ActionKindIcon(
                kind: kind,
                color: isHighlighted ? .white : kind.tint,
                size: 18
            )

            Text(kind.title)
                .font(.system(size: 12, weight: .medium))

            Spacer(minLength: 6)

            if !isLeadingSubmenu {
                submenuChevron
            }
        }
        .foregroundStyle(isHighlighted ? .white : .primary)
        .padding(.horizontal, 8)
        .frame(maxWidth: .infinity, minHeight: 30, maxHeight: 30, alignment: .leading)
        .contentShape(Rectangle())
        .background {
            if isHighlighted {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Color.accentColor)
            }
        }
    }

    private var submenuChevron: some View {
        Image(systemName: submenuChevronName)
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(isHighlighted ? .white.opacity(0.85) : .secondary)
            .frame(width: 10)
    }

    private var isLeadingSubmenu: Bool {
        submenuPlacementEdge == .minX
    }

    private var submenuChevronName: String {
        isLeadingSubmenu ? "chevron.left" : "chevron.right"
    }
}

private struct ActionKindSubmenu: View {
    let key: KeyboardKey
    let modifiers: Set<ModifierKey>
    let kind: ActionKind
    let close: () -> Void

    @EnvironmentObject private var appState: AppState

    var body: some View {
        Group {
            switch kind {
            case .app:
                AppActionPicker(
                    selectedBundleIdentifier: currentRule?.action.selectedAppBundleIdentifier,
                    select: save(app:)
                )
            case .url:
                HistoryActionPicker(
                    emptyTitle: "No Website History",
                    addTitle: "New Website",
                    valuePlaceholder: "URL",
                    initialValue: "https://",
                    iconName: ActionKind.url.systemImage,
                    tint: .green,
                    rows: appState.actionHistory.webItems.map { item in
                        HistoryActionMenuRow(
                            id: item.id,
                            title: item.name,
                            subtitle: item.url,
                            isSelected: item == currentRule?.action.selectedWebItem,
                            select: {
                                save(webItem: item)
                            },
                            delete: {
                                appState.deleteWebHistoryItem(item)
                            }
                        )
                    },
                    isValid: { name, value in
                        !name.isEmpty && URL(string: value) != nil
                    },
                    saveNewItem: { name, value in
                        save(webItem: WebActionHistoryItem(name: name, url: value))
                    }
                )
            case .command:
                CommandActionPicker(
                    toolRows: toolRows,
                    commandRows: commandRows,
                    saveNewCommand: { name, value in
                        save(commandItem: CommandActionHistoryItem(name: name, command: value))
                    }
                )
            case .mapping:
                KeyMappingPicker(
                    selectedKeyStroke: currentRule?.action.selectedKeyStroke,
                    select: save(keyStroke:)
                )
            }
        }
        .id(kind)
    }

    private var currentRule: KeyRule? {
        appState.rule(for: key, modifiers: modifiers)
    }

    private var commandRows: [HistoryActionMenuRow] {
        let selectedItem = currentRule?.action.selectedCommandItem
        let historyRows = appState.actionHistory.commandItems
            .map { item in
                HistoryActionMenuRow(
                    id: "history|\(item.id)",
                    title: item.name,
                    subtitle: item.command,
                    isSelected: item == selectedItem,
                    select: {
                        save(commandItem: item)
                    },
                    delete: {
                        appState.deleteCommandHistoryItem(item)
                    }
                )
            }

        return [
            HistoryActionMenuRow(
                id: "preset|lockScreen",
                title: KeyAction.lockScreenDisplayTitle,
                subtitle: KeyAction.lockScreenPresetSubtitle,
                isSelected: currentRule?.action == .lockScreen || selectedItem?.isLegacyLockScreenPreset == true,
                select: {
                    saveLockScreen()
                },
                delete: nil
            )
        ] + historyRows
    }

    private var toolRows: [BuiltInToolMenuRow] {
        ToolRegistry.shared.tools.map { tool in
            BuiltInToolMenuRow(
                id: tool.id,
                title: tool.title,
                subtitle: tool.subtitle,
                systemImage: tool.systemImage,
                isSelected: currentRule?.action.selectedToolID == tool.id,
                select: {
                    save(toolInvocation: tool.defaultInvocation)
                }
            )
        }
    }

    private func save(app: InstalledApp) {
        appState.saveRule(
            for: key,
            modifiers: modifiers,
            action: .openApp(
                bundleIdentifier: app.bundleIdentifier,
                displayName: app.name
            )
        )
        close()
    }

    private func save(webItem item: WebActionHistoryItem) {
        appState.saveRule(for: key, modifiers: modifiers, action: .openURL(name: item.name, url: item.url))
        close()
    }

    private func save(commandItem item: CommandActionHistoryItem) {
        appState.saveRule(for: key, modifiers: modifiers, action: .runCommand(name: item.name, command: item.command))
        close()
    }

    private func save(toolInvocation invocation: ToolInvocation) {
        appState.saveRule(for: key, modifiers: modifiers, action: .runTool(invocation))
        close()
    }

    private func saveLockScreen() {
        appState.saveRule(for: key, modifiers: modifiers, action: .lockScreen)
        close()
    }

    private func save(keyStroke: KeyStroke) {
        appState.saveRule(for: key, modifiers: modifiers, action: .sendKeyStroke(keyStroke))
        close()
    }
}

private struct AppActionPicker: View {
    let selectedBundleIdentifier: String?
    let select: (InstalledApp) -> Void

    @EnvironmentObject private var appState: AppState
    @State private var query = ""

    var body: some View {
        VStack(spacing: 7) {
            TextField("Search apps", text: $query)
                .textFieldStyle(.roundedBorder)

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    if matchingApps.isEmpty {
                        ActionMenuEmptyState(title: appState.installedApps.isEmpty ? "Loading Apps..." : "No Apps Found")
                    } else {
                        ForEach(matchingApps) { app in
                            AppActionRow(
                                app: app,
                                isSelected: app.bundleIdentifier == selectedBundleIdentifier,
                                select: {
                                    select(app)
                                }
                            )
                        }
                    }
                }
                .padding(.vertical, 2)
                .frame(maxWidth: .infinity, alignment: .topLeading)
            }
            .contentShape(Rectangle())
            .background(Color.primary.opacity(0.001))
            .frame(height: ActionMenuMetrics.appListHeight)
        }
        .frame(width: ActionMenuMetrics.submenuWidth)
        .padding(ActionMenuMetrics.padding)
        .actionMenuSurface()
    }

    private var matchingApps: [InstalledApp] {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedQuery.isEmpty else {
            return appState.installedApps
        }

        return appState.installedApps.filter {
            $0.name.localizedCaseInsensitiveContains(trimmedQuery)
                || $0.bundleIdentifier.localizedCaseInsensitiveContains(trimmedQuery)
        }
    }
}

private struct AppActionRow: View {
    let app: InstalledApp
    let isSelected: Bool
    let select: () -> Void

    @State private var icon: NSImage?

    var body: some View {
        ActionMenuRow(
            title: app.name,
            subtitle: nil,
            systemImage: nil,
            image: icon,
            tint: .accentColor,
            isSelected: isSelected,
            select: select
        )
        .help(app.name)
        .onAppear {
            icon = AppIconCache.shared.cachedIcon(for: app)
            AppIconCache.shared.icon(for: app) { loadedIcon in
                icon = loadedIcon
            }
        }
    }
}

private struct KeyMappingPicker: View {
    let selectedKeyStroke: KeyStroke?
    let select: (KeyStroke) -> Void

    @State private var capturedKeyStroke: KeyStroke?
    @State private var isCapturing = false
    @State private var targetModifiers: Set<ModifierKey> = []
    @State private var monitor: Any?

    private var currentKeyStroke: KeyStroke? {
        capturedKeyStroke ?? selectedKeyStroke
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                toggleCapture()
            } label: {
                Label(isCapturing ? "Press Target Keys" : "Record Target", systemImage: "record.circle")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(ActionMenuPlainButtonStyle(tint: .purple))

            VStack(alignment: .leading, spacing: 4) {
                Text("Target")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)

                HStack(spacing: 8) {
                    ActionKindIcon(kind: .mapping, color: .purple, size: 18)

                    Text(currentKeyStroke?.displayTitle ?? "No target key")
                        .font(.system(size: 13, weight: .medium))
                        .lineLimit(1)

                    Spacer(minLength: 6)
                }
                .padding(.horizontal, 8)
                .frame(height: 36)
                .background(Color.purple.opacity(0.12), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
            }

            Divider()

            CompactTargetKeyboard(
                modifiers: targetModifiers,
                select: { key in
                    capturedKeyStroke = KeyStroke(
                        modifiers: targetModifiers,
                        keyCode: key.keyCode,
                        keyDisplayName: key.label
                    )
                }
            )

            Spacer(minLength: 0)

            HStack(spacing: 8) {
                Spacer()

                Button {
                    if let currentKeyStroke {
                        select(currentKeyStroke)
                    }
                } label: {
                    Label("Save", systemImage: "checkmark")
                        .frame(width: 68)
                }
                .buttonStyle(ActionMenuFormButtonStyle(tint: .purple, role: .primary))
                .disabled(currentKeyStroke == nil)
            }
        }
        .frame(width: ActionMenuMetrics.submenuWidth, height: ActionMenuMetrics.submenuHeight - ActionMenuMetrics.padding * 2)
        .padding(ActionMenuMetrics.padding)
        .actionMenuSurface()
        .onAppear {
            capturedKeyStroke = selectedKeyStroke
        }
        .onChange(of: selectedKeyStroke) { _, newSelectedKeyStroke in
            capturedKeyStroke = newSelectedKeyStroke
            stopCapture()
        }
        .onDisappear {
            stopCapture()
        }
        .onLocalModifierChange { modifiers in
            targetModifiers = modifiers
        }
    }

    private func toggleCapture() {
        if isCapturing {
            stopCapture()
        } else {
            startCapture()
        }
    }

    private func startCapture() {
        stopCapture()
        isCapturing = true

        monitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { event in
            guard let keyStroke = KeyStroke(event: event) else {
                return event
            }

            capturedKeyStroke = keyStroke
            stopCapture()
            return nil
        }
    }

    private func stopCapture() {
        if let monitor {
            NSEvent.removeMonitor(monitor)
        }

        monitor = nil
        isCapturing = false
    }
}

private struct CompactTargetKeyboard: View {
    let modifiers: Set<ModifierKey>
    let select: (KeyboardKey) -> Void

    private let rows: [[KeyboardKey]] = [
        Array(KeyCatalog.defaultRows[1][1...10]),
        Array(KeyCatalog.defaultRows[2][1...10]),
        Array(KeyCatalog.defaultRows[3][1...10]),
        Array(KeyCatalog.defaultRows[4][7...10])
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(modifiers.isEmpty ? "Click a target key" : "\(modifiers.displaySymbols) + click")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
                .lineLimit(1)

            ForEach(rows.indices, id: \.self) { rowIndex in
                HStack(spacing: 4) {
                    ForEach(rows[rowIndex]) { key in
                        Button {
                            select(key)
                        } label: {
                            Text(key.targetPickerLabel)
                                .font(.system(size: 9, weight: .semibold))
                                .lineLimit(1)
                                .minimumScaleFactor(0.65)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                        }
                        .buttonStyle(.plain)
                        .frame(width: key.targetPickerWidth, height: 18)
                        .background(Color.primary.opacity(0.07), in: RoundedRectangle(cornerRadius: 4, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .strokeBorder(Color.primary.opacity(0.10), lineWidth: 1)
                                .allowsHitTesting(false)
                        }
                    }
                }
            }
        }
    }
}

private struct HistoryActionMenuRow: Identifiable {
    let id: String
    let title: String
    let subtitle: String
    let isSelected: Bool
    let select: () -> Void
    let delete: (() -> Void)?
}

private struct BuiltInToolMenuRow: Identifiable {
    let id: String
    let title: String
    let subtitle: String
    let systemImage: String
    let isSelected: Bool
    let select: () -> Void
}

private struct CommandActionPicker: View {
    let toolRows: [BuiltInToolMenuRow]
    let commandRows: [HistoryActionMenuRow]
    let saveNewCommand: (String, String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            if !toolRows.isEmpty {
                toolList
            }

            HistoryActionPicker(
                emptyTitle: "No Command History",
                addTitle: "New Command",
                valuePlaceholder: "Command",
                iconName: ActionKind.command.systemImage,
                tint: .orange,
                rows: commandRows,
                contentPadding: 0,
                usesSurface: false,
                historyListHeight: ActionMenuMetrics.commandHistoryListHeight,
                isValid: { name, value in
                    !name.isEmpty && !value.isEmpty
                },
                saveNewItem: saveNewCommand
            )
        }
        .frame(
            width: ActionMenuMetrics.submenuWidth,
            height: ActionMenuMetrics.submenuHeight - ActionMenuMetrics.padding * 2,
            alignment: .top
        )
        .padding(ActionMenuMetrics.padding)
        .actionMenuSurface()
    }

    private var toolList: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("Built-in Tools")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 4)

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(toolRows) { row in
                        ActionMenuRow(
                            title: row.title,
                            subtitle: row.subtitle,
                            systemImage: row.systemImage,
                            image: nil,
                            tint: .orange,
                            isSelected: row.isSelected,
                            select: row.select,
                            delete: nil
                        )
                        .help(row.subtitle)
                    }
                }
                .padding(.vertical, 2)
                .frame(maxWidth: .infinity, alignment: .topLeading)
            }
            .contentShape(Rectangle())
            .background(Color.primary.opacity(0.001))
            .defaultScrollAnchor(.top)
            .frame(height: ActionMenuMetrics.toolListHeight)
        }
    }
}

private struct HistoryActionPicker: View {
    let emptyTitle: String
    let addTitle: String
    let valuePlaceholder: String
    let initialValue: String
    let iconName: String
    let tint: Color
    let rows: [HistoryActionMenuRow]
    let contentPadding: CGFloat
    let usesSurface: Bool
    let historyListHeight: CGFloat
    let isValid: (String, String) -> Bool
    let saveNewItem: (String, String) -> Void

    private enum AddField: Hashable {
        case name
        case value
    }

    @State private var isAdding = false
    @State private var name = ""
    @State private var value: String
    @FocusState private var focusedAddField: AddField?

    init(
        emptyTitle: String,
        addTitle: String,
        valuePlaceholder: String,
        initialValue: String = "",
        iconName: String,
        tint: Color,
        rows: [HistoryActionMenuRow],
        contentPadding: CGFloat = ActionMenuMetrics.padding,
        usesSurface: Bool = true,
        historyListHeight: CGFloat = ActionMenuMetrics.historyListHeight,
        isValid: @escaping (String, String) -> Bool,
        saveNewItem: @escaping (String, String) -> Void
    ) {
        self.emptyTitle = emptyTitle
        self.addTitle = addTitle
        self.valuePlaceholder = valuePlaceholder
        self.initialValue = initialValue
        self.iconName = iconName
        self.tint = tint
        self.rows = rows
        self.contentPadding = contentPadding
        self.usesSurface = usesSurface
        self.historyListHeight = historyListHeight
        self.isValid = isValid
        self.saveNewItem = saveNewItem
        _value = State(initialValue: initialValue)
    }

    var body: some View {
        content
    }

    @ViewBuilder
    private var content: some View {
        let picker = VStack(spacing: 6) {
            addButton

            historyList
        }
        .overlay(alignment: .top) {
            if isAdding {
                addItemPanel
                    .transition(.opacity.combined(with: .scale(scale: 0.98, anchor: .top)))
                    .zIndex(1)
            }
        }
        .animation(.easeOut(duration: 0.16), value: isAdding)
        .frame(width: ActionMenuMetrics.submenuWidth)
        .padding(contentPadding)

        if usesSurface {
            picker.actionMenuSurface()
        } else {
            picker
        }
    }

    private var addButton: some View {
        Button {
            showAddPanel()
        } label: {
            Label(addTitle, systemImage: "plus")
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(ActionMenuPlainButtonStyle(tint: tint))
    }

    private var historyList: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                if rows.isEmpty {
                    ActionMenuEmptyState(title: emptyTitle)
                } else {
                    ForEach(rows) { row in
                        ActionMenuRow(
                            title: row.title,
                            subtitle: row.subtitle,
                            systemImage: iconName,
                            image: nil,
                            tint: tint,
                            isSelected: row.isSelected,
                            select: row.select,
                            delete: row.delete
                        )
                        .help(row.subtitle)
                    }
                }
            }
            .padding(.vertical, 2)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .contentShape(Rectangle())
        .background(Color.primary.opacity(0.001))
        .defaultScrollAnchor(.top)
        .frame(height: rows.isEmpty ? min(76, historyListHeight) : historyListHeight)
    }

    private var addItemPanel: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                Label(addTitle, systemImage: iconName)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(tint)

                Spacer()
            }

            TextField("Name", text: $name)
                .textFieldStyle(.roundedBorder)
                .focused($focusedAddField, equals: .name)
                .onSubmit {
                    focusedAddField = .value
                }

            TextField(valuePlaceholder, text: $value)
                .textFieldStyle(.roundedBorder)
                .focused($focusedAddField, equals: .value)
                .onSubmit {
                    submitNewItem()
                }

            HStack(spacing: 8) {
                Spacer()

                Button {
                    hideAddPanel()
                } label: {
                    Text("Cancel")
                        .frame(width: 58)
                }
                .buttonStyle(ActionMenuFormButtonStyle(tint: tint, role: .secondary))

                Button {
                    submitNewItem()
                } label: {
                    Label("Add", systemImage: "checkmark")
                        .frame(width: 58)
                }
                .buttonStyle(ActionMenuFormButtonStyle(tint: tint, role: .primary))
                .disabled(!canSave)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity)
        .background {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(.regularMaterial)
                .shadow(color: .black.opacity(0.16), radius: 14, y: 6)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(tint.opacity(0.24), lineWidth: 1)
                .allowsHitTesting(false)
        }
        .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var canSave: Bool {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return isValid(trimmedName, trimmedValue)
    }

    private func showAddPanel() {
        guard !isAdding else {
            return
        }

        isAdding = true

        DispatchQueue.main.async {
            focusedAddField = .name
        }
    }

    private func hideAddPanel() {
        isAdding = false
        focusedAddField = nil
    }

    private func submitNewItem() {
        guard canSave else {
            return
        }

        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
        saveNewItem(trimmedName, trimmedValue)
    }
}

private struct ActionMenuRow: View {
    let title: String
    let subtitle: String?
    let systemImage: String?
    let image: NSImage?
    let tint: Color
    let isSelected: Bool
    let select: () -> Void
    var delete: (() -> Void)?

    @State private var isHovering = false

    var body: some View {
        Button {
            select()
        } label: {
            HStack(spacing: 8) {
                icon
                    .frame(width: 18, height: 18)

                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(.system(size: 12, weight: isSelected ? .semibold : .medium))
                        .lineLimit(1)

                    if let subtitle {
                        Text(subtitle)
                            .font(.system(size: 10))
                            .foregroundStyle(isHovering ? .white.opacity(0.82) : .secondary)
                            .lineLimit(1)
                    }
                }

                Spacer(minLength: 6)

                if isHovering, let delete {
                    Button {
                        delete()
                    } label: {
                        Image(systemName: "trash")
                            .font(.system(size: 11, weight: .semibold))
                            .frame(width: 18, height: 18)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(isHovering ? .white : .secondary)
                    .help("Delete from history")
                } else if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(isHovering ? .white : .secondary)
                        .frame(width: 18, height: 18)
                } else {
                    Color.clear
                        .frame(width: 18, height: 18)
                }
            }
            .foregroundStyle(isHovering ? .white : .primary)
            .padding(.horizontal, 8)
            .frame(
                maxWidth: .infinity,
                minHeight: rowHeight,
                maxHeight: rowHeight,
                alignment: .leading
            )
            .background {
                if isHovering {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(Color.accentColor)
                } else if isSelected {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(tint.opacity(0.16))
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
        .onHover { hovering in
            isHovering = hovering
        }
    }

    private var rowHeight: CGFloat {
        subtitle == nil ? ActionMenuMetrics.rowHeight : ActionMenuMetrics.historyRowHeight
    }

    @ViewBuilder
    private var icon: some View {
        if let image {
            Image(nsImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
        } else if let systemImage {
            Image(systemName: systemImage)
                .font(.system(size: 13, weight: .semibold))
                .symbolRenderingMode(.monochrome)
                .foregroundStyle(isHovering ? .white : tint)
                .frame(width: 18, height: 18)
        }
    }
}

private struct ActionMenuEmptyState: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity)
            .frame(height: ActionMenuMetrics.rowHeight)
    }
}

private struct ActionMenuPlainButtonStyle: ButtonStyle {
    let tint: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(configuration.isPressed ? .white : .primary)
            .padding(.horizontal, 8)
            .frame(height: 32)
            .background {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(configuration.isPressed ? tint : tint.opacity(0.12))
            }
    }
}

private struct ActionMenuFormButtonStyle: ButtonStyle {
    enum Role {
        case primary
        case secondary
    }

    let tint: Color
    let role: Role

    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .semibold))
            .lineLimit(1)
            .foregroundStyle(foregroundColor(isPressed: configuration.isPressed))
            .padding(.horizontal, 10)
            .frame(height: 28)
            .background {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(backgroundColor(isPressed: configuration.isPressed))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .strokeBorder(borderColor, lineWidth: 1)
                    .allowsHitTesting(false)
            }
    }

    private func foregroundColor(isPressed: Bool) -> Color {
        switch role {
        case .primary:
            isEnabled ? .white : .secondary
        case .secondary:
            isPressed ? .primary : .secondary
        }
    }

    private func backgroundColor(isPressed: Bool) -> Color {
        switch role {
        case .primary:
            if !isEnabled {
                return Color.primary.opacity(0.07)
            }

            return isPressed ? tint.opacity(0.82) : tint
        case .secondary:
            return isPressed ? Color.primary.opacity(0.12) : Color.primary.opacity(0.06)
        }
    }

    private var borderColor: Color {
        switch role {
        case .primary:
            isEnabled ? tint.opacity(0.34) : Color.primary.opacity(0.08)
        case .secondary:
            Color.primary.opacity(0.10)
        }
    }
}

private struct ActionMenuSurfaceModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(.regularMaterial)
                    .shadow(color: .black.opacity(0.16), radius: 18, y: 8)
                    .allowsHitTesting(false)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.10), lineWidth: 1)
                    .allowsHitTesting(false)
            }
    }
}

private extension View {
    func actionMenuSurface() -> some View {
        modifier(ActionMenuSurfaceModifier())
    }

    func onLocalModifierChange(_ handler: @escaping (Set<ModifierKey>) -> Void) -> some View {
        modifier(LocalModifierChangeModifier(handler: handler))
    }
}

private struct LocalModifierChangeModifier: ViewModifier {
    let handler: (Set<ModifierKey>) -> Void

    @State private var monitor: Any?

    func body(content: Content) -> some View {
        content
            .onAppear {
                monitor = NSEvent.addLocalMonitorForEvents(matching: [.flagsChanged, .keyDown, .keyUp]) { event in
                    handler(Set(event.modifierFlags.modifierKeys))
                    return event
                }
            }
            .onDisappear {
                if let monitor {
                    NSEvent.removeMonitor(monitor)
                }
            }
    }
}

enum ActionMenuMetrics {
    static let primaryWidth: CGFloat = 168
    static let bindingStripWidth: CGFloat = primaryWidth - 20
    static let bindingCapsuleHeight: CGFloat = 26
    static let bindingTitleMaxWidth: CGFloat = 54
    static let primaryVisualHeight: CGFloat = 184
    static let submenuWidth: CGFloat = 286
    static let contentPadding: CGFloat = 1
    static let primaryMenuOuterWidth: CGFloat = primaryWidth + 12 + contentPadding * 2
    static let submenuOuterWidth: CGFloat = submenuWidth + padding * 2
    static let menuGap: CGFloat = 8
    static let totalWidth: CGFloat = primaryMenuOuterWidth + submenuOuterWidth + menuGap
    static let appListHeight: CGFloat = 176
    static let toolListHeight: CGFloat = 130
    static let commandHistoryListHeight: CGFloat = 76
    static let historyListHeight: CGFloat = 172
    static let primaryHeight: CGFloat = 184
    static let submenuHeight: CGFloat = 286
    static let maxHeight: CGFloat = submenuHeight
    static let rowHeight: CGFloat = 34
    static let historyRowHeight: CGFloat = 42
    static let padding: CGFloat = 8

    static func contentWidth(hasSubmenu: Bool) -> CGFloat {
        hasSubmenu ? totalWidth : primaryMenuOuterWidth
    }

    static func contentHeight(activeKind: ActionKind?) -> CGFloat {
        guard let activeKind else {
            return primaryHeight
        }

        return max(primaryHeight, submenuHeight + submenuTopOffset(for: activeKind))
    }

    static func submenuTopOffset(for kind: ActionKind) -> CGFloat {
        let headerHeight = CGFloat(44)
        let dividerHeight = CGFloat(1)
        let rowSpacing = CGFloat(5)
        let menuPadding = CGFloat(6)
        let rowStep = CGFloat(30) + rowSpacing

        return menuPadding + headerHeight + rowSpacing + dividerHeight + rowSpacing + CGFloat(kind.menuIndex) * rowStep
    }
}

extension ActionKind {
    var tint: Color {
        switch self {
        case .app: .blue
        case .url: .green
        case .command: .orange
        case .mapping: .purple
        }
    }
}

private extension ActionKind {
    var menuIndex: Int {
        switch self {
        case .app: 0
        case .url: 1
        case .command: 2
        case .mapping: 3
        }
    }
}

private extension KeyAction {
    var selectedAppBundleIdentifier: String? {
        guard case .openApp(let bundleIdentifier, _) = self else {
            return nil
        }

        return bundleIdentifier
    }

    var selectedWebItem: WebActionHistoryItem? {
        guard case .openURL(let name, let url) = self else {
            return nil
        }

        return WebActionHistoryItem(name: name, url: url)
    }

    var selectedCommandItem: CommandActionHistoryItem? {
        guard case .runCommand(let name, let command) = self else {
            return nil
        }

        return CommandActionHistoryItem(name: name, command: command)
    }

    var selectedToolID: String? {
        guard case .runTool(let invocation) = self else {
            return nil
        }

        return invocation.toolID
    }

    var selectedKeyStroke: KeyStroke? {
        guard case .sendKeyStroke(let keyStroke) = self else {
            return nil
        }

        return keyStroke
    }
}

private extension KeyTrigger {
    var badgeTitle: String {
        KeyStroke(
            modifiers: modifiers,
            keyCode: keyCode,
            keyDisplayName: keyDisplayName
        )
        .compactDisplayTitle
    }
}

private extension KeyStroke {
    var compactDisplayTitle: String {
        let modifierSymbols = modifiers.displaySymbols.replacingOccurrences(of: " ", with: "")

        if modifierSymbols.isEmpty {
            return keyDisplayName
        }

        return "\(modifierSymbols)\(keyDisplayName)"
    }
}

private extension KeyStroke {
    init?(event: NSEvent) {
        let keyCode = Int(event.keyCode)

        guard !Self.modifierKeyCodes.contains(keyCode) else {
            return nil
        }

        self.init(
            modifiers: Set(event.modifierFlags.modifierKeys),
            keyCode: keyCode,
            keyDisplayName: KeyCatalog.displayName(forKeyCode: keyCode)
        )
    }

    private static let modifierKeyCodes: Set<Int> = [
        55, 54,
        59, 62,
        58, 61,
        56, 60
    ]
}

private extension NSEvent.ModifierFlags {
    var modifierKeys: [ModifierKey] {
        var modifiers: [ModifierKey] = []

        if contains(.control) {
            modifiers.append(.control)
        }

        if contains(.option) {
            modifiers.append(.option)
        }

        if contains(.shift) {
            modifiers.append(.shift)
        }

        if contains(.command) {
            modifiers.append(.command)
        }

        return modifiers
    }
}

private extension KeyboardKey {
    var targetPickerLabel: String {
        switch id {
        case "left":
            "←"
        case "right":
            "→"
        case "up":
            "↑"
        case "down":
            "↓"
        default:
            label
        }
    }

    var targetPickerWidth: CGFloat {
        id == "space" ? 46 : 22
    }
}
