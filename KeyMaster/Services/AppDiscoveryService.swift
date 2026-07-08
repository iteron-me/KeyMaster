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
        if let localizedDisplayName = localizedInfoPlistStringsDisplayName(for: bundle),
           let displayName = normalizedDisplayName(localizedDisplayName),
           !displayName.isEmpty {
            return displayName
        }

        if let localizedDisplayName = localizedInfoPlistDisplayName(for: bundle),
           let displayName = normalizedDisplayName(localizedDisplayName),
           !displayName.isEmpty {
            return displayName
        }

        let fileDisplayName = FileManager.default.displayName(atPath: url.path)
        if let displayName = normalizedDisplayName(fileDisplayName), !displayName.isEmpty {
            return displayName
        }

        for key in displayNameKeys {
            if let localizedName = bundle.object(forInfoDictionaryKey: key) as? String,
               let displayName = normalizedDisplayName(localizedName),
               !displayName.isEmpty {
                return displayName
            }
        }

        return url.deletingPathExtension().lastPathComponent
    }

    private static func localizedInfoPlistStringsDisplayName(for bundle: Bundle) -> String? {
        guard let resourceURL = bundle.resourceURL else {
            return nil
        }

        let localizations = Bundle.preferredLocalizations(
            from: bundle.localizations,
            forPreferences: Locale.preferredLanguages
        )

        for localization in localizations {
            let stringsURL = resourceURL
                .appendingPathComponent("\(localization).lproj", isDirectory: true)
                .appendingPathComponent("InfoPlist.strings")

            guard let data = try? Data(contentsOf: stringsURL),
                  let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil),
                  let localizedInfo = plist as? NSDictionary
            else {
                continue
            }

            for key in displayNameKeys {
                if let name = localizedInfo[key] as? String,
                   !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    return name
                }
            }
        }

        return nil
    }

    private static func localizedInfoPlistDisplayName(for bundle: Bundle) -> String? {
        guard let resourceURL = bundle.resourceURL else {
            return nil
        }

        let loctableURL = resourceURL.appendingPathComponent("InfoPlist.loctable")
        guard let data = try? Data(contentsOf: loctableURL),
              let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil),
              let loctable = plist as? NSDictionary
        else {
            return nil
        }

        let localizations = Bundle.preferredLocalizations(
            from: bundle.localizations,
            forPreferences: Locale.preferredLanguages
        )

        for localization in localizations {
            guard let localizedInfo = loctable[localization] as? NSDictionary else {
                continue
            }

            for key in displayNameKeys {
                if let name = localizedInfo[key] as? String,
                   !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    return name
                }
            }
        }

        return nil
    }

    private static func normalizedDisplayName(_ name: String) -> String? {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            return nil
        }

        if trimmedName.localizedCaseInsensitiveCompare("CFBundleDisplayName") == .orderedSame
            || trimmedName.localizedCaseInsensitiveCompare("CFBundleName") == .orderedSame {
            return nil
        }

        if trimmedName.hasSuffix(".app") {
            return String(trimmedName.dropLast(4))
        }

        return trimmedName
    }

    private static let displayNameKeys = [
        "CFBundleDisplayName",
        "CFBundleName"
    ]
}
