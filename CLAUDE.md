# Crunchpad

Native SwiftUI macOS calculator built on the SpeedCrunch engine. This repo is a
GitHub fork of heldercorreia/speedcrunch; everything Crunchpad-specific lives in
`macos/` and `.github/` (see `macos/README.md`). Keep upstream files untouched so
`git merge upstream/main` stays clean.

Fixes to upstream code go on a branch cut from `upstream/main`, are sent
upstream as a PR (Jim's go-ahead first, since it posts under his account),
and are merged into Crunchpad's `main` from that same branch. Upstream's
test suites (`src/tests`) need the full Qt (`brew install qtbase` has
Widgets); note `testevaluator` runs with complex mode off, unlike the app.

## Releasing

1. Decide the version with Jim; it's a deliberate choice each time.
2. Edit `macos/VERSION` locally, commit, push to `main`.
3. CI (`.github/workflows/crunchpad.yml`, macos-15 runner) sees an untagged
   version and signs (Developer ID: James Payne, 9RM6Z83EG8), notarizes (App
   Store Connect API key), tags `vX.Y.Z`, and publishes the GitHub release.
4. Bump the Homebrew cask by hand in `~/src/homebrew-tap`
   (`Casks/crunchpad.rb`: `version`, `sha256` of the released DMG,
   `depends_on macos:` matching `LSMinimumSystemVersion`), run
   `brew style`, commit, push. There is deliberately no `TAP_GITHUB_TOKEN`
   secret, so CI skips this step.

Release builds must happen on macOS 15 (CI does). Homebrew's libraries target
the build machine's macOS, and `macos/build.sh` refuses to sign a bundle whose
libraries need a newer macOS than the app declares.

## Testing

Verify UI and keyboard behavior in the running app, not only by building. The
SwiftUI text field's field editor swallows arrow and Page keys, so those go
through `macos/App/Sources/Crunchpad/EditorKeys.swift`.
