import AppKit
import SwiftUI

@MainActor
final class ScreenshotPinController {
    static let shared = ScreenshotPinController()

    private var pins: [ScreenshotPinEntry] = []
    private var selectedPinID: UUID?
    private var escapeMonitor: Any?

    func pin(_ image: NSImage, sourceRect: CGRect, screenFrame: CGRect) {
        let id = UUID()

        let displaySize = CGSize(
            width: max(sourceRect.width, Self.minimumPinLength),
            height: max(sourceRect.height, Self.minimumPinLength)
        )
        let pin = ScreenshotPinItem(
            id: id,
            image: image,
            displaySize: displaySize
        )
        let windowFrame = Self.windowFrame(for: sourceRect, displaySize: displaySize, screenFrame: screenFrame)
        let window = ScreenshotPinWindow(
            contentRect: windowFrame,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )

        window.pinID = id
        window.pinController = self
        window.isReleasedWhenClosed = false
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.ignoresMouseEvents = false
        window.acceptsMouseMovedEvents = true
        window.isMovableByWindowBackground = false
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]

        let view = ScreenshotPinnedImageView(
            pin: pin,
            select: { [weak self] in
                self?.selectPin(id)
            },
            close: { [weak self] in
                self?.removePin(id)
            },
            currentWindowFrame: { [weak window] in
                window?.frame
            },
            moveWindow: { [weak window] frame in
                window?.setFrame(frame, display: true)
            }
        )
        let hostingView = ScreenshotPinHostingView(rootView: view)
        hostingView.frame = NSRect(origin: .zero, size: windowFrame.size)
        hostingView.autoresizingMask = [.width, .height]
        hostingView.wantsLayer = true
        hostingView.layer?.backgroundColor = NSColor.clear.cgColor
        window.contentView = hostingView

        pins.append(ScreenshotPinEntry(id: id, pin: pin, window: window))
        installEscapeMonitorIfNeeded()
        selectPin(id)
        window.orderFrontRegardless()
    }

    fileprivate func selectPin(_ id: UUID) {
        guard pins.contains(where: { $0.id == id }) else {
            return
        }

        selectedPinID = id
        updateSelection()

        if let window = pins.first(where: { $0.id == id })?.window {
            NSApp.activate(ignoringOtherApps: true)
            window.orderFrontRegardless()
            window.makeKey()
        }
    }

    fileprivate func removeSelectedPin() {
        guard let selectedPinID else {
            return
        }

        removePin(selectedPinID)
    }

    private func removePin(_ id: UUID) {
        guard let index = pins.firstIndex(where: { $0.id == id }) else {
            return
        }

        let wasSelected = selectedPinID == id
        pins[index].window.close()
        pins.remove(at: index)

        if wasSelected {
            selectedPinID = pins.last?.id
        }

        updateSelection()

        if pins.isEmpty {
            removeEscapeMonitor()
        }
    }

    private func updateSelection() {
        for entry in pins {
            entry.pin.isSelected = entry.id == selectedPinID
        }
    }

    private func installEscapeMonitorIfNeeded() {
        guard escapeMonitor == nil else {
            return
        }

        escapeMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard
                event.keyCode == Self.escapeKeyCode,
                event.window is ScreenshotPinWindow || NSApp.keyWindow is ScreenshotPinWindow
            else {
                return event
            }

            Task { @MainActor [weak self] in
                self?.removeSelectedPin()
            }
            return nil
        }
    }

    private func removeEscapeMonitor() {
        guard let escapeMonitor else {
            return
        }

        NSEvent.removeMonitor(escapeMonitor)
        self.escapeMonitor = nil
    }

    private static func windowFrame(for sourceRect: CGRect, displaySize: CGSize, screenFrame: CGRect) -> CGRect {
        let imageOrigin = CGPoint(
            x: screenFrame.minX + sourceRect.minX,
            y: screenFrame.maxY - sourceRect.minY - displaySize.height
        )
        let windowSize = CGSize(
            width: displaySize.width + ScreenshotPinnedImageView.effectOutset * 2,
            height: displaySize.height + ScreenshotPinnedImageView.effectOutset * 2
        )

        return CGRect(
            x: imageOrigin.x - ScreenshotPinnedImageView.effectOutset,
            y: imageOrigin.y - ScreenshotPinnedImageView.effectOutset,
            width: windowSize.width,
            height: windowSize.height
        )
    }

    private static let minimumPinLength: CGFloat = 8
    private static let escapeKeyCode: UInt16 = 53
}

private struct ScreenshotPinEntry {
    let id: UUID
    let pin: ScreenshotPinItem
    let window: ScreenshotPinWindow
}

@MainActor
private final class ScreenshotPinItem: ObservableObject, Identifiable {
    let id: UUID
    let image: NSImage
    let displaySize: CGSize
    @Published var isSelected = false

    init(id: UUID, image: NSImage, displaySize: CGSize) {
        self.id = id
        self.image = image
        self.displaySize = displaySize
    }
}

private struct ScreenshotPinnedImageView: View {
    static let effectOutset: CGFloat = 22

    @ObservedObject var pin: ScreenshotPinItem
    let select: () -> Void
    let close: () -> Void
    let currentWindowFrame: () -> CGRect?
    let moveWindow: (CGRect) -> Void

    @State private var dragMouseOffset: CGSize?
    @State private var dragWindowSize: CGSize?

    var body: some View {
        ZStack(alignment: .topTrailing) {
            imageSurface

            if pin.isSelected {
                closeButton
                    .transition(.scale(scale: 0.88).combined(with: .opacity))
            }
        }
        .padding(Self.effectOutset)
        .frame(
            width: pin.displaySize.width + Self.effectOutset * 2,
            height: pin.displaySize.height + Self.effectOutset * 2
        )
        .contentShape(Rectangle())
        .onTapGesture {
            select()
        }
        .gesture(dragGesture)
        .animation(.easeOut(duration: 0.14), value: pin.isSelected)
    }

    private var imageSurface: some View {
        let shape = RoundedRectangle(cornerRadius: 8, style: .continuous)

        return Image(nsImage: pin.image)
            .resizable()
            .interpolation(.high)
            .frame(width: pin.displaySize.width, height: pin.displaySize.height)
            .clipShape(shape)
            .overlay {
                shape
                    .strokeBorder(
                        .black.opacity(pin.isSelected ? 0.58 : 0.48),
                        lineWidth: pin.isSelected ? 5 : 4
                    )
            }
            .overlay {
                shape
                    .inset(by: pin.isSelected ? 2.5 : 2)
                    .strokeBorder(
                        pin.isSelected ? Color(nsColor: .systemBlue) : .white.opacity(0.94),
                        lineWidth: pin.isSelected ? 2.5 : 1.5
                    )
            }
    }

    private var closeButton: some View {
        Button {
            close()
        } label: {
            Image(systemName: "xmark")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 22, height: 22)
                .background(.black.opacity(0.62), in: Circle())
                .overlay(
                    Circle()
                        .stroke(.white.opacity(0.28), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.28), radius: 8, y: 3)
        }
        .buttonStyle(.plain)
        .help("删除贴图")
        .offset(x: 10, y: -10)
    }

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 2, coordinateSpace: .local)
            .onChanged { value in
                let mouseLocation = NSEvent.mouseLocation

                if dragMouseOffset == nil {
                    guard let frame = currentWindowFrame() else {
                        return
                    }

                    dragMouseOffset = CGSize(
                        width: mouseLocation.x - frame.minX,
                        height: mouseLocation.y - frame.minY
                    )
                    dragWindowSize = frame.size
                    select()
                }

                guard let dragMouseOffset, let dragWindowSize else {
                    return
                }

                moveWindow(
                    CGRect(
                        x: mouseLocation.x - dragMouseOffset.width,
                        y: mouseLocation.y - dragMouseOffset.height,
                        width: dragWindowSize.width,
                        height: dragWindowSize.height
                    )
                )
            }
            .onEnded { _ in
                dragMouseOffset = nil
                dragWindowSize = nil
            }
    }
}

private final class ScreenshotPinHostingView<Content: View>: NSHostingView<Content> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }
}

final class ScreenshotPinWindow: NSWindow {
    var pinID: UUID?
    weak var pinController: ScreenshotPinController?

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    override func sendEvent(_ event: NSEvent) {
        if event.type == .leftMouseDown || event.type == .rightMouseDown || event.type == .otherMouseDown {
            selectPin()
        }

        super.sendEvent(event)
    }

    override func mouseDown(with event: NSEvent) {
        selectPin()
        super.mouseDown(with: event)
    }

    override func keyDown(with event: NSEvent) {
        guard event.keyCode == Self.escapeKeyCode else {
            super.keyDown(with: event)
            return
        }

        Task { @MainActor [weak pinController] in
            pinController?.removeSelectedPin()
        }
    }

    private static let escapeKeyCode: UInt16 = 53

    private func selectPin() {
        guard let pinID else {
            return
        }

        Task { @MainActor [weak pinController] in
            pinController?.selectPin(pinID)
        }
    }
}
