# Configuration Import And Export Design

## Boundaries

- `KeyMasterConfiguration` is the portable in-memory snapshot. It contains
  simplified rules and action history, not persisted `KeyRule` metadata.
- `ConfigurationArchiveService` owns JSON encoding, decoding, format-version
  checks, and structural validation. It does not mutate app state.
- `AppState` owns producing a snapshot and replacing persisted/in-memory rules
  and history, followed by rule-index and keyboard-engine synchronization.
- `KeyMasterApplicationDelegate` owns the AppKit right-click menu, open/save
  panels, replacement confirmation, and success/failure alerts.

## Archive Contract

The exported `.config` file is pretty-printed, sorted-key JSON. The default
filename is `KM-yyyyMMdd.config` in local time:

```json
{
  "version": 1,
  "rules": [
    {
      "modifiers": ["control"],
      "keyCode": 0,
      "action": {
        "type": "app",
        "bundleIdentifier": "com.apple.Safari",
        "name": "Safari"
      }
    }
  ],
  "history": {
    "web": [],
    "commands": []
  }
}
```

Version 1 preserves user-authored behavior while omitting internal rule UUIDs,
derived rule/key display names, creation/update timestamps, and export time.
Disabled rules encode `"enabled": false`; enabled rules omit the field. App
actions remain portable through bundle identifiers. Import regenerates UUIDs,
derived names, and timestamps. Unknown future action payloads or archive
versions fail decoding rather than being partially applied.

## Validation

Before showing the replacement confirmation, import must reject:

- unreadable or malformed JSON;
- any `version` other than 1;
- duplicate shortcut triggers (same modifier set and key code).

Validation returns user-facing errors. No current state or persistence file is
changed during decoding or validation.

## Replacement Flow

1. Right-click the menu bar icon and choose Import Configuration.
2. Select one `.config` file through `NSOpenPanel`.
3. Decode and validate the entire archive.
4. Show a destructive confirmation with imported rule/history counts.
5. Persist imported rules and history. If either save fails, attempt to restore
   the prior persisted snapshot and leave in-memory state unchanged.
6. Publish the imported rules/history, rebuild indexes through the existing
   `rules` observer, and resynchronize the keyboard engine.
7. Show success or an actionable error alert.

Export takes an `AppState` snapshot and writes it to the URL selected through
`NSSavePanel`. Export never changes app state.

## Menu Interaction

The status item button listens for left and right mouse-up events. Left-click
keeps the existing panel toggle. Right-click presents a native `NSMenu` with
Import Configuration and Export Configuration commands. The items use standard
SF Symbols and ellipses because they open dialogs.

## Compatibility And Security

- The archive is intentionally plaintext and human-inspectable. It may include
  URLs and explicit shell commands, so the export UI must state that the file
  contains the user's complete configuration.
- macOS permissions, installed apps, application binaries, machine paths, and
  transient runtime state are excluded.
- Missing destination apps do not invalidate an imported rule; the bundle
  identifier is retained for when the app becomes available.
- Future schema changes increment `version` and add explicit migration or
  rejection behavior.

## Testing

Add a unit-test target covering portable-field round-trip fidelity, compact JSON
shape, unsupported versions, malformed JSON, duplicate triggers, and
transactional replacement. The normal development script remains the
end-to-end build/install verification path.
