# Configuration Import And Export Implementation

1. Add the versioned portable archive model and archive service.
2. Add validation errors for unsupported versions, malformed data, and
   duplicate shortcut triggers.
3. Extend `AppState` with configuration snapshot and transactional replacement
   methods while preserving its ownership of persistence/index/engine sync.
4. Add right-click handling and the native management menu to the status item.
5. Add `NSSavePanel` export, `NSOpenPanel` import, replacement confirmation, and
   success/failure alerts in the application delegate.
6. Add a `KeyMasterTests` unit-test target and focused archive service tests.
7. Update architecture and user documentation for the portable configuration
   workflow.
8. Regenerate the Xcode project through the normal development script.
9. Run `git diff --check`, unit tests, and `./scripts/dev-run.sh`.

## Risk And Rollback

- Risk: a failed two-file persistence update could leave rules and history out
  of sync. Preserve the old snapshot and restore it before reporting failure;
  do not publish imported state until both writes succeed.
- Risk: duplicate triggers can crash the existing dictionary index rebuild.
  Validate before assigning imported rules.
- Risk: using the persisted `KeyRule` Codable shape would leak UUIDs, derived
  names, and timestamps into backups. Keep a dedicated portable DTO boundary.
- Risk: right-click handling can regress the existing left-click panel toggle.
  Keep event branching isolated in the status item action and manually verify
  both paths.
- Rollback is limited to removing the archive/service APIs, status menu actions,
  test target, and documentation changes; the existing persistence format is
  not migrated.
