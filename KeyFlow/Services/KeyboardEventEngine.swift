import AppKit
import CoreGraphics
import Foundation

final class KeyboardEventEngine {
    private(set) var isRunning = false
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var compiledRules: [KeyTrigger: KeyRule] = [:]
    private var launcherKeyCodes: Set<Int> = []
    private var pressedKeyCodes: Set<Int> = []

    func start(rules: [KeyRule]) {
        guard !isRunning else { return }

        compiledRules = Dictionary(
            uniqueKeysWithValues: rules
                .filter(\.isEnabled)
                .map { ($0.trigger, $0) }
        )
        launcherKeyCodes = Set(rules.filter(\.isEnabled).map(\.trigger.launcherKeyCode))

        let eventMask = (1 << CGEventType.keyDown.rawValue) | (1 << CGEventType.keyUp.rawValue)

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
        launcherKeyCodes = []
        pressedKeyCodes = []
        isRunning = false
    }

    private static let eventCallback: CGEventTapCallBack = { _, type, event, userInfo in
        guard let userInfo else {
            return Unmanaged.passRetained(event)
        }

        let engine = Unmanaged<KeyboardEventEngine>.fromOpaque(userInfo).takeUnretainedValue()
        return engine.handle(type: type, event: event)
    }

    private func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        let keyCode = Int(event.getIntegerValueField(.keyboardEventKeycode))

        if type == .keyUp {
            pressedKeyCodes.remove(keyCode)
            return Unmanaged.passRetained(event)
        }

        guard type == .keyDown else {
            return Unmanaged.passRetained(event)
        }

        pressedKeyCodes.insert(keyCode)

        if launcherKeyCodes.contains(keyCode) {
            return nil
        }

        guard let launcherKeyCode = activeLauncherKeyCode(from: event) else {
            return Unmanaged.passRetained(event)
        }

        let launcherDisplayName = compiledRules.keys.first {
            $0.launcherKeyCode == launcherKeyCode
        }?.launcherDisplayName ?? "Launcher"

        let trigger = KeyTrigger(
            launcherKeyCode: launcherKeyCode,
            launcherDisplayName: launcherDisplayName,
            keyCode: keyCode
        )

        guard let rule = compiledRules[trigger] else {
            return Unmanaged.passRetained(event)
        }

        perform(rule.action)
        return nil
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
            (60, .maskShift)
        ]

        return modifierKeyCodes.first { keyCode, flag in
            launcherKeyCodes.contains(keyCode) && flags.contains(flag)
        }?.0
    }

    private func perform(_ action: KeyAction) {
        switch action {
        case .openApp(let bundleIdentifier, _):
            AppLauncher.open(bundleIdentifier: bundleIdentifier)
        case .openURL(_, let value):
            AppLauncher.openURL(value)
        case .runCommand(_, let command):
            CommandRunner.run(command)
        }
    }
}

private enum AppLauncher {
    static func open(bundleIdentifier: String) {
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
