# Configuration Archives

## 1. Scope / Trigger

Apply this contract whenever changing portable KeyMaster configuration import,
export, archive fields, rule/action Codable shapes, or replacement persistence.
The archive is a user-controlled cross-version boundary and must be validated
before it reaches `AppState`.

## 2. Signatures

```swift
struct KeyMasterConfiguration: Equatable {
    var rules: [ConfigurationRule]
    var history: ConfigurationHistory
}

struct ConfigurationArchiveService {
    func data(for configuration: KeyMasterConfiguration) throws -> Data
    func write(_ configuration: KeyMasterConfiguration, to url: URL) throws
    func configuration(from url: URL) throws -> KeyMasterConfiguration
    func configuration(from data: Data) throws -> KeyMasterConfiguration
}

@MainActor
func replaceConfiguration(with configuration: KeyMasterConfiguration) throws
```

## 3. Contracts

- Extension: `.config`.
- Uniform type identifier: `app.keymaster.mac.configuration`, exported by the
  app in `Info.plist`, conforming to `public.json`, and tagged with the
  `.config` filename extension. Export uses this declared type. Import also
  accepts the system type resolved directly from the `.config` extension,
  because existing files can retain a dynamic type until LaunchServices has
  associated the declared type.
- Default name: `KM-yyyyMMdd.config` using local time. Pass the
  base name without an extension to `NSSavePanel`; the content type adds it.
- Encoding: JSON, pretty printed, sorted keys, and no date values.
- Required top-level fields: `version`, `rules`, and `history`.
- Version 1 contains all portable persisted user data: shortcut rules plus URL
  and command history.
- Portable rules contain only modifier set, key code, action payload, and an
  optional `enabled: false`. UUIDs, rule names, key display names, creation and
  update dates, and export time are forbidden.
- Import regenerates UUIDs, display names, and creation/update dates.
- App actions store bundle identifiers, never application paths or binaries.
- Permissions and transient runtime state are never exported.
- Imported rules/history are published only after both persistence writes
  succeed. A second-write failure restores both previous datasets.

## 4. Validation & Error Matrix

| Condition | Required Result |
| --- | --- |
| Missing or non-integer `version` | `invalidFile`; no mutation |
| Version is not current/supported | `unsupportedVersion`; no mutation |
| JSON or nested Codable payload is malformed | `invalidFile`; no mutation |
| Duplicate modifier-set/key-code trigger | `duplicateShortcut`; no mutation |
| First persistence write fails | Keep memory unchanged; report persistence failure |
| Second persistence write fails | Restore old rules and history; keep memory unchanged |
| Rollback fails | Report rollback failure and tell the user to reopen/review saved rules |

## 5. Good / Base / Bad Cases

- Good: export rules containing app, URL, command, tool, key mapping, and lock
  actions plus history; decode and compare the complete archive for equality.
- Base: empty rules and empty history remain a valid backup and can replace the
  current configuration after confirmation.
- Bad: an edited file defines two rules for `Control + A`; reject it before
  assigning `AppState.rules`, because the rule index requires unique triggers.

## 6. Tests Required

- Round trip: assert every supported action payload, enabled state, and action
  history survive encode/decode unchanged.
- Compact shape: inspect JSON keys and assert UUIDs, derived names, key display
  names, and all timestamps are absent.
- Format errors: assert malformed JSON and unsupported versions return the
  expected `ConfigurationArchiveError`.
- Identity errors: assert duplicate triggers are rejected.
- Replacement success: assert store and published `AppState` data both change.
- Replacement failure: make history saving mutate then throw; assert both store
  datasets and both published datasets equal the original snapshot afterward.

## 7. Wrong vs Correct

### Wrong

```swift
let archive = try decoder.decode([KeyRule].self, from: data)
rules = archive
```

Reusing persisted `KeyRule` leaks UUIDs, derived names, and timestamps into the
portable file. Assigning before validation can also crash on duplicate triggers.

### Correct

```swift
let imported = try archiveService.configuration(from: data)
try appState.replaceConfiguration(with: imported)
```

Decode and validate at the archive boundary, persist with rollback, then publish
the accepted snapshot and resynchronize derived indexes and the event engine.
