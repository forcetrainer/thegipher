<p align="center">
  <img src="docs/icon.png" width="128" alt="TheGipher app icon: a gold varsity letter G on navy">
</p>

<h1 align="center">TheGipher</h1>

<p align="center">
  All of GIPHY, one hotkey away from any conversation on your Mac.<br>
  <em>Win one for the Gipher.</em>
</p>

<p align="center">
  <img src="docs/screenshot.png" width="49%" alt="The TheGipher search panel in dark mode, showing results for “touchdown”">
  <img src="docs/screenshot-light.png" width="49%" alt="The same panel in light mode">
</p>

Messages on the Mac only offers Apple's own small, filtered GIF search, and macOS has
no way for other apps to add themselves to the Messages "+" menu the way they can on
iOS. TheGipher is the next-fastest thing: a menu bar app with a floating search panel.
Press the hotkey while you're typing a message, search, hit Return, and the GIF lands
in the message field.

It isn't tied to Messages. It works in any app that accepts a pasted or dropped GIF
(Slack, Discord, Mail, Notes, …).

## Features

- **Global hotkey** (⌥⌘G by default) opens the panel over whatever you're doing,
  without pulling focus away from the conversation.
- **The whole GIPHY library**: GIFs and stickers, trending when you haven't typed
  anything, endless scrolling when you have.
- **One-key paste**: Return downloads the GIF and pastes it straight into the app you
  were in. ⌘Return also presses Return for you, so the GIF is sent in one keystroke.
  Fully usable without the mouse.
- **Large preview**: Space shows the highlighted GIF uncropped and full size before
  you commit to it.
- **Favorites**: star the GIFs you reach for most and find them in their own tab.
- **Drag and drop**: drag any GIF out of the panel into a conversation, a document, or
  onto the desktop.
- **Suggested searches**: trending searches when the field is empty, completions of
  what you've typed otherwise. Click one, or press Tab to take the first.
- **Recent**: the GIFs you've sent, ready to send again.
- **Any shortcut you like**: record your own hotkey in Settings.
- **Light and dark**: follows the system, or pick one.
- **Your choice of filtering**: content rating from G to R (R, the least filtered, is
  the default).
- **Paste size**: original quality, or smaller files for slow connections.

## Install

You need a Mac running macOS 14 or later, and Xcode (to build it).

```sh
git clone https://github.com/forcetrainer/thegipher.git && cd thegipher
./scripts/build-app.sh --install
```

That builds TheGipher, copies it to /Applications and starts it. Look for **GIF** in
the menu bar.

### First run

1. **Add a GIPHY API key.** The panel opens asking for one. Create a free key at
   <https://developers.giphy.com/dashboard/>: create an app and choose **API** (not
   SDK). Paste the key into the panel.
2. **Allow automatic pasting.** The first time you send a GIF, macOS asks you to allow
   TheGipher under System Settings › Privacy & Security › Accessibility. That
   permission is what lets it press ⌘V for you. Without it, TheGipher still copies the
   GIF and you press ⌘V yourself.

To start it automatically, turn on **Open at login** in Settings.

## Using it

| Key | Action |
| --- | --- |
| ⌥⌘G | Open or close the panel (changeable in Settings) |
| type | Search |
| ↩ | Paste the highlighted GIF, or the top result if none is highlighted |
| ⌘↩ | Paste it and send the message |
| ↓ ↑ ← → | Move through the results |
| space | Preview the GIF you're pointing at or have highlighted, large (space or esc to go back) |
| ⌘D | Add that GIF to Favorites, or remove it |
| tab | Complete what you've typed with the first suggestion |
| ⌘1 / ⌘2 / ⌘3 / ⌘4 | GIFs / Stickers / Favorites / Recent |
| esc | Close |

With the mouse: click a GIF to paste it, drag it to drop it somewhere, click the star
that appears on hover to favorite it, or right-click for the rest (**Paste and Send**,
**Copy GIF**, **Preview**, **Copy GIPHY Link**, **Open on GIPHY**).

Pointing at a GIF highlights it, the same as reaching it with the arrow keys, so
Space, ↩, ⌘↩ and ⌘D all act on whatever the pointer is over. (A pointer that's merely
resting where results appear doesn't count until you move it, so Space still types a
space while you're mid-search.)

In the Favorites and Recent tabs, typing filters the list by title.

Drag the panel by its top or bottom edge to move it. It reopens where you left it, so
you can park it beside your conversations.

**Settings** (menu bar **GIF** › Settings…) has the API key, content rating, paste
size, hotkey, appearance, and open-at-login. To change the hotkey, click it and press
the new combination; it needs ⌘, ⌥ or ⌃ (or a function key).

Settings checks a new shortcut for clashes: it refuses ones macOS itself uses
(Spotlight, screenshots, and so on) and warns when a menu command in an open app uses
the same keys, naming the app and command. It can't see shortcuts claimed by
background tools such as launchers or clipboard managers, because macOS has no way to
list those; if both respond to the same keys, change one of them.

## Good to know

- **Rate limit.** GIPHY's free key allows about 100 requests an hour. A new search
  uses two (results plus suggestions), and each further page of results uses one.
  Suggestions are remembered, so repeating a search costs less.
- **Privacy.** TheGipher talks only to GIPHY (your searches and the GIFs you load).
  Your API key, favorites and recent GIFs are stored on your Mac, in the app's
  preferences.
  There are no accounts and no analytics.
- **The Accessibility permission** is used to press ⌘V (and Return, for
  paste-and-send) in the app you were typing in, and to read the menu shortcuts of
  open apps when Settings checks your hotkey for clashes.
- **Paste and send** waits a little over half a second between pasting and pressing
  Return, to give the GIF time to attach. If a message ever goes out without its
  GIF, the app you're pasting into needed longer.

## Development

```sh
swift build                       # compile
swift test                        # unit tests
./scripts/build-app.sh            # build/TheGipher.app
./scripts/build-app.sh --install  # also copy to /Applications and relaunch
./scripts/make-icon.sh            # redraw Resources/AppIcon.icns from code
```

It's a Swift package with no dependencies:

- `Sources/GipherCore` — the GIPHY API client, models and hotkey type. No UI; covered
  by the tests.
- `Sources/TheGipher` — the app: hotkey, floating panel, search grid, paste, drag.

Debug builds can render the panel to an image without launching the app, which is how
the screenshot above was made:

```sh
BIN="$(swift build --show-bin-path)/TheGipher"
"$BIN" --snapshot live docs/screenshot.png touchdown   # real search, uses the installed app's key
"$BIN" --snapshot live docs/screenshot-light.png touchdown --light
"$BIN" --snapshot live /tmp/preview.png touchdown --preview   # with the large preview open
"$BIN" --snapshot grid /tmp/panel.png                  # fixed content; also: empty, setup
```

The build script signs with your Apple Development certificate when you have one, so
the Accessibility permission survives rebuilds. Without one it signs ad hoc, and macOS
asks for the permission again after each rebuild.

## License

[MIT](LICENSE): use it, copy it, change it, ship it. The GIFs themselves come from
GIPHY and belong to their owners; using the GIPHY API is subject to GIPHY's terms.

---

GIF search is powered by [GIPHY](https://giphy.com). TheGipher is not affiliated with
GIPHY or Apple.
