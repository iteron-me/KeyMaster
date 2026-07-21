import ApplicationServices
import CoreGraphics
import Foundation

struct ScreenNavigationElement: Identifiable {
    let id: UUID
    var hint: String
    let role: String
    let title: String?
    let frame: CGRect
    let supportsPress: Bool
    let prefersFocus: Bool
    let element: AXUIElement

    init(
        id: UUID = UUID(),
        hint: String = "",
        role: String,
        title: String?,
        frame: CGRect,
        supportsPress: Bool,
        prefersFocus: Bool,
        element: AXUIElement
    ) {
        self.id = id
        self.hint = hint
        self.role = role
        self.title = title
        self.frame = frame
        self.supportsPress = supportsPress
        self.prefersFocus = prefersFocus
        self.element = element
    }
}

struct ScreenNavigationHintTarget: Identifiable, Equatable {
    let id: UUID
    let hint: String
    let frame: CGRect
    let label: String
}

enum ScreenNavigationScanResult {
    case success(processID: pid_t, elements: [ScreenNavigationElement])
    case permissionRequired
    case noFrontmostApplication
    case noCandidates
}
