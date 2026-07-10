# Release Distribution

## Scenario: Unsigned GitHub DMG Release

### 1. Scope / Trigger

Use this contract when changing KeyMaster versioning, release scripts, code
signing, DMG contents, GitHub Actions, or release documentation. The current
distribution path intentionally supports ad-hoc signed, unnotarized early builds
and creates draft releases for manual testing.

### 2. Signatures

```sh
./scripts/package-release.sh \
  [--expected-version MAJOR.MINOR.PATCH] \
  [--build-number POSITIVE_INTEGER] \
  [--output-dir DIRECTORY] \
  [--keep-work-dir]

./scripts/release.sh MAJOR.MINOR.PATCH [--push]
```

GitHub Actions entry points:

- Push a tag matching `v*`.
- Manually dispatch `.github/workflows/release.yml` with an existing `tag`.

### 3. Contracts

- `project.yml` owns `MARKETING_VERSION`.
- A release tag must be exactly `v<MARKETING_VERSION>`.
- `scripts/release.sh VERSION` creates a local release commit and annotated tag.
- `scripts/release.sh VERSION --push` pushes the primary branch and tag with one
  `git push --atomic` operation.
- A direct user instruction to "release version X" authorizes `--push`; "prepare
  version X" does not authorize remote mutation.
- CI uses `github.run_number` as `CURRENT_PROJECT_VERSION`.
- The release job uses GitHub's `macos-26` image because the project compiles
  against Xcode 26 SDK APIs while retaining a macOS 15 deployment target.
- The packaged app identifier is `app.keymaster.mac` and its designated
  requirement comes from `scripts/keymaster-env.sh`.
- Release executables must contain both `arm64` and `x86_64`.
- Artifacts are named `KeyMaster-<version>-macos-universal.dmg` and
  `KeyMaster-<version>-macos-universal.dmg.sha256`.
- The DMG contains `KeyMaster.app` and an `/Applications` symlink.
- GitHub Releases remain drafts until a maintainer tests the downloaded artifact.
- No Apple certificate, notarization credential, or personal token is required
  for the unsigned workflow.

### 4. Validation & Error Matrix

| Condition | Required behavior |
| --- | --- |
| Version is not numeric `MAJOR.MINOR.PATCH` | Exit before modifying files |
| Worktree is dirty or branch is not the primary branch | Exit before fetch or version changes |
| Local HEAD differs from `origin/<primary>` | Refuse release preparation |
| Local or remote tag already conflicts | Refuse to overwrite or move the tag |
| Built version differs from requested/tag version | Fail before DMG creation |
| Bundle id, build number, or architecture is unexpected | Fail before publishing artifacts |
| DMG creation, verification, mount, or content check fails | Delete incomplete output artifacts |
| Existing GitHub Release is already public | Refuse asset replacement |
| Existing GitHub Release is a draft | Allow intentional asset clobber on retry |
| Runner Xcode SDK is older than the APIs referenced by the source | Use the pinned `macos-26` release image; do not raise the deployment target |

### 5. Good / Base / Bad Cases

- Good: update `0.1.0` to `0.2.0`, pass tests, create the release commit and tag,
  atomically push both, then review the generated draft Release.
- Base: run `./scripts/release.sh 0.2.0` without `--push`; the remote remains
  unchanged and a later `--push` invocation continues the prepared release.
- Bad: publish when only `project.yml` changed, force-move a public tag, upload a
  single-architecture app, or replace assets on an already-public Release.

### 6. Tests Required

- `bash -n scripts/*.sh`.
- Parse `.github/workflows/release.yml` and inspect trigger and permissions.
- Run the macOS unit-test scheme after project regeneration.
- In an isolated Git repository and bare remote, assert dirty-tree, wrong-branch,
  duplicate-tag, and divergence failures.
- In the isolated remote, assert local preparation does not push and `--push`
  sends the branch and tag atomically.
- Run `scripts/package-release.sh`; assert signature, bundle metadata, universal
  architectures, mounted entries, `hdiutil verify`, and SHA-256 verification.
- Run `./scripts/dev-run.sh` after release-infrastructure changes.
- Never test release Git mutations against the real `origin`.

### 7. Wrong vs Correct

#### Wrong

```sh
# Version-file changes silently publish, or branch and tag can arrive separately.
git push origin main
git push origin v0.2.0
```

#### Correct

```sh
# The explicit release command validates state and performs one remote mutation.
./scripts/release.sh 0.2.0 --push
```

Developer ID signing and notarization may replace the ad-hoc signing stage later,
but must preserve the version, tag, artifact verification, and draft-review
contracts unless a new design explicitly migrates them.
