import AppKit
import CoreGraphics

final class KeyCaptureMonitor {
    private var monitor: Any?

    func start(onCapture: @escaping (LauncherKey) -> Void) {
        stop()

        monitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .flagsChanged]) { event in
            if event.type == .flagsChanged {
                if let key = Self.launcherKey(fromModifierEvent: event) {
                    onCapture(key)
                    return nil
                }
                return event
            }

            onCapture(
                LauncherKey(
                    keyCode: Int(event.keyCode),
                    displayName: Self.displayName(for: event)
                )
            )
            return nil
        }
    }

    func stop() {
        if let monitor {
            NSEvent.removeMonitor(monitor)
        }

        monitor = nil
    }

    private static func launcherKey(fromModifierEvent event: NSEvent) -> LauncherKey? {
        switch event.keyCode {
        case 55, 54:
            LauncherKey(keyCode: Int(event.keyCode), displayName: "Command")
        case 59, 62:
            LauncherKey(keyCode: Int(event.keyCode), displayName: "Control")
        case 58, 61:
            LauncherKey(keyCode: Int(event.keyCode), displayName: "Option")
        case 56, 60:
            LauncherKey(keyCode: Int(event.keyCode), displayName: "Shift")
        case 57:
            LauncherKey(keyCode: Int(event.keyCode), displayName: "Caps Lock")
        default:
            nil
        }
    }

    private static func displayName(for event: NSEvent) -> String {
        if let key = KeyCatalog.defaultKeys.first(where: { $0.keyCode == Int(event.keyCode) }) {
            return key.label
        }

        if let characters = event.charactersIgnoringModifiers, !characters.isEmpty {
            return characters.uppercased()
        }

        return "Key \(event.keyCode)"
    }
}

@MainActor
final class ModifierLayerMonitor {
    private var localMonitor: Any?
    private var globalMonitor: Any?

    func start(onChange: @escaping @MainActor (ModifierSnapshot) -> Void) {
        stop()

        localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.flagsChanged, .keyDown, .keyUp]) { event in
            onChange(Self.snapshot(from: event))
            return event
        }

        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.flagsChanged, .keyDown, .keyUp]) { event in
            Task { @MainActor in
                onChange(Self.snapshot(from: event))
            }
        }
    }

    func stop() {
        if let localMonitor {
            NSEvent.removeMonitor(localMonitor)
        }

        if let globalMonitor {
            NSEvent.removeMonitor(globalMonitor)
        }

        localMonitor = nil
        globalMonitor = nil
    }

    private static func snapshot(from event: NSEvent) -> ModifierSnapshot {
        return ModifierSnapshot(
            modifiers: modifiers(from: event.modifierFlags),
            keyCodes: modifierKeyCodes(from: event.modifierFlags)
        )
    }

    private static func modifiers(from flags: NSEvent.ModifierFlags) -> Set<ModifierKey> {
        var modifiers: Set<ModifierKey> = []

        if flags.contains(.control) {
            modifiers.insert(.control)
        }

        if flags.contains(.option) {
            modifiers.insert(.option)
        }

        if flags.contains(.shift) {
            modifiers.insert(.shift)
        }

        if flags.contains(.command) {
            modifiers.insert(.command)
        }

        return modifiers
    }

    private static func modifierKeyCodes(from flags: NSEvent.ModifierFlags) -> Set<Int> {
        let rawFlags = flags.rawValue
        var keyCodes: Set<Int> = []

        if rawFlags & Self.leftControlMask != 0 {
            keyCodes.insert(59)
        }

        if rawFlags & Self.rightControlMask != 0 {
            keyCodes.insert(62)
        }

        if rawFlags & Self.leftShiftMask != 0 {
            keyCodes.insert(56)
        }

        if rawFlags & Self.rightShiftMask != 0 {
            keyCodes.insert(60)
        }

        if rawFlags & Self.leftCommandMask != 0 {
            keyCodes.insert(55)
        }

        if rawFlags & Self.rightCommandMask != 0 {
            keyCodes.insert(54)
        }

        if rawFlags & Self.leftOptionMask != 0 {
            keyCodes.insert(58)
        }

        if rawFlags & Self.rightOptionMask != 0 {
            keyCodes.insert(61)
        }

        return keyCodes
    }

    private static let leftControlMask = UInt(0x0000_0001)
    private static let leftShiftMask = UInt(0x0000_0002)
    private static let rightShiftMask = UInt(0x0000_0004)
    private static let leftCommandMask = UInt(0x0000_0008)
    private static let rightCommandMask = UInt(0x0000_0010)
    private static let leftOptionMask = UInt(0x0000_0020)
    private static let rightOptionMask = UInt(0x0000_0040)
    private static let rightControlMask = UInt(0x0000_2000)
}

struct ModifierSnapshot: Equatable {
    var modifiers: Set<ModifierKey>
    var keyCodes: Set<Int>
}
