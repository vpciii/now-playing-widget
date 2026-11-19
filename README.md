# Now Playing widget

A large macOS desktop widget for the Music app. The artwork fills the
widget, with the current song, the upcoming song, and back, play/pause
and skip controls laid over it.

Personal use on one Mac. It reads the upcoming song through a private
macOS API and cannot be distributed through the App Store; see
[ADR 0001](docs/adr/0001-private-mediaremote-for-upcoming-song.md).

## Requirements

- macOS 15 or later (built and tested on macOS 27.2).
- Xcode, which provides the build tools and the `swift` interpreter the
  app uses at runtime to read the upcoming song. Without it the widget
  still works but shows "Up next unavailable".
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) to generate the
  project (`brew install xcodegen`).

No Apple developer account is needed; the app is signed to run locally.

## Install

```sh
scripts/install.sh
```

This builds a release copy, installs it to `/Applications/NowPlaying.app`,
starts it, and registers it to start at login. Then:

1. Allow "NowPlaying" to control Music when macOS asks. The permission
   is tied to the build, so macOS asks again after each reinstall.
2. Right-click the desktop, choose Edit Widgets, search for "Now Playing"
   and add it.

The app has no window or Dock icon. Its menu bar item (two beamed notes) has
a Quit command; a menu bar manager such as Bartender may hide the item.

## Uninstall

```sh
scripts/uninstall.sh
```

Removes the app, its login item and `~/Library/Application Support/NowPlaying`.
To revoke the Music permission as well, use System Settings > Privacy &
Security > Automation.

## Develop

```sh
scripts/run.sh                                  # build and run a debug copy
(cd Packages/NowPlayingCore && swift test)      # unit tests
scripts/check-traceability.sh                   # every spec criterion has a test
```

Use `scripts/run.sh` rather than building in Xcode alone: macOS keeps the
previous widget process alive after a rebuild and goes on drawing the old
code until that process is stopped. Run `scripts/install.sh` again
afterwards to go back to the installed copy.

## Documentation

- [Spec](specs/now-playing-widget/spec.md), [plan](specs/now-playing-widget/plan.md)
  and [tasks](specs/now-playing-widget/tasks.md)
- [Architecture](docs/architecture.md)
- [Glossary](docs/glossary.md)
- [Decisions](docs/adr/)
