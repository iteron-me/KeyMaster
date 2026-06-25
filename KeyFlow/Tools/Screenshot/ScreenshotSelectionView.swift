import AppKit
import SwiftUI

struct ScreenshotSelectionView: View {
    let screenFrame: CGRect
    let copy: (CGRect) -> Void
    let cancel: () -> Void

    @State private var dragStart: CGPoint?
    @State private var dragCurrent: CGPoint?
    @State private var lockedSelectionRect: CGRect?
    @State private var movingSelectionStartRect: CGRect?
    @State private var mouseLocation: CGPoint?
    @State private var isHoveringToolbar = false
    @State private var hoveredToolbarItem: ScreenshotToolbarItem?

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Color.black.opacity(0.28)

                if let activeRect {
                    selectionOverlay(activeRect, in: proxy.size)
                }
            }
            .ignoresSafeArea()
            .contentShape(Rectangle())
            .gesture(dragGesture(in: proxy.size))
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
                ScreenshotCursorKind.arrow.apply()
                cancel()
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

    @ViewBuilder
    private func selectionOverlay(_ rect: CGRect, in size: CGSize) -> some View {
        SelectionMask(rect: rect)
            .fill(.black.opacity(0.42), style: FillStyle(eoFill: true))

        Rectangle()
            .stroke(Color(nsColor: .systemBlue), lineWidth: 2)
            .frame(width: rect.width, height: rect.height)
            .position(x: rect.midX, y: rect.midY)

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
                ScreenshotCursorKind.arrow.apply()
                copy(screenRect(fromLocalRect: rect))
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

    private func handleDragChanged(_ value: DragGesture.Value, in size: CGSize) {
        let start = clampedPoint(value.startLocation, in: size)
        let location = clampedPoint(value.location, in: size)

        if dragStart == nil {
            dragStart = start
            dragCurrent = nil
            mouseLocation = start

            if let lockedSelectionRect, lockedSelectionRect.contains(start) {
                movingSelectionStartRect = lockedSelectionRect
                hoveredToolbarItem = nil
                isHoveringToolbar = false
            } else {
                movingSelectionStartRect = nil
                lockedSelectionRect = nil
            }
        }

        mouseLocation = location

        if let movingSelectionStartRect {
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
        }

        mouseLocation = location

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
        ScreenshotCursorKind.moveHover.apply()
    }

    private var currentCursorKind: ScreenshotCursorKind {
        if isHoveringToolbar {
            return .arrow
        }

        if movingSelectionStartRect != nil {
            return .moveActive
        }

        if dragStart != nil {
            return .drawing
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
        let toolbarWidth: CGFloat = 78
        let toolbarHeight: CGFloat = 40
        let bottomY = rect.maxY + toolbarHeight / 2 + 10
        let topY = rect.minY - toolbarHeight / 2 - 10
        let y = bottomY <= size.height - 10 ? bottomY : max(topY, toolbarHeight / 2 + 10)
        let x = min(max(rect.midX, toolbarWidth / 2 + 10), size.width - toolbarWidth / 2 - 10)
        return CGPoint(x: x, y: y)
    }

    private func screenRect(fromLocalRect rect: CGRect) -> CGRect {
        CGRect(
            x: screenFrame.minX + rect.minX,
            y: screenFrame.maxY - rect.maxY,
            width: rect.width,
            height: rect.height
        )
    }
}

private struct ScreenshotToolbarIconButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .semibold))
            .symbolRenderingMode(.hierarchical)
            .foregroundStyle(.white)
            .frame(width: 30, height: 30)
            .background(
                Circle()
                    .fill(Color.white.opacity(configuration.isPressed ? 0.24 : 0.12))
            )
            .overlay(
                Circle()
                    .stroke(Color.white.opacity(configuration.isPressed ? 0.32 : 0.16), lineWidth: 1)
            )
            .contentShape(Circle())
    }
}

private enum ScreenshotToolbarItem: Equatable {
    case close
    case copy

    var tooltip: String {
        switch self {
        case .close:
            return "关闭 (Esc)"
        case .copy:
            return "复制 (Cmd+C)"
        }
    }

    var tooltipOffsetX: CGFloat {
        switch self {
        case .close:
            return -18
        case .copy:
            return 18
        }
    }
}

private enum ScreenshotCursorKind: Equatable {
    case arrow
    case crosshair
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
        case .drawing:
            NSCursor.frameResize(position: .topLeft, directions: .all).set()
        case .moveHover:
            NSCursor.openHand.set()
        case .moveActive:
            NSCursor.closedHand.set()
        }
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
