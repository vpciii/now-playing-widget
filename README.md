# Now Playing widget

A large macOS desktop widget for the Music app. The album artwork fills
the widget, with the current song, the song coming up next, and playback
controls laid over it.

- **Current and upcoming song**, with artwork for both. The upcoming song
  comes from Music's real queue, so it is right under shuffle and on
  radio stations.
- **Controls:** back, play/pause, skip, and a like button that sets the
  song as a Favorite in Music.
- **Details view:** click the song text to see the full title, artist and
  album of both songs; click again to close it.
- **Behaves like a stock widget:** add it from the widget gallery, place
  it on the desktop or in Notification Center. It updates within about a
  second of a track change.

A personal project, shared as is. It reads the upcoming song through a
private macOS API by a route that works around a restriction Apple added,
so it may break with any macOS or Xcode update and cannot be distributed
through the App Store; see
[ADR 0001](docs/adr/0001-private-mediaremote-for-upcoming-song.md). There
are no releases: you build it yourself.

Not affiliated with or endorsed by Apple. Apple Music is a trademark of
Apple Inc.

## Requirements

- macOS 15 or later. Built and tested on macOS 27.2 only.
- Xcode, for the build tools and for the `swift` interpreter the app uses
  at runtime to read the upcoming song. Open Xcode once after installing
  it so it finishes setting up.
- [XcodeGen](https://github.com/yonaskolb/XcodeGen), to generate the
  Xcode project: `brew install xcodegen`.

No Apple developer account is needed. The app is signed to run locally.

## Install

```sh
git clone https://github.com/vpciii/now-playing-widget.git
cd now-playing-widget
scripts/install.sh
```

The script builds a release copy, installs it to
`/Applications/NowPlaying.app`, starts it, and registers it to start at
login. Then:

1. **Allow the Music permission.** The first time a song plays, macOS
   asks whether "NowPlaying" may control Music. Choose Allow. Without it
   the widget stays on "Not playing".
2. **Add the widget.** Right-click the desktop, choose Edit Widgets,
   search for "Now Playing", and add it. It comes in the large size only.
3. **Play something in Music.**

The app has no window and no Dock icon. It lives in the menu bar as a
pair of beamed notes, with a Quit command.

## Using it

| Click | What happens |
|---|---|
| Back, play/pause, skip | The same as Music's own buttons. Back restarts the song, or goes to the previous one if the song has only just started. |
| Thumbs up | Likes the song (a Favorite in Music), or removes the like. The icon fills a few seconds after a like, because Music is slow to report it. |
| Song title, artist or "up next" | Opens or closes the details view. |
| Artwork | Brings Music to the front. |

When the desktop is covered by a window, macOS mutes all desktop widgets.
The widget darkens its artwork in that state so the text stays readable.
To keep widgets in full colour, see System Settings > Desktop & Dock.

## Troubleshooting

- **The widget is not in the gallery.** Make sure the app has been
  started once (`open /Applications/NowPlaying.app`), then reopen Edit
  Widgets.
- **It says "Not playing" while music plays.** Check that NowPlaying is
  allowed under System Settings > Privacy & Security > Automation, and
  that the app is running (look for the menu bar icon, or run
  `pgrep -x NowPlaying`).
- **It says "Up next unavailable".** The private route to Music's queue
  is not answering. Check that Xcode is installed and `/usr/bin/swift`
  runs. If it stopped after a macOS or Xcode update, Apple may have
  closed the route; everything else keeps working.
- **No menu bar icon.** Menu bar managers such as Bartender hide new
  items by default. Look in the manager's hidden section.
- **macOS asks for the Music permission again.** The permission is tied
  to the build, so it is asked again after each reinstall.
- **The widget shows old code after a rebuild.** macOS keeps the previous
  widget process alive. Use `scripts/run.sh` or `scripts/install.sh`,
  which stop it.

To see what the app is doing:

```sh
log stream --info --predicate 'subsystem BEGINSWITH "local.nowplaying"'
```

## Limitations

- Works with Apple's Music app only.
- One size (large) and one upcoming song.
- No dislike button: Music discards a dislike set from outside the app
  for streamed songs.
- The only network use is downloading artwork from Apple's image servers.
  Nothing is sent anywhere.

## Uninstall

```sh
scripts/uninstall.sh
```

Removes the app, its login item and
`~/Library/Application Support/NowPlaying`. To revoke the Music
permission as well, use System Settings > Privacy & Security >
Automation.

## Develop

```sh
scripts/run.sh                                  # build and run a debug copy
(cd Packages/NowPlayingCore && swift test)      # unit tests
scripts/check-traceability.sh                   # every spec criterion has a test
```

Run `scripts/install.sh` again afterwards to go back to the installed
copy; only one copy of the app should exist at a time.

The logic lives in a small Swift package (`Packages/NowPlayingCore`) that
is tested without Music or WidgetKit. The app and the widget are thin
layers over it.

## Documentation

- [Spec](specs/now-playing-widget/spec.md), [plan](specs/now-playing-widget/plan.md)
  and [tasks](specs/now-playing-widget/tasks.md)
- [Architecture](docs/architecture.md)
- [Glossary](docs/glossary.md)
- [Decisions](docs/adr/)

## License

[MIT](LICENSE).
