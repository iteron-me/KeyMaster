import AppKit
import CoreGraphics
import CoreServices
import Foundation

@MainActor
final class ActionDispatcher {
    static let shared = ActionDispatcher()

    private let toolRegistry: ToolRegistry

    init(toolRegistry: ToolRegistry = .shared) {
        self.toolRegistry = toolRegistry
    }

    func perform(_ rule: KeyRule) {
        let action = rule.action

        switch action {
        case .openApp(let bundleIdentifier, _):
            AppLauncher.open(bundleIdentifier: bundleIdentifier)
        case .openURL(_, let value):
            AppLauncher.openURL(value)
        case .runCommand(_, let command):
            CommandRunner.run(command)
        case .runTool(let invocation):
            Task {
                do {
                    try await toolRegistry.run(invocation)
                } catch {
                    assertionFailure("Failed to run tool: \(error)")
                }
            }
        case .sendKeyStroke(let keyStroke):
            KeyStrokeSender.send(keyStroke, sourceModifiers: rule.trigger.modifiers)
        case .lockScreen:
            KeyStrokeSender.send(.systemLockScreen, sourceModifiers: rule.trigger.modifiers)
        }
    }
}

extension KeyStroke {
    static let systemLockScreen = KeyStroke(
        modifiers: [.control, .command],
        keyCode: 12,
        keyDisplayName: "Q"
    )
}

enum KeyStrokeSender {
    static func send(_ keyStroke: KeyStroke, sourceModifiers: Set<ModifierKey>) {
        let source = CGEventSource(stateID: .hidSystemState)
        let releasedSourceModifiers = sourceModifiers.subtracting(keyStroke.modifiers)
        let pressedTargetModifiers = keyStroke.modifiers.subtracting(sourceModifiers)
        var currentModifiers = sourceModifiers

        for modifier in releasedSourceModifiers.sortedForDisplay.reversed() {
            currentModifiers.remove(modifier)
            post(
                keyCode: keyCode(for: modifier),
                keyDown: false,
                flags: cgFlags(for: currentModifiers),
                source: source
            )
        }

        for modifier in pressedTargetModifiers.sortedForDisplay {
            currentModifiers.insert(modifier)
            post(
                keyCode: keyCode(for: modifier),
                keyDown: true,
                flags: cgFlags(for: currentModifiers),
                source: source
            )
        }

        let targetFlags = cgFlags(for: currentModifiers)
        post(keyCode: keyStroke.keyCode, keyDown: true, flags: targetFlags, source: source)
        post(keyCode: keyStroke.keyCode, keyDown: false, flags: targetFlags, source: source)

        for modifier in pressedTargetModifiers.sortedForDisplay.reversed() {
            currentModifiers.remove(modifier)
            post(
                keyCode: keyCode(for: modifier),
                keyDown: false,
                flags: cgFlags(for: currentModifiers),
                source: source
            )
        }

        for modifier in releasedSourceModifiers.sortedForDisplay {
            currentModifiers.insert(modifier)
            post(
                keyCode: keyCode(for: modifier),
                keyDown: true,
                flags: cgFlags(for: currentModifiers),
                source: source
            )
        }
    }

    private static func post(
        keyCode: Int?,
        keyDown: Bool,
        flags: CGEventFlags,
        source: CGEventSource?
    ) {
        guard let keyCode else {
            return
        }

        guard let event = CGEvent(
            keyboardEventSource: source,
            virtualKey: CGKeyCode(keyCode),
            keyDown: keyDown
        ) else {
            return
        }

        event.flags = flags
        event.setIntegerValueField(.eventSourceUserData, value: KeyboardEventEngine.syntheticEventMarker)
        event.post(tap: .cghidEventTap)
    }

    private static func keyCode(for modifier: ModifierKey) -> Int? {
        switch modifier {
        case .control:
            59
        case .option:
            58
        case .shift:
            56
        case .command:
            55
        }
    }

    private static func cgFlags(for modifiers: Set<ModifierKey>) -> CGEventFlags {
        var flags: CGEventFlags = []

        if modifiers.contains(.control) {
            flags.insert(.maskControl)
        }

        if modifiers.contains(.option) {
            flags.insert(.maskAlternate)
        }

        if modifiers.contains(.shift) {
            flags.insert(.maskShift)
        }

        if modifiers.contains(.command) {
            flags.insert(.maskCommand)
        }

        return flags
    }
}

@MainActor
private enum AppLauncher {
    static func open(bundleIdentifier: String) {
        guard !bundleIdentifier.isEmpty else {
            return
        }

        if let foregroundApplication = foregroundApplication(bundleIdentifier: bundleIdentifier) {
            _ = foregroundApplication.hide()
            return
        }

        let runningApplication = preferredRunningApplication(bundleIdentifier: bundleIdentifier)
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier)
            ?? runningApplication?.bundleURL
        else {
            return
        }

        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        configuration.promptsUserIfNeeded = true
        configuration.allowsRunningApplicationSubstitution = true

        if runningApplication != nil {
            configuration.appleEvent = reopenAppleEvent(bundleIdentifier: bundleIdentifier)
        }

        NSWorkspace.shared.openApplication(at: url, configuration: configuration) { launchedApplication, _ in
            Task { @MainActor in
                let application = launchedApplication
                    ?? preferredRunningApplication(bundleIdentifier: bundleIdentifier)

                if let application {
                    bringToFront(application)
                }
            }
        }
    }

    static func openURL(_ value: String) {
        guard let url = URL(string: value) else {
            return
        }

        NSWorkspace.shared.open(url)
    }

    private static func foregroundApplication(bundleIdentifier: String) -> NSRunningApplication? {
        if let frontmostApplication = NSWorkspace.shared.frontmostApplication,
           frontmostApplication.bundleIdentifier == bundleIdentifier {
            return frontmostApplication
        }

        return NSRunningApplication.runningApplications(
            withBundleIdentifier: bundleIdentifier
        )
        .first(where: \.isActive)
    }

    private static func preferredRunningApplication(bundleIdentifier: String) -> NSRunningApplication? {
        let runningApplications = NSRunningApplication.runningApplications(
            withBundleIdentifier: bundleIdentifier
        )

        return runningApplications.first(where: \.isActive)
            ?? runningApplications.first(where: { $0.activationPolicy == .regular })
            ?? runningApplications.first
    }

    private static func bringToFront(_ application: NSRunningApplication) {
        _ = application.unhide()
        _ = application.activate(options: [.activateAllWindows])
    }

    private static func reopenAppleEvent(bundleIdentifier: String) -> NSAppleEventDescriptor {
        let event = NSAppleEventDescriptor.appleEvent(
            withEventClass: AEEventClass(kCoreEventClass),
            eventID: AEEventID(kAEReopenApplication),
            targetDescriptor: NSAppleEventDescriptor(bundleIdentifier: bundleIdentifier),
            returnID: AEReturnID(kAutoGenerateReturnID),
            transactionID: AETransactionID(kAnyTransactionID)
        )
        event.setParam(
            NSAppleEventDescriptor(boolean: true),
            forKeyword: AEKeyword(kAEApplicationActivationExpected)
        )
        return event
    }
}

private enum CommandRunner {
    static func run(_ command: String) {
        Task.detached(priority: .utility) {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/bin/zsh")
            process.arguments = ["-lc", command]

            do {
                try process.run()
            } catch {
                assertionFailure("Failed to run command: \(error)")
            }
        }
    }
}

