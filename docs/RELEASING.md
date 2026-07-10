# Releasing KeyMaster

KeyMaster currently publishes ad-hoc signed, unnotarized DMG files through a
tag-triggered GitHub Actions workflow. The workflow creates a draft release so
the downloaded artifact can be tested before publication.

## Prepare A Release

Start from a clean, synchronized `main` branch. Use a three-component numeric
version:

```sh
./scripts/release.sh 0.2.0
```

The command verifies the repository state, updates `MARKETING_VERSION` in
`project.yml`, regenerates the Xcode project, runs unit tests, creates a
`chore(release): 0.2.0` commit, and creates annotated tag `v0.2.0`. It does not
change the remote repository.

Review the commit and tag, then publish them atomically:

```sh
./scripts/release.sh 0.2.0 --push
```

Running the command with `--push` from the original clean state performs both
preparation and publication in one guarded flow.

## GitHub Actions

Pushing the tag starts `.github/workflows/release.yml`. The workflow:

1. Checks out the exact tag and validates it against the app version.
2. Creates a universal Release archive without Apple signing credentials.
3. Applies an ad-hoc signature and verifies the app bundle.
4. Creates and mounts a compressed DMG containing KeyMaster and an Applications
   link.
5. Generates a SHA-256 checksum.
6. Creates a draft GitHub Release and uploads both files.

For a transient CI failure, rerun the workflow or use its manual dispatch with
the existing tag. A source or packaging fix should normally use a new patch
version rather than moving an existing tag.

## Smoke Test And Publish

Download the DMG and checksum from the draft release instead of testing a local
artifact. Verify the checksum, install the app, and confirm the real browser
quarantine flow:

- Control-click > Open works, or Privacy & Security shows Open Anyway.
- Accessibility and Input Monitoring can be granted.
- Global shortcuts work after permissions are enabled.
- Screen Recording can be granted when using screenshot tools.
- The app launches on both Apple silicon and Intel when test hardware is
  available.

Publish the draft only after these checks pass.

## Local Packaging

CI and local packaging use the same command:

```sh
./scripts/package-release.sh --expected-version 0.2.0 --build-number 2
```

Artifacts are written to `dist/`. Use `--keep-work-dir` to retain the temporary
archive and staging files for diagnosis.

## Recovering A Local Preparation

If the release has not been pushed, the script can be rerun with `--push`. To
cancel a local preparation, first verify that the tag is absent from GitHub, then
remove the local tag and undo the release commit while preserving its changes:

```sh
git tag -d v0.2.0
git reset --soft HEAD^
```

Do not rewrite a tag after its release has been published.

## Future Signing

Developer ID signing and notarization will replace the ad-hoc signing block in
`scripts/package-release.sh`. Versioning, tags, DMG staging, checksums, draft
review, and GitHub upload remain unchanged.
