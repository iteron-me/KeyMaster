import AppKit
import SwiftUI

@MainActor
final class WindowManagementWindowController: NSObject, NSWindowDelegate {
    static let shared = WindowManagementWindowController()

    private var window: NSWindow?
    private var hostingController: NSHostingController<AnyView>?

    func show(appState: AppState) {
        let window = window ?? makeWindow(appState: appState)
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
    }

    func windowWillClose(_ notification: Notification) {
        guard notification.object as? NSWindow === window else {
            return
        }
        window = nil
        hostingController = nil
    }

    private func makeWindow(appState: AppState) -> NSWindow {
        let content = WindowManagementView(appState: appState)
        let controller = NSHostingController(rootView: AnyView(content))
        controller.view.frame = NSRect(origin: .zero, size: Self.windowSize)
        controller.view.autoresizingMask = [.width, .height]

        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: Self.windowSize),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Window Management"
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.contentViewController = controller
        window.center()
        window.collectionBehavior = [.managed, .canJoinAllSpaces]

        hostingController = controller
        self.window = window
        return window
    }

    private static let windowSize = NSSize(width: 620, height: 540)
}

private struct WindowManagementView: View {
    @ObservedObject var appState: AppState

    @State private var recordingOperation: WindowManagementOperation?
    @State private var monitor: Any?
    @State private var errorMessage: String?

    private let spatialOperations: [WindowManagementOperation] = [
        .leftHalf, .rightHalf, .fill, .center
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack(spacing: 10) {
                    Image(systemName: "rectangle.split.2x1")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(.tint)

                    Text("Window Management")
                        .font(.system(size: 22, weight: .semibold))

                    Spacer()
                }

                LazyVGrid(columns: Self.columns, spacing: 12) {
                    ForEach(spatialOperations) { operation in
                        WindowPlacementOption(
                            operation: operation,
                            bindings: bindings(for: operation),
                            isRecording: recordingOperation == operation,
                            record: { startRecording(operation) },
                            remove: appState.deleteRule
                        )
                    }
                }

                VStack(spacing: 0) {
                    ForEach([WindowManagementOperation.nextDisplay, .restore]) { operation in
                        WindowCommandOption(
                            operation: operation,
                            bindings: bindings(for: operation),
                            isRecording: recordingOperation == operation,
                            record: { startRecording(operation) },
                            remove: appState.deleteRule
                        )

                        if operation != .restore {
                            Divider().padding(.leading, 46)
                        }
                    }
                }
                .background(Color.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 8))

                if let errorMessage {
                    Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.red)
                        .lineLimit(2)
                }

                Spacer(minLength: 0)
            }
            .padding(20)
        }
        .frame(width: 620, height: 540, alignment: .topLeading)
        .background(Color(nsColor: .windowBackgroundColor))
        .onDisappear {
            stopRecording()
        }
    }

    private func bindings(for operation: WindowManagementOperation) -> [KeyRule] {
        appState.rules.filter { rule in
            guard case .runTool(let invocation) = rule.action else {
                return false
            }
            return WindowManagementOperation(invocation: invocation) == operation
        }
        .sorted { $0.trigger.displayTitle < $1.trigger.displayTitle }
    }

    private func startRecording(_ operation: WindowManagementOperation) {
        stopRecording()
        errorMessage = nil
        recordingOperation = operation
        appState.setShortcutCaptureActive(true)

        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if event.keyCode == 53 {
                stopRecording()
                return nil
            }

            guard !Self.modifierKeyCodes.contains(Int(event.keyCode)) else {
                return nil
            }

            let modifiers = ModifierLayerMonitor.modifiers(from: event.modifierFlags)
            guard !modifiers.isEmpty else {
                errorMessage = "Window shortcuts require at least one modifier."
                stopRecording()
                return nil
            }

            let trigger = KeyTrigger(
                modifiers: modifiers,
                keyCode: Int(event.keyCode),
                keyDisplayName: KeyCatalog.displayName(forKeyCode: Int(event.keyCode))
            )
            stopRecording()
            save(trigger, for: operation)
            return nil
        }
    }

    private func save(_ trigger: KeyTrigger, for operation: WindowManagementOperation) {
        if let existingRule = appState.rule(for: trigger),
           !existingRule.runsWindowManagement(operation) {
            let alert = NSAlert()
            alert.alertStyle = .warning
            alert.messageText = "Replace Existing Shortcut?"
            alert.informativeText = "\(trigger.displayTitle) currently runs \(existingRule.action.displayTitle)."
            alert.addButton(withTitle: "Replace")
            alert.addButton(withTitle: "Cancel")
            guard alert.runModal() == .alertFirstButtonReturn else {
                return
            }
        }

        appState.saveRule(trigger: trigger, action: .runTool(operation.invocation))
        errorMessage = nil
    }

    private func stopRecording() {
        if let monitor {
            NSEvent.removeMonitor(monitor)
        }
        monitor = nil
        recordingOperation = nil
        appState.setShortcutCaptureActive(false)
    }

    private static let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    private static let modifierKeyCodes: Set<Int> = [
        55, 54, 59, 62, 58, 61, 56, 60
    ]
}

private struct WindowPlacementOption: View {
    let operation: WindowManagementOperation
    let bindings: [KeyRule]
    let isRecording: Bool
    let record: () -> Void
    let remove: (KeyRule) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                WindowPlacementPreview(operation: operation)

                VStack(alignment: .leading, spacing: 5) {
                    Text(operation.title)
                        .font(.system(size: 14, weight: .semibold))

                    BindingList(bindings: bindings, remove: remove)
                }

                Spacer(minLength: 4)

                RecordShortcutButton(isRecording: isRecording, action: record)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 122, alignment: .topLeading)
        .background(Color.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(isRecording ? Color.accentColor : Color.primary.opacity(0.08))
        }
    }
}

private struct WindowCommandOption: View {
    let operation: WindowManagementOperation
    let bindings: [KeyRule]
    let isRecording: Bool
    let record: () -> Void
    let remove: (KeyRule) -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: operation.systemImage)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.tint)
                .frame(width: 24)

            Text(operation.title)
                .font(.system(size: 14, weight: .semibold))
                .frame(width: 92, alignment: .leading)

            BindingList(bindings: bindings, remove: remove)

            Spacer(minLength: 8)
            RecordShortcutButton(isRecording: isRecording, action: record)
        }
        .padding(.horizontal, 12)
        .frame(height: 58)
        .contentShape(Rectangle())
        .overlay {
            if isRecording {
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(Color.accentColor)
            }
        }
    }
}

private struct WindowPlacementPreview: View {
    let operation: WindowManagementOperation

    var body: some View {
        GeometryReader { proxy in
            let bounds = CGRect(origin: .zero, size: proxy.size).insetBy(dx: 5, dy: 5)
            RoundedRectangle(cornerRadius: 5)
                .stroke(Color.secondary.opacity(0.5), lineWidth: 1)
                .overlay(alignment: .topLeading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.accentColor.opacity(0.78))
                        .frame(width: placement(in: bounds).width, height: placement(in: bounds).height)
                        .offset(
                            x: bounds.minX + placement(in: bounds).minX,
                            y: bounds.minY + placement(in: bounds).minY
                        )
                }
        }
        .frame(width: 68, height: 48)
        .accessibilityLabel(operation.title)
    }

    private func placement(in bounds: CGRect) -> CGRect {
        switch operation {
        case .leftHalf:
            CGRect(x: 0, y: 0, width: bounds.width / 2, height: bounds.height)
        case .rightHalf:
            CGRect(x: bounds.width / 2, y: 0, width: bounds.width / 2, height: bounds.height)
        case .fill:
            CGRect(origin: .zero, size: bounds.size)
        case .center:
            CGRect(x: bounds.width * 0.18, y: bounds.height * 0.18, width: bounds.width * 0.64, height: bounds.height * 0.64)
        case .nextDisplay, .restore:
            .zero
        }
    }
}

private struct BindingList: View {
    let bindings: [KeyRule]
    let remove: (KeyRule) -> Void

    var body: some View {
        if bindings.isEmpty {
            Text("Not set")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        } else {
            FlowLayout(spacing: 5, rowSpacing: 5) {
                ForEach(bindings) { rule in
                    HStack(spacing: 4) {
                        Text(rule.trigger.compactTitle)
                            .font(.system(size: 11, weight: .semibold, design: .rounded))

                        Button {
                            remove(rule)
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 10, weight: .semibold))
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.secondary)
                        .help("Remove \(rule.trigger.displayTitle)")
                    }
                    .padding(.leading, 7)
                    .padding(.trailing, 5)
                    .frame(height: 24)
                    .background(Color.accentColor.opacity(0.12), in: Capsule())
                }
            }
        }
    }
}

private struct RecordShortcutButton: View {
    let isRecording: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: isRecording ? "keyboard.badge.ellipsis" : "plus")
                .font(.system(size: 12, weight: .semibold))
                .frame(width: 26, height: 26)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(isRecording ? Color.white : Color.accentColor)
        .background(isRecording ? Color.accentColor : Color.accentColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 6))
        .help(isRecording ? "Press shortcut, or Escape to cancel" : "Add Shortcut")
    }
}

private extension KeyRule {
    func runsWindowManagement(_ operation: WindowManagementOperation) -> Bool {
        guard case .runTool(let invocation) = action else {
            return false
        }
        return WindowManagementOperation(invocation: invocation) == operation
    }
}

private extension KeyTrigger {
    var compactTitle: String {
        let modifiers = modifiers.displaySymbols.replacingOccurrences(of: " ", with: "")
        return modifiers.isEmpty ? keyDisplayName : "\(modifiers)\(keyDisplayName)"
    }
}
