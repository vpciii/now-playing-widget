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
  `PlayerCommand`, `SharedContainer`. All unit tests live here.
- **`App/`** — the *host app* (`local.nowplaying.app`). A background
  agent with a menu bar item; not sandboxed. Writes the *snapshot*, asks
  WidgetKit to reload, and receives the widget's commands.
- **`Widget/`** — the widget extension (`local.nowplaying.app.widget`).
  Sandboxed. Reads the latest *snapshot* and draws it; large size only.

## Boundaries and stores

- **Shared folder:** `~/Library/Application Support/NowPlaying/`, holding
  `snapshot.json` (and artwork files, later). The host app writes it; the
  widget reads it through a read-only sandbox exception. It is not an App
  Group, because that entitlement needs a provisioning profile.
- **Commands:** the widget posts a distributed notification
  `local.nowplaying.command.<next|back|playpause>` with no payload; the
  host app observes it.
- **Signing:** ad hoc ("sign to run locally"). No developer team.

## Not built yet

Reading Music (*supported route*), the *queue source* (ADR-0001),
artwork, carrying commands out, the overlay layout, and the login item.
See `specs/now-playing-widget/tasks.md`.

## Build

`xcodegen generate`, then build the `NowPlaying` scheme. The `.xcodeproj`
is generated from `project.yml` and not committed.
