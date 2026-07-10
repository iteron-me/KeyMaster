# Unsigned DMG Release Implementation Plan

## Scope Shape

Keep this as one end-to-end task. The packaging script, release orchestration,
GitHub workflow, and documentation are independently testable but share one
version/signing contract and only deliver user value when integrated.

## Implementation Checklist

- [x] Add `scripts/package-release.sh` as the shared local/CI packaging entry
      point.
- [x] Parse explicit options for expected marketing version, build number, output
      directory, and retained build workspace while providing safe defaults.
- [x] Validate required Apple tools and XcodeGen before mutating the output path.
- [x] Regenerate `KeyMaster.xcodeproj` and create a Release archive for a generic
      macOS destination with Xcode signing disabled and universal architectures
      requested explicitly.
- [x] Copy the archived app into an isolated staging area, apply the existing
      stable ad-hoc designated requirement, and verify strict/deep signature
      validity.
- [x] Read the built Info.plist to validate bundle identifier, marketing version,
      build number, and macOS deployment target.
- [x] Inspect the main executable with `lipo` and require both `arm64` and
      `x86_64` slices.
- [x] Stage `KeyMaster.app` plus an `/Applications` symlink and create a compressed
      UDZO disk image using `hdiutil`.
- [x] Verify the disk image, mount it read-only at a controlled temporary mount
      point, verify its entries and packaged app, then detach it through cleanup
      traps on success or failure.
- [x] Generate a portable SHA-256 file from within `dist/` so it does not contain
      machine-specific absolute paths.
- [x] Add `scripts/release.sh` with local preparation as the default and `--push`
      as the explicit remote mutation mode.
- [x] Validate semantic version syntax, primary branch, clean worktree, configured
      origin, remote synchronization, current source version, and local/remote tag
      absence before changing version metadata.
- [x] Update exactly one `MARKETING_VERSION` entry in `project.yml`, regenerate
      the Xcode project, run `git diff --check`, and reject unexpected changed
      paths.
- [x] Run the existing unit-test scheme as the local pre-tag quality gate without
      building a local DMG.
- [x] Create `chore(release): <version>` and annotated tag `v<version>`; with
      `--push`, push the primary branch and tag using one `git push --atomic`.
- [x] Detect an already-prepared local release state well enough to provide a
      clear continuation or exact push command instead of corrupting history.
- [x] Add `.github/workflows/release.yml` for `v*` tag pushes and manual retries
      against an existing tag.
- [x] Use a GitHub-hosted macOS runner, install XcodeGen, invoke the repository
      packaging script, and upload the DMG/checksum as workflow artifacts.
- [x] Create or update a draft GitHub Release using the repository token, minimal
      job permissions, generated notes, asset clobbering for retries, and a clear
      unsigned/unnotarized warning.
- [x] Add maintainer release documentation covering prepare, push, CI retry,
      Draft Release smoke test, publication, failure recovery, and the future
      Developer ID migration point.
- [x] Update `README.md` and `README.zh-CN.md` with Release download/install steps,
      checksum verification, Gatekeeper approval, privacy permissions, and the
      macOS 15 requirement.
- [x] Keep `docs/ROADMAP.md` accurate by marking the unsigned GitHub packaging
      foundation complete while retaining Developer ID signing/notarization as
      future work.

## Validation Plan

- [x] Run shell syntax checks on every new or modified shell script with
      `bash -n`.
- [x] Exercise release-script validation failures for malformed version, dirty
      worktree, wrong branch, duplicate tag, and remote divergence in isolated
      temporary Git repositories.
- [x] Exercise local prepare and atomic push against an isolated bare remote;
      confirm the release commit and tag arrive together.
- [x] Run `scripts/package-release.sh` locally and confirm the generated filename,
      checksum, app metadata, ad-hoc signature, universal executable, DMG
      verification, and mounted contents.
- [x] Parse or lint the workflow locally where available and inspect its event,
      permission, ref, and asset paths manually.
- [x] Run the project's unit tests after project regeneration.
- [x] Run `./scripts/dev-run.sh` as the required final repository verification and
      report whether the stable installed development app succeeds.
- [x] Inspect `git diff --check`, `git status`, and the final diff to ensure no
      release commit/tag was created in the real repository during implementation.

## Risk And Rollback Points

- Release orchestration changes Git history only after all local validation and
  tests pass. Failures before commit leave reviewable version metadata changes.
- No implementation test may push to the real `origin`; Git mutation tests use a
  bare repository under `/private/tmp`.
- DMG staging and DerivedData use owned temporary/output directories only. Cleanup
  must never target an arbitrary caller-provided path without validation.
- GitHub Release creation remains draft-only. A failed or incorrect artifact can
  be replaced before publication without moving the version tag.
- If workflow behavior is faulty, disable/remove the workflow while retaining the
  local packaging script; no application runtime or persisted user data changes
  are involved.
- Developer ID migration later replaces the signing/notarization block rather
  than changing release triggering or version semantics.
