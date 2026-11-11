# thegipher

Giphy search panel for macOS Messages: global hotkey, search, paste. A native Swift
menu bar app (SwiftPM, AppKit + SwiftUI, no dependencies). See README.md for usage.

## Commands

- `swift build` / `swift test` — compile and run the unit tests.
- `./scripts/build-app.sh [--install]` — assemble and sign `build/TheGipher.app`.

## Layout

- `Sources/GipherCore` — GIPHY client, models, rendition selection. Pure logic; keep
  it UI-free and covered by `Tests/GipherCoreTests`.
- `Sources/TheGipher` — the app. `PanelController` owns the floating panel, keyboard
  handling and the send flow; `SearchModel` owns search state and paging; `Paster`
  does the clipboard and the synthetic ⌘V.

## Things that are deliberate

- The panel is a borderless **non-activating** `NSPanel`: it takes typing without
  making this app frontmost, so the conversation keeps focus for the paste. Don't
  activate the app when showing it.
- GIFs go on the clipboard as a **file URL**, the same thing Finder's Copy produces.
  That is the form Messages attaches as an animated GIF.
- The hotkey uses Carbon `RegisterEventHotKey` because it needs no privacy
  permission. Only the synthetic ⌘V needs Accessibility.
- macOS has no third-party Messages extension point; don't try to build one.

## Setup notes

- Set up with `new-project` (`~/development/tools`). The repo is on GitHub
  and backed up by `repo-backup`.
- The GIPHY API key is entered in the app and stored in its user defaults, not in
  `.env`.
