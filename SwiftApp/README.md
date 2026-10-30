# Elisa aprende música (iOS)

Native SwiftUI port of the web app at https://bluey.chiq.me, for Elisa's iPad and an iPhone.
Private use only: the Bluey art and fonts are Ludo Studio / BBC property, so this never goes to
the App Store or TestFlight. See `PLAN.md` for the plan and `Reference Material/` for what the
web app looks like.

## Layout

- `ElisaKit/`: the game's rules as a Swift package, tested on the Mac.
- `App/`: the SwiftUI app. `project.yml` generates `ElisaMusica.xcodeproj` (gitignored).
- `deploy`, `scripts/deploy/`: one-command OTA release.
- `scripts/devlog/server.py`: receives diagnostics from `--devlog` builds.

## Build and test

```bash
cd SwiftApp/ElisaKit && swift test
```

```bash
cd SwiftApp && xcodegen generate && open ElisaMusica.xcodeproj
```

UI tests (main flows) on the simulator:

```bash
cd SwiftApp && xcodebuild test -project ElisaMusica.xcodeproj -scheme ElisaMusica -destination 'platform=iOS Simulator,name=iPhone 16e' -derivedDataPath build/dd
```

Screenshots to compare with `Reference Material/`: the same command with
`TEST_RUNNER_ELISA_SCREENSHOTS=1` in front and `-only-testing:ElisaMusicaUITests/ScreenshotTests
-resultBundlePath build/shots.xcresult` at the end, then
`xcrun xcresulttool export attachments --path build/shots.xcresult --output-path build/shots`.

Launch arguments for testing: `-ElisaFreshState YES` (throwaway progress), `-ElisaLevel <chord
id>`, `-ElisaAnswer <chord id>` (always ask that chord).

## Progress

Saved in `Application Support/ElisaMusica/progress.json`, in the same format as the web app's
state download. To bring progress over from https://bluey.chiq.me: in the web app, reveal the
hidden download link by calling `enable_download()` six times in a row in the browser console
(under 1.5 s between calls; nothing in the page calls it yet), then tap the download link that
appears (`#download-link`, or call `download_state()` in the console); get the file onto the iPad (AirDrop to Files); in this app tap the title six
times quickly, pick the file and tap **Reemplazar**. The previous progress is kept beside it as
`progress.before-import-<time>.json`.

## Setup on a new machine

`Config/Local.xcconfig` (gitignored) holds the signing identity:

```
ELISA_MUSICA_BUNDLE_ID = me.chiq.elisa-musica
DEVELOPMENT_TEAM = <your team ID>
```

`.env` (gitignored) holds where releases are served from:

```
ELISA_MUSICA_UPLOAD_BASE=https://files.chiq.me
```

On developer.apple.com, the App ID `me.chiq.elisa-musica` must exist, and every iPad or iPhone
that should install the app must be registered before the build.

## Deploy

Run it on the macmini, which serves files.chiq.me from `~/c/file_server/files`. It needs a
clean working tree on `main` (web app changes included).

```bash
SwiftApp/deploy                 # bump the patch version, build, publish, tag, push
SwiftApp/deploy minor           # or major, or an exact X.Y.Z
SwiftApp/deploy --summary "New flags" --note "Guitar on every other level"
SwiftApp/deploy --yes           # no confirmation prompt
SwiftApp/deploy --devlog        # diagnostics build that reports to scripts/devlog/server.py
ELISA_MUSICA_UNSIGNED=1 SwiftApp/deploy   # unsigned build into SwiftApp/build/, publishes nothing
```

Install from Safari on the device: https://files.chiq.me/files/elisa-musica-install.html (add
it to the Home Screen). In the app, touch and hold the icon → **Install Latest** does the same.

For a `--devlog` build, start the server first. It writes to `SwiftApp/log/`:

```bash
python3 SwiftApp/scripts/devlog/server.py
```
