import AppKit
import Foundation

struct InstalledApp: Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let bundleIdentifier: String
    let url: URL
}

struct AppDiscoveryService: Sendable {
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

                appsByBundleIdentifier[bundleIdentifier] = InstalledApp(
                    id: bundleIdentifier,
                    name: Self.displayName(for: bundle, at: url),
                    bundleIdentifier: bundleIdentifier,
                    url: url
                )
            }
        }

        return appsByBundleIdentifier.values.sorted {
            $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
    }

    private static func displayName(for bundle: Bundle, at url: URL) -> String {
        for key in displayNameKeys {
            if let localizedName = bundle.localizedInfoDictionary?[key] as? String,
               !localizedName.isEmpty {
                return localizedName
            }
        }

        for key in displayNameKeys {
            if let name = bundle.object(forInfoDictionaryKey: key) as? String,
               !name.isEmpty {
                return name
            }
        }

        let fileDisplayName = FileManager.default.displayName(atPath: url.path)
        if !fileDisplayName.isEmpty {
            return fileDisplayName
        }

        return url.deletingPathExtension().lastPathComponent
    }

    private static let displayNameKeys = [
        "CFBundleDisplayName",
        "CFBundleName"
    ]
}
