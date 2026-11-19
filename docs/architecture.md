# Architecture

The system's shape now. Terms are defined in `glossary.md`.

```
Music.app ──notification / AppleScript──▶ Host app ──writes──▶ shared folder ──reads──▶ Widget
                                           ▲                                             │
                                           └────────── command notification ◀────────────┘
```

## Components

- **`Packages/NowPlayingCore`** — Swift package with no dependencies.
  The *snapshot* model and file format, `SnapshotBuilder` (merges the
  *supported route* and *queue source* results), `QueueOutputParser`,
  `PlayerCommand`, `CommandDispatcher`, `TimelinePlan`, `SharedContainer`,
  `ArtworkURLPolicy`, `HostAppPolicy`,
  and `WidgetLayout`, which decides what the widget draws. All unit
  tests live here.
- **`App/`** — the *host app* (`local.nowplaying.app`). A background
  agent with a menu bar item; not sandboxed. `NowPlayingCoordinator`
  observes Music's `com.apple.Music.playerInfo` notification, reads the
  *current song* and artwork over AppleScript (`AppleScriptMusic`),
  writes the *snapshot* and a downscaled artwork JPEG, asks WidgetKit to
  reload, and carries out the widget's commands. It never launches Music.
  `SwiftScriptQueueSource` pipes the bundled `queue-source.swiftscript`
  into `/usr/bin/swift` to get the *upcoming song* (ADR-0001), and
  `ArtworkFetcher` downloads artwork from allowlisted URLs only. The
  *current song*'s artwork comes from the queue's URL for that song;
  AppleScript artwork is the fallback, because just after a track change
  it can still be the previous song's (`CurrentArtworkSource`).
- **`Widget/`** — the widget extension (`local.nowplaying.app.widget`).
  Sandboxed. Reads the latest *snapshot* and draws its `WidgetLayout`:
  artwork filling the widget, with the song text and controls overlaid on
  a scrim. Large size only; macOS 15 or later. Clicking the song text
  toggles the *details view*; which song it is open for is kept in the
  extension's own `UserDefaults` (`DetailsStore`), so the host app is not
  involved and a track change closes it.

## Boundaries and stores

- **Shared folder:** `~/Library/Application Support/NowPlaying/`, holding
  `snapshot.json`, `current-artwork.jpg` and `upcoming-artwork.jpg`. The host app writes it; the
  widget reads it through a read-only sandbox exception. It is not an App
  Group, because that entitlement needs a provisioning profile.
- **Commands:** the widget posts a distributed notification
  `local.nowplaying.command.<name>` with no payload, one name per
  `PlayerCommand` (playback: `next`, `back`, `playpause`; rating: `like`,
  `removeLike`); the host app observes it. Music announces nothing when
  a *rating* changes and reports a new like only about 2.5 s after it is
  set, so after a like command the host app reads Music again twice
  (0.3 s and 3.5 s) and publishes what it reports. There is no dislike:
  Music discards it for streamed songs.
- **Network:** one outbound use, an HTTPS GET of artwork from
  `*.mzstatic.com` (Apple's image CDN), enforced by `ArtworkURLPolicy`
  including on redirects.
- **External dependency:** Xcode's `swift` interpreter at `/usr/bin/swift`.
  Without it the *upcoming song* is unavailable; nothing else is affected.
- **Signing:** ad hoc ("sign to run locally"). No developer team. The
  Automation consent for Music is tied to the build's signature, so a
  rebuild can make macOS ask again.
- **Staleness:** the widget's timeline ends with a "not playing" entry 30
  seconds after a playing song's expected end (`TimelinePlan`).

## Install and startup

`scripts/install.sh` puts a release copy at `/Applications/NowPlaying.app`.
That copy registers itself as a login item (`SMAppService.mainApp`); a
development build in the `build` folder never does (`HostAppPolicy`).
Only one copy should exist at a time, since both carry the same widget
extension.

The menu bar item has a Quit command. Bartender, which the owner runs,
hides it by default: the item appeared once Bartender was quit (confirmed
2026-11-19).

## Repository

Public on GitHub at `vpciii/now-playing-widget`, MIT licensed (ADR-0002).
Commits use the owner's GitHub noreply address.

## Build

`scripts/run.sh` generates the project, builds, and runs a debug build.
It also stops the previous widget extension process: macOS keeps that
process alive across rebuilds, so without this the desktop keeps showing
the old widget code. The `.xcodeproj` is generated from `project.yml` and
not committed.
