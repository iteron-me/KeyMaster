import AppKit
import CoreGraphics
import Foundation

enum ScreenNavigationKeyInput {
    case escape
    case backspace
    case letter(String)
    case upArrow
    case downArrow
}

final class ScreenNavigationKeyboardMonitor {
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var suppressedKeyCodes: Set<Int> = []
    private var handleKeyInput: (@MainActor (ScreenNavigationKeyInput) -> Void)?

    var isRunning: Bool {
        eventTap != nil
    }

    func start(handleKeyInput: @escaping @MainActor (ScreenNavigationKeyInput) -> Void) {
        stop()
        self.handleKeyInput = handleKeyInput

        let eventMask = (1 << CGEventType.keyDown.rawValue)
            | (1 << CGEventType.keyUp.rawValue)

        eventTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(eventMask),
            callback: ScreenNavigationKeyboardMonitor.eventCallback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        )

        guard let eventTap else {
            self.handleKeyInput = nil
            return
        }

        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)

        if let runLoopSource {
            CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
            CGEvent.tapEnable(tap: eventTap, enable: true)
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
        suppressedKeyCodes = []
        handleKeyInput = nil
    }

    private static let eventCallback: CGEventTapCallBack = { _, type, event, userInfo in
        guard let userInfo else {
            return Unmanaged.passUnretained(event)
        }

        let monitor = Unmanaged<ScreenNavigationKeyboardMonitor>.fromOpaque(userInfo).takeUnretainedValue()
        return monitor.handle(type: type, event: event)
    }

    private func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if event.getIntegerValueField(.eventSourceUserData) == KeyboardEventEngine.syntheticEventMarker {
            return Unmanaged.passUnretained(event)
        }

        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let eventTap {
                CGEvent.tapEnable(tap: eventTap, enable: true)
            }

            return Unmanaged.passUnretained(event)
        }

        let keyCode = Int(event.getIntegerValueField(.keyboardEventKeycode))

        if type == .keyUp {
            if suppressedKeyCodes.remove(keyCode) != nil {
                return nil
            }

            return Unmanaged.passUnretained(event)
        }

        guard type == .keyDown,
              let input = input(from: event, keyCode: keyCode)
        else {
            return Unmanaged.passUnretained(event)
        }

        Task { @MainActor [handleKeyInput] in
            handleKeyInput?(input)
        }

        if input.allowsForegroundDelivery {
            return Unmanaged.passUnretained(event)
        }

        suppressedKeyCodes.insert(keyCode)
        return nil
    }

    private func input(from event: CGEvent, keyCode: Int) -> ScreenNavigationKeyInput? {
        if keyCode == Self.escapeKeyCode {
            return .escape
        }

        guard hasOnlyShiftOrNoModifier(event.flags) else {
            return nil
        }

        if keyCode == Self.backspaceKeyCode {
            return .backspace
        }

        if keyCode == Self.upArrowKeyCode {
            return .upArrow
        }

        if keyCode == Self.downArrowKeyCode {
            return .downArrow
        }

        guard let nsEvent = NSEvent(cgEvent: event),
              let character = nsEvent.charactersIgnoringModifiers?.uppercased().first,
              character >= "A",
              character <= "Z"
        else {
            return nil
        }

        return .letter(String(character))
    }

    private func hasOnlyShiftOrNoModifier(_ flags: CGEventFlags) -> Bool {
        var modifiers = flags.intersection(.maskAlphaShift)

        if flags.contains(.maskControl) {
            modifiers.insert(.maskControl)
        }

        if flags.contains(.maskAlternate) {
            modifiers.insert(.maskAlternate)
        }

        if flags.contains(.maskCommand) {
            modifiers.insert(.maskCommand)
        }

        return modifiers.subtracting(.maskAlphaShift).isEmpty
    }

    private static let escapeKeyCode = 53
    private static let backspaceKeyCode = 51
    private static let upArrowKeyCode = 126
    private static let downArrowKeyCode = 125
}

private extension ScreenNavigationKeyInput {
    var allowsForegroundDelivery: Bool {
        switch self {
        case .upArrow, .downArrow:
            true
        case .escape, .backspace, .letter:
            false
        }
    }
}
