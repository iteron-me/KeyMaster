import AppKit
import Foundation

struct InstalledApp: Identifiable, Hashable {
    let id: String
    let name: String
    let bundleIdentifier: String
    let url: URL
}

struct AppDiscoveryService {
    func installedApps() -> [InstalledApp] {
        let roots = [
            URL(fileURLWithPath: "/Applications", isDirectory: true),
            FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Applications", isDirectory: true),
            URL(fileURLWithPath: "/System/Applications", isDirectory: true)
        ]

        var appsByBundleIdentifier: [String: InstalledApp] = [:]

        for root in roots {
            guard let enumerator = FileManager.default.enumerator(
                at: root,
                includingPropertiesForKeys: [.isApplicationKey],
                options: [.skipsHiddenFiles, .skipsPackageDescendants]
            ) else {
                continue
            }

            for case let url as URL in enumerator where url.pathExtension == "app" {
                guard
                    let bundle = Bundle(url: url),
                    let bundleIdentifier = bundle.bundleIdentifier
                else {
                    continue
                }

                let displayName = bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
                    ?? bundle.object(forInfoDictionaryKey: "CFBundleName") as? String
                    ?? url.deletingPathExtension().lastPathComponent

                appsByBundleIdentifier[bundleIdentifier] = InstalledApp(
                    id: bundleIdentifier,
                    name: displayName,
                    bundleIdentifier: bundleIdentifier,
                    url: url
                )
            }
        }

        return appsByBundleIdentifier.values.sorted {
            $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
    }
}
