import AppKit
import SwiftUI

struct KeyboardLayoutView: View {
    @EnvironmentObject private var appState: AppState
    @State private var editingKey: KeyboardKey?
    @State private var menuPresenter: KeyActionMenuWindowPresenter?

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
            openEditor: { sourceView in
                openEditor(for: key, from: sourceView)
            }
        )
        .frame(width: width ?? Self.keyWidth(for: key), height: height)
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
            menuPresenter = KeyActionMenuWindowPresenter()
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
    let openEditor: (NSView) -> Void

    @GestureState private var isPressed = false
    @State private var sourceView: NSView?

    var body: some View {
        ZStack(alignment: .topTrailing) {
            KeyLegendView(key: key)
                .allowsHitTesting(false)

            if let rule {
                ActionBadge(action: rule.action)
                    .padding(5)
                    .allowsHitTesting(false)
            }
        }
        .foregroundStyle(.primary)
        .keyboardKeySurface(tint: rule?.action.kind.tint, isPressed: isPressed)
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
        .accessibilityElement()
        .accessibilityLabel(key.label)
        .accessibilityAddTraits(.isButton)
        .accessibilityAction {
            openEditorIfPossible()
        }
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

@MainActor
private final class KeyActionMenuWindowPresenter: NSObject, NSMenuDelegate {
    private weak var appState: AppState?
    private var key: KeyboardKey?
    private var menu: NSMenu?
    private var lazySubmenuKinds: [ObjectIdentifier: ActionKind] = [:]
    private var loadedLazySubmenus: Set<ObjectIdentifier> = []
    private var closeHandler: (() -> Void)?
    private var didFinish = false

    func present(
        key: KeyboardKey,
        appState: AppState,
        from sourceView: NSView,
        close: @escaping () -> Void
    ) {
        dismissMenu(notifying: false, cancelTracking: true)

        self.appState = appState
        self.key = key
        self.closeHandler = close
        didFinish = false
        lazySubmenuKinds.removeAll()
        loadedLazySubmenus.removeAll()

        let menu = makeMainMenu(
            key: key,
            appState: appState
        )
        menu.delegate = self
        self.menu = menu

        menu.popUp(
            positioning: nil,
            at: NSPoint(
                x: sourceView.bounds.maxX + Self.menuGap,
                y: sourceView.bounds.maxY
            ),
            in: sourceView
        )
    }

    func close() {
        dismissMenu(notifying: true, cancelTracking: true)
    }

    func menuDidClose(_ menu: NSMenu) {
        guard menu === self.menu else {
            return
        }

        dismissMenu(notifying: true, cancelTracking: false)
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        let menuID = ObjectIdentifier(menu)

        guard let kind = lazySubmenuKinds[menuID],
              !loadedLazySubmenus.contains(menuID),
              let appState
        else {
            return
        }

        menu.removeAllItems()

        let item = NSMenuItem()
        item.view = submenuView(for: kind, appState: appState)
        menu.addItem(item)
        loadedLazySubmenus.insert(menuID)
    }

    private func makeMainMenu(
        key: KeyboardKey,
        appState: AppState
    ) -> NSMenu {
        let menu = NSMenu()
        menu.autoenablesItems = false

        let titleItem = NSMenuItem(
            title: "\(appState.launcherKey.displayName) + \(key.label)",
            action: nil,
            keyEquivalent: ""
        )
        titleItem.isEnabled = false
        menu.addItem(titleItem)

        if let currentRule = appState.rule(for: key) {
            let currentItem = NSMenuItem(
                title: "Current: \(currentRule.action.displayTitle)",
                action: nil,
                keyEquivalent: ""
            )
            currentItem.image = Self.symbolImage(currentRule.action.kind.systemImage)
            currentItem.isEnabled = false
            menu.addItem(currentItem)
        }

        menu.addItem(.separator())

        for kind in ActionKind.allCases {
            let item = NSMenuItem(
                title: kind.title,
                action: nil,
                keyEquivalent: ""
            )
            item.image = Self.symbolImage(kind.systemImage)
            item.submenu = lazySubmenu(for: kind)
            menu.addItem(item)
        }

        if appState.rule(for: key) != nil {
            menu.addItem(.separator())

            let removeItem = NSMenuItem(
                title: "Remove",
                action: #selector(removeRule(_:)),
                keyEquivalent: ""
            )
            removeItem.target = self
            removeItem.image = Self.symbolImage("trash")
            menu.addItem(removeItem)
        }

        return menu
    }

    private func lazySubmenu(for kind: ActionKind) -> NSMenu {
        let menu = NSMenu(title: kind.title)
        menu.autoenablesItems = false
        menu.delegate = self

        let placeholderItem = NSMenuItem(
            title: "Loading...",
            action: nil,
            keyEquivalent: ""
        )
        placeholderItem.isEnabled = false
        menu.addItem(placeholderItem)
        lazySubmenuKinds[ObjectIdentifier(menu)] = kind

        return menu
    }

    private func submenuView(
        for kind: ActionKind,
        appState: AppState
    ) -> NSView {
        let currentRule = key.flatMap { appState.rule(for: $0) }

        switch kind {
        case .app:
            return AppActionMenuView(
                apps: appState.installedApps,
                selectedBundleIdentifier: currentRule?.action.selectedAppBundleIdentifier,
                select: { [weak self] app in
                    self?.save(app: app)
                }
            )
        case .url:
            return HistoryActionMenuView(
                emptyTitle: "No Website History",
                addTitle: "New Website",
                valuePlaceholder: "URL",
                initialValue: "https://",
                iconName: "link",
                tint: .systemGreen,
                rows: appState.actionHistory.webItems.map { item in
                    HistoryActionRow(
                        id: item.id,
                        title: item.name,
                        subtitle: item.url,
                        isSelected: item == currentRule?.action.selectedWebItem,
                        select: { [weak self] in
                            self?.save(webItem: item)
                        }
                    )
                },
                isValid: { name, value in
                    !name.isEmpty && URL(string: value) != nil
                },
                saveNewItem: { [weak self] name, value in
                    self?.save(webItem: WebActionHistoryItem(name: name, url: value))
                }
            )
        case .command:
            return HistoryActionMenuView(
                emptyTitle: "No Command History",
                addTitle: "New Command",
                valuePlaceholder: "Command",
                iconName: "terminal.fill",
                tint: .systemOrange,
                rows: appState.actionHistory.commandItems.map { item in
                    HistoryActionRow(
                        id: item.id,
                        title: item.name,
                        subtitle: item.command,
                        isSelected: item == currentRule?.action.selectedCommandItem,
                        select: { [weak self] in
                            self?.save(commandItem: item)
                        }
                    )
                },
                isValid: { name, value in
                    !name.isEmpty && !value.isEmpty
                },
                saveNewItem: { [weak self] name, value in
                    self?.save(commandItem: CommandActionHistoryItem(name: name, command: value))
                }
            )
        }
    }

    private func save(app: InstalledApp) {
        guard let appState, let key else {
            return
        }

        appState.saveRule(
            for: key,
            action: .openApp(
                bundleIdentifier: app.bundleIdentifier,
                displayName: app.name
            )
        )
        dismissMenu(notifying: true, cancelTracking: true)
    }

    private func save(webItem item: WebActionHistoryItem) {
        guard let appState, let key else {
            return
        }

        appState.saveRule(for: key, webHistoryItem: item)
        dismissMenu(notifying: true, cancelTracking: true)
    }

    private func save(commandItem item: CommandActionHistoryItem) {
        guard let appState, let key else {
            return
        }

        appState.saveRule(for: key, commandHistoryItem: item)
        dismissMenu(notifying: true, cancelTracking: true)
    }

    @objc
    private func removeRule(_ sender: NSMenuItem) {
        guard let appState, let key else {
            return
        }

        appState.deleteRule(for: key)
        dismissMenu(notifying: true, cancelTracking: true)
    }

    private func dismissMenu(
        notifying shouldNotify: Bool,
        cancelTracking: Bool
    ) {
        guard !didFinish else {
            return
        }

        didFinish = true

        let menu = menu
        let closeHandler = closeHandler
        self.menu = nil
        self.closeHandler = nil
        lazySubmenuKinds.removeAll()
        loadedLazySubmenus.removeAll()
        appState = nil
        key = nil

        if cancelTracking {
            menu?.cancelTracking()
        }

        if shouldNotify {
            closeHandler?()
        }
    }

    private static func symbolImage(_ name: String) -> NSImage? {
        NSImage(systemSymbolName: name, accessibilityDescription: nil)
    }

    private static let menuGap: CGFloat = 8
}

private enum ActionMenuMetrics {
    static let width: CGFloat = 286
    static let contentWidth: CGFloat = width - padding * 2
    static let appListHeight: CGFloat = 176
    static let historyMenuHeight: CGFloat = 284
    static let rowHeight: CGFloat = 34
    static let historyRowHeight: CGFloat = 42
    static let padding: CGFloat = 8
}

@MainActor
private func updateDocumentFrame(
    for stackView: NSStackView,
    in scrollView: NSScrollView
) {
    stackView.layoutSubtreeIfNeeded()

    let fittingSize = stackView.fittingSize
    let contentWidth = max(
        scrollView.contentView.bounds.width,
        ActionMenuMetrics.contentWidth
    )
    stackView.frame = NSRect(
        x: 0,
        y: 0,
        width: contentWidth,
        height: max(fittingSize.height, scrollView.contentView.bounds.height)
    )
}

private final class MenuStackView: NSStackView {
    override var isFlipped: Bool {
        true
    }
}

private final class AppActionMenuView: NSView, NSSearchFieldDelegate {
    private let apps: [InstalledApp]
    private let selectedBundleIdentifier: String?
    private let select: (InstalledApp) -> Void
    private let searchField = MenuSearchTextField()
    private let scrollView = NSScrollView()
    private let stackView = MenuStackView()
    private var rebuildGeneration = 0

    init(
        apps: [InstalledApp],
        selectedBundleIdentifier: String?,
        select: @escaping (InstalledApp) -> Void
    ) {
        self.apps = apps
        self.selectedBundleIdentifier = selectedBundleIdentifier
        self.select = select
        super.init(frame: NSRect(
            x: 0,
            y: 0,
            width: ActionMenuMetrics.width,
            height: ActionMenuMetrics.appListHeight + 46
        ))

        setupViews()
        scheduleRowsRebuild()
    }

    required init?(coder: NSCoder) {
        nil
    }

    func controlTextDidChange(_ obj: Notification) {
        scheduleRowsRebuild()
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()

        DispatchQueue.main.async { [weak self] in
            guard let self else {
                return
            }

            self.window?.makeFirstResponder(self.searchField)
        }
    }

    private func setupViews() {
        searchField.placeholderString = "Search apps"
        searchField.delegate = self

        stackView.orientation = .vertical
        stackView.alignment = .leading
        stackView.spacing = 2
        stackView.edgeInsets = NSEdgeInsets(top: 2, left: 0, bottom: 2, right: 0)
        stackView.frame = NSRect(
            x: 0,
            y: 0,
            width: ActionMenuMetrics.contentWidth,
            height: 1
        )
        stackView.autoresizingMask = [.width]

        scrollView.documentView = stackView
        scrollView.hasVerticalScroller = true
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder

        addSubview(searchField)
        addSubview(scrollView)

        searchField.translatesAutoresizingMaskIntoConstraints = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            searchField.topAnchor.constraint(equalTo: topAnchor, constant: ActionMenuMetrics.padding),
            searchField.leadingAnchor.constraint(equalTo: leadingAnchor, constant: ActionMenuMetrics.padding),
            searchField.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -ActionMenuMetrics.padding),
            searchField.heightAnchor.constraint(equalToConstant: 28),

            scrollView.topAnchor.constraint(equalTo: searchField.bottomAnchor, constant: 6),
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: ActionMenuMetrics.padding),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -ActionMenuMetrics.padding),
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -ActionMenuMetrics.padding)
        ])
    }

    private func scheduleRowsRebuild() {
        rebuildGeneration += 1
        let generation = rebuildGeneration

        stackView.arrangedSubviews.forEach {
            stackView.removeArrangedSubview($0)
            $0.removeFromSuperview()
        }
        stackView.addArrangedSubview(ActionMenuEmptyRow(title: "Loading Apps..."))
        updateDocumentFrame(for: stackView, in: scrollView)

        DispatchQueue.main.async { [weak self] in
            guard let self, self.rebuildGeneration == generation else {
                return
            }

            self.rebuildRows(generation: generation)
        }
    }

    private func rebuildRows(generation: Int) {
        stackView.arrangedSubviews.forEach {
            stackView.removeArrangedSubview($0)
            $0.removeFromSuperview()
        }

        let rows = matchingApps

        guard !rows.isEmpty else {
            stackView.addArrangedSubview(ActionMenuEmptyRow(title: "No Apps Found"))
            updateDocumentFrame(for: stackView, in: scrollView)
            return
        }

        appendRows(
            rows,
            startingAt: 0,
            generation: generation
        )
    }

    private func appendRows(
        _ rows: [InstalledApp],
        startingAt startIndex: Int,
        generation: Int
    ) {
        guard rebuildGeneration == generation else {
            return
        }

        let endIndex = min(startIndex + Self.rowsPerBatch, rows.count)

        for index in startIndex..<endIndex {
            let app = rows[index]
            addRow(for: app)
        }

        updateDocumentFrame(for: stackView, in: scrollView)

        guard endIndex < rows.count else {
            return
        }

        DispatchQueue.main.async { [weak self] in
            self?.appendRows(
                rows,
                startingAt: endIndex,
                generation: generation
            )
        }
    }

    private func addRow(for app: InstalledApp) {
        let row = ActionMenuRowView(
            title: app.name,
            subtitle: nil,
            image: AppIconCache.shared.cachedIcon(for: app),
            tint: .controlAccentColor,
            isSelected: app.bundleIdentifier == selectedBundleIdentifier,
            rowHeight: ActionMenuMetrics.rowHeight,
            action: { [select] in
                select(app)
            }
        )
        row.toolTip = app.name
        stackView.addArrangedSubview(row)

        AppIconCache.shared.icon(for: app) { [weak row] icon in
            row?.setImage(icon)
        }
    }

    private var matchingApps: [InstalledApp] {
        let query = searchField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !query.isEmpty else {
            return apps
        }

        return apps.filter {
            $0.name.localizedCaseInsensitiveContains(query)
                || $0.bundleIdentifier.localizedCaseInsensitiveContains(query)
        }
    }

    private static let rowsPerBatch = 24
}

private struct HistoryActionRow {
    let id: String
    let title: String
    let subtitle: String
    let isSelected: Bool
    let select: () -> Void
}

private final class HistoryActionMenuView: NSView, NSTextFieldDelegate {
    private let emptyTitle: String
    private let addTitle: String
    private let valuePlaceholder: String
    private let initialValue: String
    private let iconName: String
    private let tint: NSColor
    private let rows: [HistoryActionRow]
    private let isValid: (String, String) -> Bool
    private let saveNewItem: (String, String) -> Void

    private let contentStack = NSStackView()
    private let formStack = NSStackView()
    private let nameField = MenuTextField()
    private let valueField = MenuTextField()
    private let scrollView = NSScrollView()
    private let listStack = MenuStackView()

    init(
        emptyTitle: String,
        addTitle: String,
        valuePlaceholder: String,
        initialValue: String = "",
        iconName: String,
        tint: NSColor,
        rows: [HistoryActionRow],
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
        super.init(frame: NSRect(
            x: 0,
            y: 0,
            width: ActionMenuMetrics.width,
            height: ActionMenuMetrics.historyMenuHeight
        ))

        setupViews()
        rebuildRows()
    }

    required init?(coder: NSCoder) {
        nil
    }

    func controlTextDidChange(_ obj: Notification) {
        updateSaveButtonState()
    }

    override func layout() {
        super.layout()
        updateDocumentFrame(for: listStack, in: scrollView)
    }

    private func setupViews() {
        contentStack.orientation = .vertical
        contentStack.alignment = .leading
        contentStack.spacing = 6
        contentStack.edgeInsets = NSEdgeInsets(
            top: ActionMenuMetrics.padding,
            left: ActionMenuMetrics.padding,
            bottom: ActionMenuMetrics.padding,
            right: ActionMenuMetrics.padding
        )

        let addRow = ActionMenuRowView(
            title: addTitle,
            subtitle: nil,
            image: NSImage(systemSymbolName: "plus", accessibilityDescription: nil),
            tint: tint,
            isSelected: false,
            rowHeight: 32,
            action: { [weak self] in
                self?.toggleForm()
            }
        )

        setupForm()

        listStack.orientation = .vertical
        listStack.alignment = .leading
        listStack.spacing = 2
        listStack.edgeInsets = NSEdgeInsets(top: 2, left: 0, bottom: 2, right: 0)
        listStack.frame = NSRect(
            x: 0,
            y: 0,
            width: ActionMenuMetrics.contentWidth,
            height: 1
        )
        listStack.autoresizingMask = [.width]

        scrollView.documentView = listStack
        scrollView.hasVerticalScroller = true
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder

        addSubview(contentStack)
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false

        contentStack.addArrangedSubview(addRow)
        contentStack.addArrangedSubview(formStack)
        contentStack.addArrangedSubview(scrollView)

        formStack.isHidden = true

        NSLayoutConstraint.activate([
            contentStack.topAnchor.constraint(equalTo: topAnchor),
            contentStack.leadingAnchor.constraint(equalTo: leadingAnchor),
            contentStack.trailingAnchor.constraint(equalTo: trailingAnchor),
            contentStack.bottomAnchor.constraint(equalTo: bottomAnchor),

            addRow.widthAnchor.constraint(equalTo: contentStack.widthAnchor, constant: -ActionMenuMetrics.padding * 2),
            formStack.widthAnchor.constraint(equalTo: contentStack.widthAnchor, constant: -ActionMenuMetrics.padding * 2),
            scrollView.widthAnchor.constraint(equalTo: contentStack.widthAnchor, constant: -ActionMenuMetrics.padding * 2),
            scrollView.heightAnchor.constraint(greaterThanOrEqualToConstant: 76)
        ])
    }

    private func setupForm() {
        formStack.orientation = .vertical
        formStack.alignment = .leading
        formStack.spacing = 6
        formStack.edgeInsets = NSEdgeInsets(top: 7, left: 8, bottom: 8, right: 8)
        formStack.wantsLayer = true
        formStack.layer?.cornerRadius = 8
        formStack.layer?.backgroundColor = NSColor.controlBackgroundColor.withAlphaComponent(0.65).cgColor

        nameField.placeholderString = "Name"
        valueField.placeholderString = valuePlaceholder
        valueField.stringValue = initialValue
        nameField.delegate = self
        valueField.delegate = self

        let buttonRow = NSStackView()
        buttonRow.orientation = .horizontal
        buttonRow.alignment = .centerY
        buttonRow.spacing = 8

        let cancelButton = NSButton(title: "Cancel", target: self, action: #selector(cancelForm))
        cancelButton.bezelStyle = .rounded

        let spacer = NSView()
        let saveButton = NSButton(title: "Save", target: self, action: #selector(saveForm))
        saveButton.bezelStyle = .rounded
        saveButton.keyEquivalent = "\r"
        saveButton.identifier = Self.saveButtonIdentifier

        buttonRow.addArrangedSubview(cancelButton)
        buttonRow.addArrangedSubview(spacer)
        buttonRow.addArrangedSubview(saveButton)
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)

        formStack.addArrangedSubview(nameField)
        formStack.addArrangedSubview(valueField)
        formStack.addArrangedSubview(buttonRow)

        NSLayoutConstraint.activate([
            nameField.widthAnchor.constraint(equalTo: formStack.widthAnchor, constant: -16),
            valueField.widthAnchor.constraint(equalTo: formStack.widthAnchor, constant: -16),
            buttonRow.widthAnchor.constraint(equalTo: formStack.widthAnchor, constant: -16)
        ])

        updateSaveButtonState()
    }

    private func rebuildRows() {
        listStack.arrangedSubviews.forEach {
            listStack.removeArrangedSubview($0)
            $0.removeFromSuperview()
        }

        guard !rows.isEmpty else {
            listStack.addArrangedSubview(ActionMenuEmptyRow(title: emptyTitle))
            updateDocumentFrame(for: listStack, in: scrollView)
            return
        }

        for row in rows {
            let rowView = ActionMenuRowView(
                title: row.title,
                subtitle: row.subtitle,
                image: NSImage(systemSymbolName: iconName, accessibilityDescription: nil),
                tint: tint,
                isSelected: row.isSelected,
                rowHeight: ActionMenuMetrics.historyRowHeight,
                action: row.select
            )
            rowView.toolTip = row.subtitle
            listStack.addArrangedSubview(rowView)
        }

        updateDocumentFrame(for: listStack, in: scrollView)
    }

    private func toggleForm() {
        formStack.isHidden.toggle()

        if !formStack.isHidden {
            window?.makeFirstResponder(nameField)
        }
    }

    @objc
    private func cancelForm() {
        formStack.isHidden = true
    }

    @objc
    private func saveForm() {
        let name = nameField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let value = valueField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)

        guard isValid(name, value) else {
            NSSound.beep()
            return
        }

        saveNewItem(name, value)
    }

    private func updateSaveButtonState() {
        guard let saveButton = formStack
            .arrangedSubviews
            .compactMap({ $0 as? NSStackView })
            .flatMap(\.arrangedSubviews)
            .compactMap({ $0 as? NSButton })
            .first(where: { $0.identifier == Self.saveButtonIdentifier })
        else {
            return
        }

        let name = nameField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let value = valueField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        saveButton.isEnabled = isValid(name, value)
    }

    private static let saveButtonIdentifier = NSUserInterfaceItemIdentifier("ActionMenuSaveButton")
}

private final class ActionMenuRowView: NSControl {
    private let iconView = NSImageView()
    private let titleField = NSTextField(labelWithString: "")
    private let subtitleField = NSTextField(labelWithString: "")
    private let trailingView = NSImageView()
    private let tint: NSColor
    private let rowHeight: CGFloat
    private let actionHandler: () -> Void
    private var trackingArea: NSTrackingArea?
    private var isHovering = false {
        didSet {
            updateAppearance()
        }
    }
    private var isSelected: Bool {
        didSet {
            updateAppearance()
        }
    }

    init(
        title: String,
        subtitle: String?,
        image: NSImage?,
        tint: NSColor,
        isSelected: Bool,
        rowHeight: CGFloat,
        action: @escaping () -> Void
    ) {
        self.tint = tint
        self.isSelected = isSelected
        self.rowHeight = rowHeight
        self.actionHandler = action
        super.init(frame: .zero)

        setupViews(
            title: title,
            subtitle: subtitle,
            image: image
        )
        updateAppearance()
    }

    required init?(coder: NSCoder) {
        nil
    }

    override var intrinsicContentSize: NSSize {
        NSSize(width: ActionMenuMetrics.width - ActionMenuMetrics.padding * 2, height: rowHeight)
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()

        if let trackingArea {
            removeTrackingArea(trackingArea)
        }

        let area = NSTrackingArea(
            rect: bounds,
            options: [.activeAlways, .mouseEnteredAndExited, .inVisibleRect],
            owner: self
        )
        addTrackingArea(area)
        trackingArea = area
    }

    override func mouseEntered(with event: NSEvent) {
        isHovering = true
    }

    override func mouseExited(with event: NSEvent) {
        isHovering = false
    }

    override func mouseUp(with event: NSEvent) {
        guard bounds.contains(convert(event.locationInWindow, from: nil)) else {
            return
        }

        actionHandler()
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }

    func setImage(_ image: NSImage?) {
        iconView.image = image
        iconView.contentTintColor = image?.isTemplate == true ? tint : nil
    }

    private func setupViews(
        title: String,
        subtitle: String?,
        image: NSImage?
    ) {
        wantsLayer = true
        layer?.cornerRadius = 6

        iconView.image = image
        iconView.imageScaling = .scaleProportionallyUpOrDown
        iconView.contentTintColor = image?.isTemplate == true ? tint : nil

        titleField.stringValue = title
        titleField.font = .systemFont(ofSize: 12, weight: isSelected ? .semibold : .medium)
        titleField.lineBreakMode = .byTruncatingTail

        subtitleField.stringValue = subtitle ?? ""
        subtitleField.font = .systemFont(ofSize: 10)
        subtitleField.lineBreakMode = .byTruncatingTail
        subtitleField.isHidden = subtitle == nil

        trailingView.image = isSelected
            ? NSImage(systemSymbolName: "checkmark", accessibilityDescription: nil)
            : nil
        trailingView.imageScaling = .scaleProportionallyUpOrDown
        trailingView.contentTintColor = .secondaryLabelColor

        let labelStack = NSStackView(views: subtitle == nil ? [titleField] : [titleField, subtitleField])
        labelStack.orientation = .vertical
        labelStack.alignment = .leading
        labelStack.spacing = 1

        let rowStack = NSStackView(views: [iconView, labelStack, trailingView])
        rowStack.orientation = .horizontal
        rowStack.alignment = .centerY
        rowStack.spacing = 8
        rowStack.edgeInsets = NSEdgeInsets(top: 0, left: 8, bottom: 0, right: 8)

        addSubview(rowStack)
        rowStack.translatesAutoresizingMaskIntoConstraints = false
        iconView.translatesAutoresizingMaskIntoConstraints = false
        trailingView.translatesAutoresizingMaskIntoConstraints = false

        labelStack.setContentHuggingPriority(.defaultLow, for: .horizontal)
        labelStack.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        NSLayoutConstraint.activate([
            heightAnchor.constraint(equalToConstant: rowHeight),
            rowStack.topAnchor.constraint(equalTo: topAnchor),
            rowStack.leadingAnchor.constraint(equalTo: leadingAnchor),
            rowStack.trailingAnchor.constraint(equalTo: trailingAnchor),
            rowStack.bottomAnchor.constraint(equalTo: bottomAnchor),

            iconView.widthAnchor.constraint(equalToConstant: 18),
            iconView.heightAnchor.constraint(equalToConstant: 18),
            trailingView.widthAnchor.constraint(equalToConstant: 16),
            trailingView.heightAnchor.constraint(equalToConstant: 16)
        ])
    }

    private func updateAppearance() {
        if isHovering {
            layer?.backgroundColor = NSColor.controlAccentColor.cgColor
            titleField.textColor = .white
            subtitleField.textColor = NSColor.white.withAlphaComponent(0.82)
            iconView.contentTintColor = .white
            trailingView.contentTintColor = .white
            return
        }

        if isSelected {
            layer?.backgroundColor = tint.withAlphaComponent(0.16).cgColor
        } else {
            layer?.backgroundColor = .clear
        }

        titleField.textColor = .labelColor
        subtitleField.textColor = .secondaryLabelColor
        iconView.contentTintColor = iconView.image?.isTemplate == true ? tint : nil
        trailingView.contentTintColor = .secondaryLabelColor
    }
}

private final class ActionMenuEmptyRow: NSView {
    init(title: String) {
        super.init(frame: NSRect(
            x: 0,
            y: 0,
            width: ActionMenuMetrics.width - ActionMenuMetrics.padding * 2,
            height: ActionMenuMetrics.rowHeight
        ))

        let label = NSTextField(labelWithString: title)
        label.font = .systemFont(ofSize: 12, weight: .medium)
        label.textColor = .secondaryLabelColor
        label.alignment = .center

        addSubview(label)
        label.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            heightAnchor.constraint(equalToConstant: ActionMenuMetrics.rowHeight),
            label.topAnchor.constraint(equalTo: topAnchor),
            label.leadingAnchor.constraint(equalTo: leadingAnchor),
            label.trailingAnchor.constraint(equalTo: trailingAnchor),
            label.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }

    required init?(coder: NSCoder) {
        nil
    }
}

private final class MenuSearchTextField: NSSearchField {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }
}

private final class MenuTextField: NSTextField {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }
}

@MainActor
private final class AppIconCache {
    static let shared = AppIconCache()

    private var iconsByBundleIdentifier: [String: NSImage] = [:]
    private var pendingHandlersByBundleIdentifier: [String: [(NSImage) -> Void]] = [:]

    func cachedIcon(for app: InstalledApp) -> NSImage {
        if let icon = iconsByBundleIdentifier[app.bundleIdentifier] {
            return icon
        }

        return Self.placeholderIcon
    }

    func icon(
        for app: InstalledApp,
        completion: @escaping (NSImage) -> Void
    ) {
        icon(
            forBundleIdentifier: app.bundleIdentifier,
            path: app.url.path,
            completion: completion
        )
    }

    func icon(
        forBundleIdentifier bundleIdentifier: String,
        completion: @escaping (NSImage) -> Void
    ) {
        icon(
            forBundleIdentifier: bundleIdentifier,
            path: nil,
            completion: completion
        )
    }

    private func icon(
        forBundleIdentifier bundleIdentifier: String,
        path: String?,
        completion: @escaping (NSImage) -> Void
    ) {
        if let icon = iconsByBundleIdentifier[bundleIdentifier] {
            completion(icon)
            return
        }

        if pendingHandlersByBundleIdentifier[bundleIdentifier] != nil {
            pendingHandlersByBundleIdentifier[bundleIdentifier]?.append(completion)
            return
        }

        pendingHandlersByBundleIdentifier[bundleIdentifier] = [completion]

        Task.detached(priority: .utility) {
            let resolvedPath = path ?? NSWorkspace.shared
                .urlForApplication(withBundleIdentifier: bundleIdentifier)?
                .path
            let icon = if let resolvedPath {
                NSWorkspace.shared.icon(forFile: resolvedPath)
            } else {
                NSImage(systemSymbolName: "app", accessibilityDescription: nil)
                    ?? NSImage(size: NSSize(width: 16, height: 16))
            }
            icon.size = NSSize(width: 16, height: 16)

            await MainActor.run {
                self.iconsByBundleIdentifier[bundleIdentifier] = icon
                let handlers = self.pendingHandlersByBundleIdentifier.removeValue(forKey: bundleIdentifier) ?? []

                for handler in handlers {
                    handler(icon)
                }
            }
        }
    }

    private static let placeholderIcon: NSImage = {
        let image = NSImage(systemSymbolName: "app", accessibilityDescription: nil)
            ?? NSImage(size: NSSize(width: 16, height: 16))
        image.size = NSSize(width: 16, height: 16)
        return image
    }()
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

private extension ActionKind {
    var tint: Color {
        switch self {
        case .app: .blue
        case .url: .green
        case .command: .orange
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
