# Package unsigned DMG release

## Goal

Provide a repeatable, GitHub-hosted way to build and package KeyMaster as a
downloadable DMG without joining the Apple Developer Program. A maintainer marks
an intentional release with a version tag; GitHub Actions builds the artifact so
normal releases do not depend on one local Mac. The artifact is intended for
early public releases and trusted testers who accept that macOS Gatekeeper will
require manual approval before the first launch.

## Background

- `project.yml` is the source of truth for Xcode project generation.
- `scripts/dev-run.sh` currently creates a Debug build, installs it at
  `/Applications/KeyMaster.app`, and applies an ad-hoc signature with a stable
  designated requirement.
- The repository has no release packaging script or GitHub Actions workflow.
- The local toolchain includes `hdiutil`, `ditto`, `codesign`, and `shasum`, so
  DMG creation does not require a third-party dependency.
- The Release configuration targets macOS 15.0 and resolves to a universal
  `arm64` + `x86_64` build.
- No Developer ID signing identity is installed. The resulting app cannot be
  notarized and must not be presented as a trusted or Apple-verified release.
- Public macOS projects use several release models. Repository research found:
  Rectangle builds an ad-hoc DMG in CI for every push but does not publish it as
  a release; LinearMouse builds on `v*` tags and creates a draft GitHub Release;
  AltTab runs a fully automated signed/notarized semantic-release pipeline with
  multiple Apple and update-signing secrets; Stats only validates Release
  archives in public CI; Maccy and Ice expose no release workflow.

## Requirements

- Add a deterministic local packaging command that regenerates the Xcode project
  and builds KeyMaster using the Release configuration.
- Add a GitHub Actions workflow triggered by version tags matching `v*` and by
  manual dispatch for controlled retries or pre-release testing.
- Treat a Git tag as explicit release intent. Do not publish merely because the
  version field changed on the main branch.
- Add a repository-owned release orchestration command accepting a semantic
  version, for example `./scripts/release.sh 1.2.0`.
- The release command must validate the branch, clean working tree, remote
  synchronization, version syntax, existing tags, and expected repository files
  before modifying state.
- The release command must update `MARKETING_VERSION` in `project.yml`, regenerate
  `KeyMaster.xcodeproj`, verify that only expected release metadata changed, run
  the configured pre-release quality gate, create a release commit, and create an
  annotated `v<version>` tag.
- When remote publication is explicitly requested, push the release commit and
  tag atomically so GitHub cannot receive one without the other.
- A natural-language instruction such as "release version 1.2.0" may be fulfilled
  by the coding agent invoking the checked-in release command. The script remains
  the auditable source of release behavior.
- Keep `project.yml` as the human-readable marketing-version source. The release
  workflow must reject a tag whose version does not match the built app's
  `CFBundleShortVersionString`.
- Use the GitHub Actions run number as the CI build number while keeping local
  packaging able to accept an explicit build number.
- Package the Release app with an ad-hoc signature and the bundle identifier
  `app.keymaster.mac`.
- Produce a versioned DMG under the ignored `dist/` directory.
- Include an `/Applications` link in the mounted DMG so users can install with a
  standard drag-and-drop workflow.
- Produce a SHA-256 checksum alongside the DMG.
- Upload the DMG and checksum to a draft GitHub Release associated with the tag,
  with generated release notes and an explicit unsigned/unnotarized warning.
- Fail clearly when required tools are unavailable or when the expected app
  bundle is missing.
- Verify the app signature, bundle architecture, mounted DMG contents, and final
  disk image before reporting success.
- Document, in English and Chinese, that the release is not notarized and how a
  user can approve only KeyMaster through System Settings or Control-click Open.
- Keep the release path separate from `scripts/dev-run.sh`; development installs
  must retain their current stable `/Applications/KeyMaster.app` behavior.
- Structure the script so Developer ID signing and notarization can replace the
  ad-hoc signing stage later without redesigning the build and packaging stages.
- Keep the workflow permissions minimal: read repository contents during build
  and write contents only for creating or updating the draft release.

## Acceptance Criteria

- [ ] One documented command creates a Release DMG without third-party packaging
      utilities.
- [ ] Pushing a matching version tag runs the same packaging logic on a GitHub
      hosted macOS runner without requiring Apple signing secrets.
- [ ] The DMG filename includes the app version from the built bundle.
- [ ] The packaged app has identifier `app.keymaster.mac` and a valid ad-hoc
      signature.
- [ ] The packaged executable contains both `arm64` and `x86_64` architectures.
- [ ] Mounting the DMG shows `KeyMaster.app` and an `Applications` link.
- [ ] A SHA-256 checksum file is generated and can verify the DMG.
- [ ] English and Chinese documentation explain macOS 15+, installation,
      Gatekeeper approval, and Accessibility/Input Monitoring requirements.
- [ ] A successful tag workflow creates or updates a draft GitHub Release and
      attaches the DMG and checksum rather than publishing immediately.
- [ ] A tag/version mismatch fails before a release is created.
- [ ] `./scripts/release.sh 1.2.0` can prepare the version change, generated
      project update, release commit, and annotated tag without hand-editing.
- [ ] Release orchestration refuses a dirty tree, wrong branch, divergent remote,
      malformed version, duplicate version tag, or failed verification.
- [ ] The remote push path uses a single atomic push for the branch and tag.
- [ ] Existing development build and test behavior remains unchanged.
- [ ] `./scripts/dev-run.sh` succeeds after the repository changes.

## Out Of Scope

- Apple Developer Program enrollment.
- Developer ID signing, Hardened Runtime, notarization, or stapling.
- Mac App Store or installer package distribution.
- Automatic updates or Sparkle integration.
- Conventional-commit semantic version calculation or release creation triggered
  implicitly by main-branch changes.
- Automatically publishing a release without maintainer review.

## Release Authorization Contract

- `scripts/release.sh <version>` prepares the release commit and annotated tag
  locally but does not mutate the remote repository.
- `scripts/release.sh <version> --push` performs the guarded preparation and the
  atomic remote push.
- A direct natural-language instruction to the coding agent to "release version
  X" is explicit authorization for the `--push` path. Requests to "prepare
  version X" use the local-only path.
