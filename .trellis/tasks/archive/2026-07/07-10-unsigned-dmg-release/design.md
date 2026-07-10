# Unsigned DMG Release Design

## Overview

The release system has two layers:

1. A repository-owned packaging script performs all Xcode build, ad-hoc signing,
   DMG creation, and verification steps. It can run locally or in CI.
2. A thin GitHub Actions workflow decides when to run the script and attaches
   its outputs to the GitHub Release associated with a version tag.

This separation prevents the CI YAML from becoming the only executable release
documentation and keeps a future Developer ID migration localized to the
signing/notarization stage.

## Release Trigger

- Normal releases are triggered by pushing a tag such as `v0.2.0`.
- Main-branch pushes and pull requests may run build verification later, but do
  not create releases.
- `workflow_dispatch` provides an explicit manual execution path for testing and
  recovery. It must not infer a new public version from arbitrary source changes.
- A version-field change alone never creates a release. The tag is the deliberate
  and auditable release command.

## Release Orchestration Command

The maintainer-facing entry point is:

```sh
./scripts/release.sh <semantic-version> [--push]
```

The command implements a guarded state machine rather than a loose list of Git
commands:

1. Validate a stable `MAJOR.MINOR.PATCH` version and derive `v<version>`.
2. Require the expected primary branch, a clean working tree, and configured
   `origin` remote.
3. Fetch the primary branch and tags, then require local HEAD to match the remote
   primary branch so the release cannot silently omit upstream commits.
4. Reject an existing local or remote version tag.
5. Update the single `MARKETING_VERSION` entry in `project.yml` with exact-match
   guards; fail if the expected source shape has changed.
6. Regenerate `KeyMaster.xcodeproj` from `project.yml`.
7. Run the release preflight and inspect the Git diff, allowing only the expected
   version metadata and generated project changes.
8. Create `chore(release): <version>` and annotated tag `v<version>` locally.
9. With `--push`, use `git push --atomic origin <primary-branch> v<version>`.

The script does not call the GitHub Releases API. The pushed tag triggers the CI
workflow, which owns artifact production and draft Release creation. This keeps
Git credentials and GitHub API responsibilities separate from build packaging.

The coding agent can translate a direct user instruction such as "release 1.2.0"
into this command. Keeping the behavior in source control makes the same release
reproducible by a human maintainer and reviewable in pull requests.

## Version Contract

- `project.yml` remains the source of `MARKETING_VERSION` for source builds.
- The tag format is `v<MARKETING_VERSION>`; for example, project version `0.2.0`
  requires tag `v0.2.0`.
- After building, the packaging script reads `CFBundleShortVersionString` from
  `KeyMaster.app/Contents/Info.plist` and rejects a mismatching requested version.
- CI supplies `CURRENT_PROJECT_VERSION` from `github.run_number` so each CI
  release has a monotonic build identifier without requiring a second manual
  version edit.
- Artifact naming is `KeyMaster-<version>-macos-universal.dmg` plus the same name
  with `.sha256` appended.

## Build And Packaging Flow

```text
release tag
    -> GitHub-hosted macOS runner
    -> checkout exact tagged commit
    -> install XcodeGen
    -> repository packaging script
        -> regenerate KeyMaster.xcodeproj
        -> archive Release with signing disabled
        -> copy KeyMaster.app from the archive
        -> apply explicit ad-hoc app signature
        -> verify bundle id, version, signature, and arm64/x86_64 slices
        -> stage KeyMaster.app + Applications symlink
        -> create compressed UDZO DMG with hdiutil
        -> mount read-only and verify staged entries
        -> generate SHA-256 checksum
    -> create or update draft GitHub Release
    -> attach DMG and checksum
    -> maintainer smoke-tests downloaded artifact
    -> maintainer publishes draft
```

## Signing Boundary

- The Release archive is produced with Xcode signing disabled so Automatic
  signing cannot require a missing development team on GitHub runners.
- The final app receives an ad-hoc signature with bundle identifier
  `app.keymaster.mac` and a stable designated requirement consistent with the
  current development script.
- The disk image is not represented as Developer ID signed or notarized.
- Documentation states that Gatekeeper approval and privacy permissions are two
  separate user actions. Updates may require permissions to be re-enabled.

## GitHub Release Behavior

- The workflow uses the repository-provided `GITHUB_TOKEN`; no Apple credentials
  or personal access token is required.
- `contents: write` is granted only to the release job.
- The release starts as a draft. CI success proves packaging consistency, but
  cannot fully validate the browser quarantine, Gatekeeper, Accessibility, Input
  Monitoring, and Screen Recording experience on a fresh user machine.
- Generated release notes are augmented with a clear unsigned/unnotarized notice
  and links to English and Chinese installation instructions.
- Re-running the same tag updates assets with clobber semantics for transient CI
  failures. A source or packaging-code fix requires a new version tag, unless an
  unpublished draft tag is deliberately deleted and recreated by the maintainer.

The draft gate is the selected first-release policy. Publication remains a
maintainer action after smoke-testing the exact downloaded artifact.

## Local Reproducibility

Maintainers can run the packaging script locally with explicit version and build
number inputs. This path is for debugging and disaster recovery; it is not the
normal release requirement once GitHub Actions is enabled.

## Failure Handling

- Missing XcodeGen or Apple command-line tools: fail before building with an
  actionable message.
- Version mismatch: fail before DMG creation or GitHub Release mutation.
- Non-universal executable: fail before packaging.
- Invalid app signature, unexpected bundle identifier, failed DMG verification,
  or missing mounted entries: fail and retain no successful-looking artifact.
- Existing draft for the same tag: replace matching assets for an intentional
  retry; never create a second release for the same version.
- Failure after local commit/tag creation but before push: leave the prepared
  state visible and provide an explicit rollback command; do not silently delete
  Git history.
- Atomic push rejection: neither the release commit nor tag is accepted remotely;
  resolve the remote state and retry the same guarded command path.

## Trade-offs And Alternatives

### Detecting version changes on main

Rejected for the first iteration. It conflates editing metadata with release
approval, can accidentally publish from a normal merge, and complicates retries.

### Fully automatic semantic-release

Deferred. AltTab demonstrates that it works, but it requires strict conventional
commits, automatic version calculation, changelog/appcast updates, signing and
notarization secrets, and more recovery logic than KeyMaster currently needs.

### Local-only release builds

Rejected as the normal path because they depend on one workstation and make
reproducibility and auditability weaker. The local script remains as a fallback.

### Immediate publication after a successful tag build

Possible, but not recommended while the app is unsigned. A draft gate lets the
maintainer test the exact quarantined download and confirm the permission setup
instructions before users see the release.

## Future Developer ID Migration

The workflow structure remains unchanged. Replace the ad-hoc stage with temporary
keychain setup, Developer ID signing, Hardened Runtime, notarization, stapling,
and Gatekeeper assessment. Release triggering, version validation, DMG staging,
checksums, draft review, and upload remain reusable.
