import CoreGraphics
import Foundation

struct ScreenshotAnnotation: Equatable, Identifiable, Sendable {
    enum Content: Equatable, Sendable {
        case rectangle(CGRect)
        case text(ScreenshotTextAnnotation)
    }

    let id: UUID
    var content: Content

    init(id: UUID = UUID(), content: Content) {
        self.id = id
        self.content = content
    }
}

struct ScreenshotTextAnnotation: Equatable, Sendable {
    var text: String
    var origin: CGPoint
}
