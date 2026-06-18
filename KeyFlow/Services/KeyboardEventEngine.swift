import AppKit
import CoreServices
import CoreGraphics
import Foundation

final class KeyboardEventEngine {
    private(set) var isRunning = false
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var compiledRules: [ShortcutKey: KeyRule] = [:]
    private var suppressedKeyCodes: Set<Int> = []

    func start(rules: [KeyRule]) {
        guard !isRunning else { return }

        compiledRules = Dictionary(
            rules
                .filter(\.isEnabled)
                .map {
                    (
                        ShortcutKey(
                            modifiers: $0.trigger.modifiers,
                            keyCode: $0.trigger.keyCode
                        ),
                        $0
                    )
                },
            uniquingKeysWith: { _, newValue in newValue }
        )

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
        if event.getIntegerValueField(.eventSourceUserData) == Self.syntheticEventMarker {
            return Unmanaged.passUnretained(event)
        }

        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let eventTap {
                CGEvent.tapEnable(tap: eventTap, enable: true)
            }

            return Unmanaged.passUnretained(event)
        }

        let keyCode = Int(event.getIntegerValueField(.keyboardEventKeycode))

        if type == .flagsChanged {
            return Unmanaged.passUnretained(event)
        }

        if type == .keyUp {
            if suppressedKeyCodes.remove(keyCode) != nil {
                return nil
            }
            return Unmanaged.passUnretained(event)
        }

        guard type == .keyDown else {
            return Unmanaged.passUnretained(event)
        }

        let isAutoRepeat = event.getIntegerValueField(.keyboardEventAutorepeat) != 0
        let shortcutKey = ShortcutKey(
            modifiers: Self.modifiers(from: event.flags),
            keyCode: keyCode
        )

        guard let rule = compiledRules[shortcutKey] else {
            return Unmanaged.passUnretained(event)
        }

        suppressedKeyCodes.insert(keyCode)
        guard !isAutoRepeat || rule.action.allowsRepeat else {
            return nil
        }

        perform(rule)
        return nil
    }

    private static func modifiers(from flags: CGEventFlags) -> Set<ModifierKey> {
        var modifiers: Set<ModifierKey> = []

        if flags.contains(.maskControl) {
            modifiers.insert(.control)
        }

        if flags.contains(.maskAlternate) {
            modifiers.insert(.option)
        }

        if flags.contains(.maskShift) {
            modifiers.insert(.shift)
        }

        if flags.contains(.maskCommand) {
            modifiers.insert(.command)
        }

        return modifiers
    }

    private func perform(_ rule: KeyRule) {
        let action = rule.action

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
        case .sendKeyStroke(let keyStroke):
            KeyStrokeSender.send(keyStroke, sourceModifiers: rule.trigger.modifiers)
        }
    }

    fileprivate static let syntheticEventMarker: Int64 = 0x4B46_4D50
}

private struct ShortcutKey: Hashable {
    let modifiers: Set<ModifierKey>
    let keyCode: Int
}

private enum KeyStrokeSender {
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
