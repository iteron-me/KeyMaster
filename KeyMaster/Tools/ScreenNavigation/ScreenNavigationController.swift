import AppKit
import Foundation

@MainActor
final class ScreenNavigationController {
    static let shared = ScreenNavigationController()

    private let scanner = AccessibilityElementScanner()
    private let overlayController = ScreenNavigationOverlayController()
    private let keyboardMonitor = ScreenNavigationKeyboardMonitor()
    private var session: ScreenNavigationSession?
    private var transientMessageID: UUID?

    func beginNavigation() {
        cancelNavigation()

        switch scanner.scanFrontmostApplication() {
        case .success(let processID, let scannedElements):
            transientMessageID = nil
            let hints = HintGenerator.generate(count: scannedElements.count)
            let elements = zip(scannedElements, hints).map { scannedElement, hint in
                var element = scannedElement
                element.hint = hint
                return element
            }

            guard !elements.isEmpty else {
                showTransientMessage("No keyboard targets found")
                return
            }

            let session = ScreenNavigationSession(processID: processID, elements: elements)
            self.session = session
            keyboardMonitor.start { [weak self] input in
                self?.handle(input)
            }
            overlayController.show(targets: elements.map(\.hintTarget))
        case .permissionRequired:
            showAccessibilityPermissionAlert()
        case .noFrontmostApplication:
            showTransientMessage("No active app")
        case .noCandidates:
            showTransientMessage("No keyboard targets found")
        }
    }

    func cancelNavigation() {
        transientMessageID = nil
        session = nil
        keyboardMonitor.stop()
        overlayController.close()
    }

    private func handle(_ input: ScreenNavigationKeyInput) {
        switch input {
        case .escape:
            cancelNavigation()
        case .backspace:
            guard let session else {
                return
            }

            session.removeLastInput()
            overlayController.updatePrefix(session.inputPrefix)
        case .upArrow, .downArrow:
            guard let session else {
                return
            }

            session.clearInput()
            overlayController.updatePrefix(session.inputPrefix)
        case .letter(let letter):
            guard let session else {
                return
            }

            session.append(letter)
            overlayController.updatePrefix(session.inputPrefix)

            let matches = session.matches
            if matches.count == 1, matches[0].hint == session.inputPrefix {
                let element = matches[0]
                cancelNavigation()
                AccessibilityElementExecutor.execute(element)
            }
        }
    }

    private func showTransientMessage(_ message: String) {
        let messageID = UUID()
        transientMessageID = messageID

        keyboardMonitor.start { [weak self] input in
            if case .escape = input {
                self?.cancelNavigation()
            }
        }
        overlayController.showMessage(message)

        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(1_200))
            guard self?.transientMessageID == messageID else {
                return
            }

            self?.cancelNavigation()
        }
    }

    private func showAccessibilityPermissionAlert() {
        NSApp.activate(ignoringOtherApps: true)

        let alert = NSAlert()
        alert.messageText = "Screen Navigation Needs Accessibility Permission"
        alert.informativeText = "KeyMaster needs Accessibility permission to inspect and activate visible UI elements."
        alert.addButton(withTitle: "Open Settings")
        alert.addButton(withTitle: "Cancel")

        if alert.runModal() == .alertFirstButtonReturn {
            PermissionService().requestAccessibilityPermission()
            PermissionService.openAccessibilitySettings()
        }
    }

}

@MainActor
private final class ScreenNavigationSession {
    let processID: pid_t
    let elements: [ScreenNavigationElement]
    private(set) var inputPrefix = ""

    init(processID: pid_t, elements: [ScreenNavigationElement]) {
        self.processID = processID
        self.elements = elements
    }

    var matches: [ScreenNavigationElement] {
        guard !inputPrefix.isEmpty else {
            return elements
        }

        return elements.filter { $0.hint.hasPrefix(inputPrefix) }
    }

    func append(_ letter: String) {
        let proposedPrefix = inputPrefix + letter

        if elements.contains(where: { $0.hint.hasPrefix(proposedPrefix) }) {
            inputPrefix = proposedPrefix
        }
    }

    func removeLastInput() {
        guard !inputPrefix.isEmpty else {
            return
        }

        inputPrefix.removeLast()
    }

    func clearInput() {
        inputPrefix = ""
    }
}

private extension ScreenNavigationElement {
    var hintTarget: ScreenNavigationHintTarget {
        ScreenNavigationHintTarget(
            id: id,
            hint: hint,
            frame: frame,
            label: title ?? role
        )
    }
}
