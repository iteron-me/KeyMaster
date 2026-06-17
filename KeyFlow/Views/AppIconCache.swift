import AppKit

@MainActor
final class AppIconCache {
    static let shared = AppIconCache()

    private var iconsByBundleIdentifier: [String: NSImage] = [:]
    private var pendingHandlersByBundleIdentifier: [String: [(NSImage) -> Void]] = [:]

    func cachedIcon(for app: InstalledApp) -> NSImage {
        if let icon = iconsByBundleIdentifier[app.bundleIdentifier] {
            return icon
        }

        return Self.placeholderIcon
    }

    func icon(
        for app: InstalledApp,
        completion: @escaping (NSImage) -> Void
    ) {
        icon(
            forBundleIdentifier: app.bundleIdentifier,
            path: app.url.path,
            completion: completion
        )
    }

    func icon(
        forBundleIdentifier bundleIdentifier: String,
        completion: @escaping (NSImage) -> Void
    ) {
        icon(
            forBundleIdentifier: bundleIdentifier,
            path: nil,
            completion: completion
        )
    }

    private func icon(
        forBundleIdentifier bundleIdentifier: String,
        path: String?,
        completion: @escaping (NSImage) -> Void
    ) {
        if let icon = iconsByBundleIdentifier[bundleIdentifier] {
            completion(icon)
            return
        }

        if pendingHandlersByBundleIdentifier[bundleIdentifier] != nil {
            pendingHandlersByBundleIdentifier[bundleIdentifier]?.append(completion)
            return
        }

        pendingHandlersByBundleIdentifier[bundleIdentifier] = [completion]

        Task.detached(priority: .utility) {
            let resolvedPath = path ?? NSWorkspace.shared
                .urlForApplication(withBundleIdentifier: bundleIdentifier)?
                .path
            let icon = if let resolvedPath {
                NSWorkspace.shared.icon(forFile: resolvedPath)
            } else {
                NSImage(systemSymbolName: "app", accessibilityDescription: nil)
                    ?? NSImage(size: NSSize(width: 16, height: 16))
            }
            icon.size = NSSize(width: 16, height: 16)

            await MainActor.run {
                self.iconsByBundleIdentifier[bundleIdentifier] = icon
                let handlers = self.pendingHandlersByBundleIdentifier.removeValue(forKey: bundleIdentifier) ?? []

                for handler in handlers {
                    handler(icon)
                }
            }
        }
    }

    private static let placeholderIcon: NSImage = {
        let image = NSImage(systemSymbolName: "app", accessibilityDescription: nil)
            ?? NSImage(size: NSSize(width: 16, height: 16))
        image.size = NSSize(width: 16, height: 16)
        return image
    }()
}
