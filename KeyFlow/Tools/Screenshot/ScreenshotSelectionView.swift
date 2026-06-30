import AppKit
import SwiftUI

struct ScreenshotSelectionView: View {
    let copy: (CGRect, [ScreenshotAnnotation]) -> Void
    let cancel: () -> Void

    @State private var dragStart: CGPoint?
    @State private var dragCurrent: CGPoint?
    @State private var lockedSelectionRect: CGRect?
    @State private var movingSelectionStartRect: CGRect?
    @State private var annotationDragStart: CGPoint?
    @State private var annotationDragCurrent: CGPoint?
    @State private var pendingTextOrigin: CGPoint?
    @State private var pendingText = ""
    @State private var isIgnoringCurrentDrag = false
    @State private var annotationMode: ScreenshotAnnotationMode = .selection
    @State private var annotations: [ScreenshotAnnotation] = []
    @State private var mouseLocation: CGPoint?
    @State private var isHoveringToolbar = false
    @State private var hoveredToolbarItem: ScreenshotToolbarItem?
    @FocusState private var isTextFieldFocused: Bool

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Color.black.opacity(0.28)

                if let activeRect {
                    selectionOverlay(activeRect, in: proxy.size)
                }

                ScreenshotShortcutHandlingView(
                    isTextFieldFocused: isTextFieldFocused,
                    rectangle: {
                        toggleRectangleAnnotationMode()
                    },
                    text: {
                        toggleTextAnnotationMode()
                    },
                    copy: {
                        if let lockedSelectionRect {
                            ScreenshotCursorKind.arrow.apply()
                            copy(displayRect(fromLocalRect: lockedSelectionRect), annotationsIncludingPendingText())
                            return true
                        }
                        return false
                    },
                    undo: {
                        undoLastAnnotation()
                    }
                )
                .frame(width: 0, height: 0)
            }
            .ignoresSafeArea()
            .contentShape(Rectangle())
            .gesture(dragGesture(in: proxy.size))
            .simultaneousGesture(tapGesture(in: proxy.size))
            .onContinuousHover(coordinateSpace: .local) { phase in
                handleHover(phase)
            }
            .onAppear {
                currentCursorKind.apply()
            }
            .onChange(of: currentCursorKind) { _, newCursorKind in
                newCursorKind.apply()
            }
            .onExitCommand {
                if pendingTextOrigin != nil {
                    cancelPendingText()
                    currentCursorKind.apply()
                } else {
                    ScreenshotCursorKind.arrow.apply()
                    cancel()
                }
            }
            .onDisappear {
                ScreenshotCursorKind.arrow.apply()
            }
        }
    }

    private func dragGesture(in size: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 1, coordinateSpace: .local)
            .onChanged { value in
                handleDragChanged(value, in: size)
            }
            .onEnded { value in
                handleDragEnded(value, in: size)
            }
    }

    private func tapGesture(in size: CGSize) -> some Gesture {
        SpatialTapGesture(coordinateSpace: .local)
            .onEnded { value in
                handleTap(at: clampedPoint(value.location, in: size))
            }
    }

    @ViewBuilder
    private func selectionOverlay(_ rect: CGRect, in size: CGSize) -> some View {
        SelectionMask(rect: rect)
            .fill(.black.opacity(0.42), style: FillStyle(eoFill: true))

        Rectangle()
            .stroke(Color(nsColor: .systemBlue), lineWidth: 2)
            .frame(width: rect.width, height: rect.height)
            .position(x: rect.midX, y: rect.midY)

        ForEach(annotations.indices, id: \.self) { index in
            annotationOverlay(annotations[index], in: rect)
        }

        if let activeAnnotationRect {
            rectangleAnnotationOverlay(activeAnnotationRect, in: rect)
        }

        if pendingTextOrigin != nil {
            pendingTextOverlay(in: rect)
        }

        Text("\(Int(rect.width)) x \(Int(rect.height))")
            .font(.system(size: 11, weight: .semibold, design: .monospaced))
            .foregroundStyle(.white)
            .padding(.horizontal, 7)
            .padding(.vertical, 4)
            .background(.black.opacity(0.58), in: Capsule())
            .position(x: min(rect.maxX + 42, size.width - 48), y: max(rect.minY - 14, 16))

        if lockedSelectionRect != nil {
            toolbar(for: rect, in: size)
        }
    }

    private func toolbar(for rect: CGRect, in size: CGSize) -> some View {
        let position = toolbarPosition(for: rect, in: size)

        return ZStack {
            toolbarButtons(for: rect)

            if let hoveredToolbarItem {
                Text(hoveredToolbarItem.tooltip)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(.black.opacity(0.72), in: Capsule())
                    .overlay(
                        Capsule()
                            .stroke(.white.opacity(0.14), lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.28), radius: 8, y: 3)
                    .offset(x: hoveredToolbarItem.tooltipOffsetX, y: 40)
                    .allowsHitTesting(false)
                    .transition(.opacity)
            }
        }
        .animation(.easeOut(duration: 0.12), value: hoveredToolbarItem)
        .position(position)
    }

    private func toolbarButtons(for rect: CGRect) -> some View {
        HStack(spacing: 6) {
            Button {
                ScreenshotCursorKind.arrow.apply()
                cancel()
            } label: {
                Label("关闭", systemImage: "xmark")
                    .labelStyle(.iconOnly)
            }
            .keyboardShortcut(.cancelAction)
            .buttonStyle(ScreenshotToolbarIconButtonStyle())
            .help(ScreenshotToolbarItem.close.tooltip)
            .onHover { isHovered in
                updateToolbarHover(.close, isHovered: isHovered)
            }

            Button {
                toggleRectangleAnnotationMode()
            } label: {
                Label("标注", systemImage: "rectangle")
                    .labelStyle(.iconOnly)
            }
            .buttonStyle(ScreenshotToolbarIconButtonStyle(isActive: annotationMode == .rectangle))
            .help(ScreenshotToolbarItem.annotate.tooltip)
            .onHover { isHovered in
                updateToolbarHover(.annotate, isHovered: isHovered)
            }

            Button {
                toggleTextAnnotationMode()
            } label: {
                Label("文字", systemImage: "textformat")
                    .labelStyle(.iconOnly)
            }
            .buttonStyle(ScreenshotToolbarIconButtonStyle(isActive: annotationMode == .text))
            .help(ScreenshotToolbarItem.text.tooltip)
            .onHover { isHovered in
                updateToolbarHover(.text, isHovered: isHovered)
            }

            Button {
                ScreenshotCursorKind.arrow.apply()
                copy(displayRect(fromLocalRect: rect), annotationsIncludingPendingText())
            } label: {
                Label("复制", systemImage: "doc.on.doc")
                    .labelStyle(.iconOnly)
            }
            .keyboardShortcut("c", modifiers: .command)
            .buttonStyle(ScreenshotToolbarIconButtonStyle())
            .help(ScreenshotToolbarItem.copy.tooltip)
            .onHover { isHovered in
                updateToolbarHover(.copy, isHovered: isHovered)
            }
        }
        .onHover { isHovered in
            isHoveringToolbar = isHovered
            if !isHovered {
                hoveredToolbarItem = nil
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 5)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(
            Capsule()
                .stroke(Color.white.opacity(0.18), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.28), radius: 12, y: 6)
    }

    private func updateToolbarHover(_ item: ScreenshotToolbarItem, isHovered: Bool) {
        if isHovered {
            hoveredToolbarItem = item
        } else if hoveredToolbarItem == item {
            hoveredToolbarItem = nil
        }
    }

    @ViewBuilder
    private func annotationOverlay(_ annotation: ScreenshotAnnotation, in selectionRect: CGRect) -> some View {
        switch annotation.content {
        case .rectangle(let rect):
            rectangleAnnotationOverlay(rect, in: selectionRect)
        case .text(let text):
            textAnnotationOverlay(text, in: selectionRect)
        }
    }

    private func rectangleAnnotationOverlay(_ annotation: CGRect, in selectionRect: CGRect) -> some View {
        let rect = annotation.offsetBy(dx: selectionRect.minX, dy: selectionRect.minY)

        return Rectangle()
            .stroke(Color(nsColor: .systemRed), lineWidth: 2)
            .frame(width: rect.width, height: rect.height)
            .position(x: rect.midX, y: rect.midY)
    }

    private func textAnnotationOverlay(_ annotation: ScreenshotTextAnnotation, in selectionRect: CGRect) -> some View {
        Text(annotation.text)
            .font(.system(size: Self.annotationTextSize, weight: .semibold))
            .foregroundStyle(Color(nsColor: .systemRed))
            .shadow(color: .white.opacity(0.92), radius: 1.2)
            .padding(.horizontal, 5)
            .padding(.vertical, 3)
            .fixedSize(horizontal: true, vertical: false)
            .offset(x: annotation.origin.x, y: annotation.origin.y)
            .frame(width: selectionRect.width, height: selectionRect.height, alignment: .topLeading)
            .position(x: selectionRect.midX, y: selectionRect.midY)
            .allowsHitTesting(false)
    }

    private func pendingTextOverlay(in selectionRect: CGRect) -> some View {
        Group {
            if let pendingTextOrigin {
                TextField("输入文字", text: $pendingText)
                    .font(.system(size: Self.annotationTextSize, weight: .semibold))
                    .foregroundStyle(Color(nsColor: .systemRed))
                    .textFieldStyle(.plain)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 5)
                    .frame(width: Self.textFieldSize.width, height: Self.textFieldSize.height, alignment: .leading)
                    .background(.white.opacity(0.92), in: RoundedRectangle(cornerRadius: 6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color(nsColor: .systemRed).opacity(0.82), lineWidth: 1.5)
                    )
                    .focused($isTextFieldFocused)
                    .onSubmit {
                        commitPendingText()
                    }
                    .offset(x: pendingTextOrigin.x, y: pendingTextOrigin.y)
                    .frame(width: selectionRect.width, height: selectionRect.height, alignment: .topLeading)
                    .position(x: selectionRect.midX, y: selectionRect.midY)
            }
        }
    }

    @discardableResult
    private func toggleRectangleAnnotationMode() -> Bool {
        guard lockedSelectionRect != nil else {
            return false
        }

        commitPendingText()
        annotationMode = annotationMode == .rectangle ? .selection : .rectangle
        currentCursorKind.apply()
        return true
    }

    @discardableResult
    private func toggleTextAnnotationMode() -> Bool {
        guard lockedSelectionRect != nil else {
            return false
        }

        commitPendingText()
        annotationMode = annotationMode == .text ? .selection : .text
        currentCursorKind.apply()
        return true
    }

    private func handleHover(_ phase: HoverPhase) {
        switch phase {
        case .active(let location):
            mouseLocation = location
            currentCursorKind.apply()
        case .ended:
            mouseLocation = nil
            ScreenshotCursorKind.arrow.apply()
        }
    }

    private func handleTap(at location: CGPoint) {
        guard
            annotationMode == .text,
            let lockedSelectionRect,
            lockedSelectionRect.contains(location)
        else {
            return
        }

        commitPendingText()
        pendingTextOrigin = textOrigin(for: location, in: lockedSelectionRect)
        pendingText = ""
        hoveredToolbarItem = nil
        isHoveringToolbar = false

        DispatchQueue.main.async {
            isTextFieldFocused = true
        }
    }

    private func handleDragChanged(_ value: DragGesture.Value, in size: CGSize) {
        let start = clampedPoint(value.startLocation, in: size)
        let location = clampedPoint(value.location, in: size)

        if dragStart == nil {
            dragStart = start
            dragCurrent = nil
            isIgnoringCurrentDrag = false
            mouseLocation = start

            commitPendingText()

            if let lockedSelectionRect, annotationMode == .rectangle, lockedSelectionRect.contains(start) {
                annotationDragStart = clampedPoint(start, in: lockedSelectionRect)
                annotationDragCurrent = clampedPoint(location, in: lockedSelectionRect)
                movingSelectionStartRect = nil
                hoveredToolbarItem = nil
                isHoveringToolbar = false
            } else if let lockedSelectionRect, annotationMode == .text, lockedSelectionRect.contains(start) {
                isIgnoringCurrentDrag = true
                movingSelectionStartRect = nil
                annotationDragStart = nil
                annotationDragCurrent = nil
            } else if let lockedSelectionRect, lockedSelectionRect.contains(start) {
                movingSelectionStartRect = lockedSelectionRect
                annotationDragStart = nil
                annotationDragCurrent = nil
                hoveredToolbarItem = nil
                isHoveringToolbar = false
            } else if annotationMode.isAnnotationTool, lockedSelectionRect != nil {
                isIgnoringCurrentDrag = true
                movingSelectionStartRect = nil
                annotationDragStart = nil
                annotationDragCurrent = nil
            } else {
                movingSelectionStartRect = nil
                annotationDragStart = nil
                annotationDragCurrent = nil
                lockedSelectionRect = nil
                annotations = []
                annotationMode = .selection
            }
        }

        mouseLocation = location

        if isIgnoringCurrentDrag {
            currentCursorKind.apply()
        } else if let annotationDragStart, let lockedSelectionRect {
            self.annotationDragStart = clampedPoint(annotationDragStart, in: lockedSelectionRect)
            annotationDragCurrent = clampedPoint(location, in: lockedSelectionRect)
            ScreenshotCursorKind.crosshair.apply()
        } else if let movingSelectionStartRect {
            let proposedRect = movingSelectionStartRect.offsetBy(
                dx: location.x - start.x,
                dy: location.y - start.y
            )
            lockedSelectionRect = clampedRect(proposedRect, in: size)
            ScreenshotCursorKind.moveActive.apply()
        } else {
            dragCurrent = location
            ScreenshotCursorKind.drawing.apply()
        }
    }

    private func handleDragEnded(_ value: DragGesture.Value, in size: CGSize) {
        let start = clampedPoint(value.startLocation, in: size)
        let location = clampedPoint(value.location, in: size)
        defer {
            dragStart = nil
            dragCurrent = nil
            movingSelectionStartRect = nil
            annotationDragStart = nil
            annotationDragCurrent = nil
            isIgnoringCurrentDrag = false
        }

        mouseLocation = location

        if isIgnoringCurrentDrag {
            currentCursorKind.apply()
            return
        }

        if let annotationDragStart, let lockedSelectionRect {
            let rect = normalizedRect(
                from: annotationDragStart,
                to: clampedPoint(location, in: lockedSelectionRect)
            )

            if rect.width >= 4, rect.height >= 4 {
                annotations.append(
                    ScreenshotAnnotation(
                        content: .rectangle(
                            rect.offsetBy(dx: -lockedSelectionRect.minX, dy: -lockedSelectionRect.minY)
                        )
                    )
                )
            }

            ScreenshotCursorKind.crosshair.apply()
            return
        }

        if let movingSelectionStartRect {
            let proposedRect = movingSelectionStartRect.offsetBy(
                dx: location.x - start.x,
                dy: location.y - start.y
            )
            lockedSelectionRect = clampedRect(proposedRect, in: size)
            ScreenshotCursorKind.moveHover.apply()
            return
        }

        let localRect = normalizedRect(from: start, to: location)

        guard localRect.width >= 4, localRect.height >= 4 else {
            ScreenshotCursorKind.arrow.apply()
            cancel()
            return
        }

        lockedSelectionRect = localRect
        annotations = []
        annotationMode = .selection
        cancelPendingText()
        ScreenshotCursorKind.moveHover.apply()
    }

    private var currentCursorKind: ScreenshotCursorKind {
        if isHoveringToolbar {
            return .arrow
        }

        if annotationDragStart != nil {
            return .crosshair
        }

        if movingSelectionStartRect != nil {
            return .moveActive
        }

        if dragStart != nil {
            return .drawing
        }

        if annotationMode == .rectangle, lockedSelectionRect != nil {
            return .crosshair
        }

        if annotationMode == .text, lockedSelectionRect != nil {
            return .text
        }

        if let lockedSelectionRect, let mouseLocation, lockedSelectionRect.contains(mouseLocation) {
            return .moveHover
        }

        return .crosshair
    }

    private var activeRect: CGRect? {
        if let lockedSelectionRect {
            return lockedSelectionRect
        }

        guard let dragStart, let dragCurrent else {
            return nil
        }

        return normalizedRect(from: dragStart, to: dragCurrent)
    }

    private var activeAnnotationRect: CGRect? {
        guard let lockedSelectionRect, let annotationDragStart, let annotationDragCurrent else {
            return nil
        }

        return normalizedRect(
            from: annotationDragStart,
            to: annotationDragCurrent
        )
        .offsetBy(dx: -lockedSelectionRect.minX, dy: -lockedSelectionRect.minY)
    }

    private func commitPendingText() {
        guard let pendingTextOrigin else {
            return
        }

        let text = pendingText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !text.isEmpty {
            annotations.append(
                ScreenshotAnnotation(
                    content: .text(
                        ScreenshotTextAnnotation(text: text, origin: pendingTextOrigin)
                    )
                )
            )
        }

        cancelPendingText()
    }

    private func cancelPendingText() {
        pendingTextOrigin = nil
        pendingText = ""
        isTextFieldFocused = false
    }

    @discardableResult
    private func undoLastAnnotation() -> Bool {
        if pendingTextOrigin != nil {
            cancelPendingText()
            currentCursorKind.apply()
            return true
        }

        if annotations.popLast() != nil {
            currentCursorKind.apply()
            return true
        } else {
            currentCursorKind.apply()
            return false
        }
    }

    private func annotationsIncludingPendingText() -> [ScreenshotAnnotation] {
        guard
            let pendingTextOrigin,
            !pendingText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else {
            return annotations
        }

        var currentAnnotations = annotations
        currentAnnotations.append(
            ScreenshotAnnotation(
                content: .text(
                    ScreenshotTextAnnotation(
                        text: pendingText.trimmingCharacters(in: .whitespacesAndNewlines),
                        origin: pendingTextOrigin
                    )
                )
            )
        )
        return currentAnnotations
    }

    private func normalizedRect(from start: CGPoint, to end: CGPoint) -> CGRect {
        CGRect(
            x: min(start.x, end.x),
            y: min(start.y, end.y),
            width: abs(start.x - end.x),
            height: abs(start.y - end.y)
        )
    }

    private func clampedPoint(_ point: CGPoint, in size: CGSize) -> CGPoint {
        CGPoint(
            x: min(max(point.x, 0), size.width),
            y: min(max(point.y, 0), size.height)
        )
    }

    private func clampedPoint(_ point: CGPoint, in rect: CGRect) -> CGPoint {
        CGPoint(
            x: min(max(point.x, rect.minX), rect.maxX),
            y: min(max(point.y, rect.minY), rect.maxY)
        )
    }

    private func textOrigin(for point: CGPoint, in rect: CGRect) -> CGPoint {
        let localX = point.x - rect.minX
        let localY = point.y - rect.minY

        return CGPoint(
            x: min(max(localX, 0), max(rect.width - Self.textFieldSize.width, 0)),
            y: min(max(localY, 0), max(rect.height - Self.textFieldSize.height, 0))
        )
    }

    private func clampedRect(_ rect: CGRect, in size: CGSize) -> CGRect {
        let width = min(rect.width, size.width)
        let height = min(rect.height, size.height)
        let maxX = max(size.width - width, 0)
        let maxY = max(size.height - height, 0)

        return CGRect(
            x: min(max(rect.minX, 0), maxX),
            y: min(max(rect.minY, 0), maxY),
            width: width,
            height: height
        )
    }

    private func toolbarPosition(for rect: CGRect, in size: CGSize) -> CGPoint {
        let toolbarWidth: CGFloat = 150
        let toolbarHeight: CGFloat = 40
        let bottomY = rect.maxY + toolbarHeight / 2 + 10
        let topY = rect.minY - toolbarHeight / 2 - 10
        let y = bottomY <= size.height - 10 ? bottomY : max(topY, toolbarHeight / 2 + 10)
        let x = min(max(rect.midX, toolbarWidth / 2 + 10), size.width - toolbarWidth / 2 - 10)
        return CGPoint(x: x, y: y)
    }

    private func displayRect(fromLocalRect rect: CGRect) -> CGRect {
        CGRect(
            x: rect.minX,
            y: rect.minY,
            width: rect.width,
            height: rect.height
        )
    }

    private static let annotationTextSize: CGFloat = 18
    private static let textFieldSize = CGSize(width: 180, height: 34)
}

private struct ScreenshotToolbarIconButtonStyle: ButtonStyle {
    var isActive = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .semibold))
            .symbolRenderingMode(.hierarchical)
            .foregroundStyle(.white)
            .frame(width: 30, height: 30)
            .background(
                Circle()
                    .fill(backgroundColor(isPressed: configuration.isPressed))
            )
            .overlay(
                Circle()
                    .stroke(strokeColor(isPressed: configuration.isPressed), lineWidth: 1)
            )
            .contentShape(Circle())
    }

    private func backgroundColor(isPressed: Bool) -> Color {
        if isActive {
            return Color(nsColor: .systemRed).opacity(isPressed ? 0.42 : 0.34)
        }

        return Color.white.opacity(isPressed ? 0.24 : 0.12)
    }

    private func strokeColor(isPressed: Bool) -> Color {
        if isActive {
            return Color(nsColor: .systemRed).opacity(isPressed ? 0.74 : 0.58)
        }

        return Color.white.opacity(isPressed ? 0.32 : 0.16)
    }
}

private enum ScreenshotToolbarItem: Equatable {
    case close
    case annotate
    case text
    case copy

    var tooltip: String {
        switch self {
        case .close:
            return "关闭 (Esc)"
        case .annotate:
            return "框选标注 (R)"
        case .text:
            return "文字标注 (T)"
        case .copy:
            return "复制 (Cmd+C)"
        }
    }

    var tooltipOffsetX: CGFloat {
        switch self {
        case .close:
            return -54
        case .annotate:
            return -18
        case .text:
            return 18
        case .copy:
            return 54
        }
    }
}

private enum ScreenshotAnnotationMode {
    case selection
    case rectangle
    case text

    var isAnnotationTool: Bool {
        switch self {
        case .rectangle, .text:
            return true
        case .selection:
            return false
        }
    }
}

private enum ScreenshotCursorKind: Equatable {
    case arrow
    case crosshair
    case text
    case drawing
    case moveHover
    case moveActive

    @MainActor
    func apply() {
        switch self {
        case .arrow:
            NSCursor.arrow.set()
        case .crosshair:
            NSCursor.crosshair.set()
        case .text:
            NSCursor.iBeam.set()
        case .drawing:
            NSCursor.frameResize(position: .topLeft, directions: .all).set()
        case .moveHover:
            NSCursor.openHand.set()
        case .moveActive:
            NSCursor.closedHand.set()
        }
    }
}

private struct ScreenshotShortcutHandlingView: NSViewRepresentable {
    var isTextFieldFocused: Bool
    var rectangle: () -> Bool
    var text: () -> Bool
    var copy: () -> Bool
    var undo: () -> Bool

    func makeNSView(context: Context) -> ShortcutHandlingNSView {
        let view = ShortcutHandlingNSView()
        view.handlers = context.coordinator
        return view
    }

    func updateNSView(_ nsView: ShortcutHandlingNSView, context: Context) {
        context.coordinator.isTextFieldFocused = isTextFieldFocused
        context.coordinator.rectangle = rectangle
        context.coordinator.text = text
        context.coordinator.copy = copy
        context.coordinator.undo = undo
    }

    static func dismantleNSView(_ nsView: ShortcutHandlingNSView, coordinator: Coordinator) {
        nsView.removeMonitor()
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(
            isTextFieldFocused: isTextFieldFocused,
            rectangle: rectangle,
            text: text,
            copy: copy,
            undo: undo
        )
    }

    final class Coordinator {
        var isTextFieldFocused: Bool
        var rectangle: () -> Bool
        var text: () -> Bool
        var copy: () -> Bool
        var undo: () -> Bool

        init(
            isTextFieldFocused: Bool,
            rectangle: @escaping () -> Bool,
            text: @escaping () -> Bool,
            copy: @escaping () -> Bool,
            undo: @escaping () -> Bool
        ) {
            self.isTextFieldFocused = isTextFieldFocused
            self.rectangle = rectangle
            self.text = text
            self.copy = copy
            self.undo = undo
        }

        @discardableResult
        func handle(_ event: NSEvent) -> Bool {
            guard event.type == .keyDown else {
                return false
            }

            let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            if modifiers == .command, let character = event.charactersIgnoringModifiers?.lowercased() {
                switch character {
                case "c":
                    return copy()
                case "z":
                    return undo()
                default:
                    break
                }
            }

            guard !isTextFieldFocused, modifiers.isEmpty else {
                return false
            }

            switch event.charactersIgnoringModifiers?.lowercased() {
            case "r":
                return rectangle()
            case "t":
                return text()
            default:
                return false
            }
        }
    }
}

private final class ShortcutHandlingNSView: NSView {
    weak var handlers: ScreenshotShortcutHandlingView.Coordinator?
    private var monitor: Any?

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        guard window != nil else {
            removeMonitor()
            return
        }

        guard monitor == nil else {
            return
        }

        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handlers?.handle(event) == true ? nil : event
        }
    }

    fileprivate func removeMonitor() {
        guard let monitor else {
            return
        }

        NSEvent.removeMonitor(monitor)
        self.monitor = nil
    }
}

private struct SelectionMask: Shape {
    let rect: CGRect

    func path(in frame: CGRect) -> Path {
        var path = Path()
        path.addRect(frame)
        path.addRect(rect)
        return path
    }
}
