import SwiftUI

@main
struct KeyFlowApp: App {
    @NSApplicationDelegateAdaptor(KeyFlowApplicationDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}
