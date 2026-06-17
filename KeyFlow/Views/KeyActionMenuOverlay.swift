import AppKit
import SwiftUI

struct KeyActionMenuContent: View {
    let key: KeyboardKey
    let close: () -> Void
    var activeKindChanged: (ActionKind?) -> Void = { _ in }

    @EnvironmentObject private var appState: AppState
    @State private var activeKind: ActionKind?

    var body: some View {
        HStack(alignment: .center, spacing: ActionMenuMetrics.menuGap) {
            ActionKindMenu(
                key: key,
                activeKind: $activeKind,
                close: close
            )

            if let activeKind {
                ActionKindSubmenu(
                    key: key,
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
        .frame(
            width: ActionMenuMetrics.contentWidth(hasSubmenu: true),
            height: ActionMenuMetrics.maxHeight,
            alignment: .leading
        )
        .padding(ActionMenuMetrics.contentPadding)
        .contentShape(Rectangle())
        .onHover { isHovering in
            if !isHovering {
                activeKind = nil
            }
        }
        .onChange(of: activeKind) { _, newValue in
            activeKindChanged(newValue)
        }
    }
}

private struct ActionKindMenu: View {
    let key: KeyboardKey
    @Binding var activeKind: ActionKind?
    let close: () -> Void

    @EnvironmentObject private var appState: AppState
    @State private var isRemoveHovered = false

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            VStack(alignment: .leading, spacing: 3) {
                Text("\(appState.launcherKey.displayName) + \(key.label)")
                    .font(.system(size: 12, weight: .semibold))
                    .lineLimit(1)

                if let rule = appState.rule(for: key) {
                    Label(rule.action.displayTitle, systemImage: rule.action.kind.systemImage)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
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

            if appState.rule(for: key) != nil {
                Divider()

                Button {
                    appState.deleteRule(for: key)
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
}

private struct ActionMenuKindRow: View {
    let kind: ActionKind
    let isActive: Bool
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
            Image(systemName: kind.systemImage)
                .font(.system(size: 13, weight: .semibold))
                .frame(width: 18)
                .foregroundStyle(isHighlighted ? .white : kind.tint)

            Text(kind.title)
                .font(.system(size: 12, weight: .medium))

            Spacer(minLength: 6)

            Image(systemName: "chevron.right")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(isHighlighted ? .white.opacity(0.85) : .secondary)
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
}

private struct ActionKindSubmenu: View {
    let key: KeyboardKey
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
                HistoryActionPicker(
                    emptyTitle: "No Command History",
                    addTitle: "New Command",
                    valuePlaceholder: "Command",
                    iconName: ActionKind.command.systemImage,
                    tint: .orange,
                    rows: appState.actionHistory.commandItems.map { item in
                        HistoryActionMenuRow(
                            id: item.id,
                            title: item.name,
                            subtitle: item.command,
                            isSelected: item == currentRule?.action.selectedCommandItem,
                            select: {
                                save(commandItem: item)
                            },
                            delete: {
                                appState.deleteCommandHistoryItem(item)
                            }
                        )
                    },
                    isValid: { name, value in
                        !name.isEmpty && !value.isEmpty
                    },
                    saveNewItem: { name, value in
                        save(commandItem: CommandActionHistoryItem(name: name, command: value))
                    }
                )
            }
        }
        .id(kind)
    }

    private var currentRule: KeyRule? {
        appState.rule(for: key)
    }

    private func save(app: InstalledApp) {
        appState.saveRule(
            for: key,
            action: .openApp(
                bundleIdentifier: app.bundleIdentifier,
                displayName: app.name
            )
        )
        close()
    }

    private func save(webItem item: WebActionHistoryItem) {
        appState.saveRule(for: key, webHistoryItem: item)
        close()
    }

    private func save(commandItem item: CommandActionHistoryItem) {
        appState.saveRule(for: key, commandHistoryItem: item)
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
                LazyVStack(alignment: .leading, spacing: 2) {
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
            }
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

private struct HistoryActionMenuRow: Identifiable {
    let id: String
    let title: String
    let subtitle: String
    let isSelected: Bool
    let select: () -> Void
    let delete: () -> Void
}

private struct HistoryActionPicker: View {
    let emptyTitle: String
    let addTitle: String
    let valuePlaceholder: String
    let initialValue: String
    let iconName: String
    let tint: Color
    let rows: [HistoryActionMenuRow]
    let isValid: (String, String) -> Bool
    let saveNewItem: (String, String) -> Void

    @State private var isAdding = false
    @State private var name = ""
    @State private var value: String

    init(
        emptyTitle: String,
        addTitle: String,
        valuePlaceholder: String,
        initialValue: String = "",
        iconName: String,
        tint: Color,
        rows: [HistoryActionMenuRow],
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
        self.isValid = isValid
        self.saveNewItem = saveNewItem
        _value = State(initialValue: initialValue)
    }

    var body: some View {
        VStack(spacing: 6) {
            Button {
                isAdding.toggle()
            } label: {
                Label(addTitle, systemImage: "plus")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(ActionMenuPlainButtonStyle(tint: tint))

            if isAdding {
                VStack(spacing: 6) {
                    TextField("Name", text: $name)
                        .textFieldStyle(.roundedBorder)

                    TextField(valuePlaceholder, text: $value)
                        .textFieldStyle(.roundedBorder)

                    HStack(spacing: 8) {
                        Button("Cancel") {
                            isAdding = false
                        }
                        .controlSize(.small)

                        Spacer()

                        Button("Add") {
                            let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
                            let trimmedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
                            saveNewItem(trimmedName, trimmedValue)
                        }
                        .controlSize(.small)
                        .disabled(!canSave)
                    }
                }
                .padding(.vertical, 4)
            }

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 2) {
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
            }
            .frame(height: rows.isEmpty ? 76 : ActionMenuMetrics.historyListHeight)
        }
        .frame(width: ActionMenuMetrics.submenuWidth)
        .padding(ActionMenuMetrics.padding)
        .actionMenuSurface()
    }

    private var canSave: Bool {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return isValid(trimmedName, trimmedValue)
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
                .foregroundStyle(isHovering ? .white : tint)
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
}

enum ActionMenuMetrics {
    static let primaryWidth: CGFloat = 168
    static let primaryVisualHeight: CGFloat = 184
    static let submenuWidth: CGFloat = 286
    static let contentPadding: CGFloat = 1
    static let primaryMenuOuterWidth: CGFloat = primaryWidth + 12 + contentPadding * 2
    static let submenuOuterWidth: CGFloat = submenuWidth + padding * 2
    static let menuGap: CGFloat = 8
    static let totalWidth: CGFloat = primaryMenuOuterWidth + submenuOuterWidth + menuGap
    static let appListHeight: CGFloat = 176
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
        }
    }
}

private extension ActionKind {
    var menuIndex: Int {
        switch self {
        case .app: 0
        case .url: 1
        case .command: 2
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
}
