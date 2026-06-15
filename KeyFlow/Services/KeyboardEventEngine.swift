import AppKit
import CoreGraphics
import Foundation

final class KeyboardEventEngine {
    private(set) var isRunning = false
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var compiledRules: [ShortcutKey: KeyRule] = [:]
    private var compiledRulesByModifierFamily: [ShortcutKey: KeyRule] = [:]
    private var launcherKeyCodes: Set<Int> = []
    private var pressedKeyCodes: Set<Int> = []
    private var suppressedKeyCodes: Set<Int> = []

    func start(rules: [KeyRule]) {
        guard !isRunning else { return }

        compiledRules = Dictionary(
            rules
                .filter(\.isEnabled)
                .map {
                    (
                        ShortcutKey(
                            launcherKeyCode: $0.trigger.launcherKeyCode,
                            keyCode: $0.trigger.keyCode
                        ),
                        $0
                    )
                },
            uniquingKeysWith: { _, newValue in newValue }
        )
        compiledRulesByModifierFamily = Dictionary(
            rules
                .filter(\.isEnabled)
                .compactMap { rule in
                    guard let normalizedLauncherKeyCode = normalizedModifierKeyCode(for: rule.trigger.launcherKeyCode) else {
                        return nil
                    }

                    return (
                        ShortcutKey(
                            launcherKeyCode: normalizedLauncherKeyCode,
                            keyCode: rule.trigger.keyCode
                        ),
                        rule
                    )
                },
            uniquingKeysWith: { _, newValue in newValue }
        )
        launcherKeyCodes = Set(rules.filter(\.isEnabled).map(\.trigger.launcherKeyCode))

        let eventMask = (1 << CGEventType.keyDown.rawValue)
            | (1 << CGEventType.keyUp.rawValue)
            | (1 << CGEventType.flagsChanged.rawValue)

        eventTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(eventMask),
            callback: KeyboardEventEngine.eventCallback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        )

        guard let eventTap else {
            isRunning = false
            return
        }

        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)

        if let runLoopSource {
            CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
            CGEvent.tapEnable(tap: eventTap, enable: true)
            isRunning = true
        }
    }

    func stop() {
        if let eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
        }

        if let runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        }

        eventTap = nil
        runLoopSource = nil
        compiledRules = [:]
        compiledRulesByModifierFamily = [:]
        launcherKeyCodes = []
        pressedKeyCodes = []
        suppressedKeyCodes = []
        isRunning = false
    }

    private static let eventCallback: CGEventTapCallBack = { _, type, event, userInfo in
        guard let userInfo else {
            return Unmanaged.passUnretained(event)
        }

        let engine = Unmanaged<KeyboardEventEngine>.fromOpaque(userInfo).takeUnretainedValue()
        return engine.handle(type: type, event: event)
    }

    private func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let eventTap {
                CGEvent.tapEnable(tap: eventTap, enable: true)
            }

            return Unmanaged.passUnretained(event)
        }

        let keyCode = Int(event.getIntegerValueField(.keyboardEventKeycode))

        if type == .flagsChanged {
            updateModifierState(keyCode: keyCode, flags: event.flags)
            return Unmanaged.passUnretained(event)
        }

        if type == .keyUp {
            pressedKeyCodes.remove(keyCode)
            if suppressedKeyCodes.remove(keyCode) != nil {
                return nil
            }
            return Unmanaged.passUnretained(event)
        }

        guard type == .keyDown else {
            return Unmanaged.passUnretained(event)
        }

        pressedKeyCodes.insert(keyCode)

        if launcherKeyCodes.contains(keyCode) {
            return nil
        }

        guard let launcherKeyCode = activeLauncherKeyCode(from: event) else {
            return Unmanaged.passUnretained(event)
        }

        let shortcutKey = ShortcutKey(
            launcherKeyCode: launcherKeyCode,
            keyCode: keyCode
        )

        guard let rule = rule(for: shortcutKey) else {
            return Unmanaged.passUnretained(event)
        }

        suppressedKeyCodes.insert(keyCode)
        perform(rule.action)
        return nil
    }

    private func rule(for shortcutKey: ShortcutKey) -> KeyRule? {
        if let rule = compiledRules[shortcutKey] {
            return rule
        }

        guard let normalizedLauncherKeyCode = normalizedModifierKeyCode(for: shortcutKey.launcherKeyCode) else {
            return nil
        }

        return compiledRulesByModifierFamily[
            ShortcutKey(
                launcherKeyCode: normalizedLauncherKeyCode,
                keyCode: shortcutKey.keyCode
            )
        ]
    }

    private func updateModifierState(keyCode: Int, flags: CGEventFlags) {
        guard launcherKeyCodes.contains(keyCode) else {
            return
        }

        if modifierFlag(for: keyCode).map(flags.contains) ?? false {
            pressedKeyCodes.insert(keyCode)
        } else {
            pressedKeyCodes.remove(keyCode)
        }
    }

    private func activeLauncherKeyCode(from event: CGEvent) -> Int? {
        for keyCode in launcherKeyCodes where pressedKeyCodes.contains(keyCode) {
            return keyCode
        }

        let flags = event.flags
        let modifierKeyCodes: [(Int, CGEventFlags)] = [
            (55, .maskCommand),
            (54, .maskCommand),
            (59, .maskControl),
            (62, .maskControl),
            (58, .maskAlternate),
            (61, .maskAlternate),
            (56, .maskShift),
            (60, .maskShift),
            (57, .maskAlphaShift)
        ]

        return modifierKeyCodes.first { keyCode, flag in
            launcherKeyCodes.contains(keyCode) && flags.contains(flag)
        }?.0
    }

    private func modifierFlag(for keyCode: Int) -> CGEventFlags? {
        switch keyCode {
        case 55, 54:
            .maskCommand
        case 59, 62:
            .maskControl
        case 58, 61:
            .maskAlternate
        case 56, 60:
            .maskShift
        case 57:
            .maskAlphaShift
        default:
            nil
        }
    }

    private func normalizedModifierKeyCode(for keyCode: Int) -> Int? {
        switch keyCode {
        case 55, 54:
            55
        case 59, 62:
            59
        case 58, 61:
            58
        case 56, 60:
            56
        case 57:
            57
        default:
            nil
        }
    }

    private func perform(_ action: KeyAction) {
        switch action {
        case .openApp(let bundleIdentifier, _):
            Task { @MainActor in
                AppLauncher.open(bundleIdentifier: bundleIdentifier)
            }
        case .openURL(_, let value):
            Task { @MainActor in
                AppLauncher.openURL(value)
            }
        case .runCommand(_, let command):
            CommandRunner.run(command)
        }
    }
}

private struct ShortcutKey: Hashable {
    let launcherKeyCode: Int
    let keyCode: Int
}

@MainActor
private enum AppLauncher {
    static func open(bundleIdentifier: String) {
        guard !bundleIdentifier.isEmpty else {
            return
        }

        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) else {
            return
        }

        NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
    }

    static func openURL(_ value: String) {
        guard let url = URL(string: value) else {
            return
        }

        NSWorkspace.shared.open(url)
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
