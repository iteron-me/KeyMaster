import SwiftUI

@main
struct KeyMasterApp: App {
    @NSApplicationDelegateAdaptor(KeyMasterApplicationDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}
