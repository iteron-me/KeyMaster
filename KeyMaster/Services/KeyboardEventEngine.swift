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

        Task { @MainActor in
            ActionDispatcher.shared.perform(rule)
        }
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

    static let syntheticEventMarker: Int64 = 0x4B46_4D50
}

private struct ShortcutKey: Hashable {
    let modifiers: Set<ModifierKey>
    let keyCode: Int
}
