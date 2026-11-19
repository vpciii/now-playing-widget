# Plan: Now Playing desktop widget

- **Status:** Approved
- **Date:** 2026-11-19
- **Author:** Claude (draft); approved by the owner 2026-11-19
- **Spec:** ./spec.md
- **Related ADRs:** ADR-0001

> This plan freezes with its spec: editable while `Draft` / `Under
> review` / `Approved`, and a historical record once the PR that marks
> the spec `Implemented` merges. A contradiction found later goes to a
> test, a new spec, or an ADR — not back into this file.

## Approach

Three pieces. A **core Swift package** holds everything that can be
tested without Music or WidgetKit: the *snapshot* model, the builder
that merges *supported route* and *queue source* results, the parsers,
the artwork URL allowlist, and the layout model the widget view renders
from. A **host app** (background agent, not sandboxed) does all the
talking to the outside: it listens for Music's
`com.apple.Music.playerInfo` notification, reads the *current song* over
AppleScript, runs the *queue source* script through `/usr/bin/swift`,
writes the *snapshot* and artwork into a shared App Group container, and
asks WidgetKit to reload. A **widget extension** (sandboxed) only reads
the latest *snapshot* and draws it.

Every edge of the host app is behind a protocol (`MusicReading`,
`QueueSource`, `MusicCommanding`, `ArtworkFetching`) so tests substitute
fakes and the private route (ADR-0001) is one replaceable component.

Controls are App Intents on widget buttons. The intent does not talk to
Music itself: it posts a distributed notification naming the command,
and the host app turns that into one AppleScript command (`next track`,
`back track`, `playpause`). This keeps Music access and its Automation
consent in a single process. The first task verifies this relay works
from the sandboxed extension; if it does not, the fallback is an Apple
Events entitlement on the extension.

## Components touched

All new.

- `project.yml` — XcodeGen definition of the app and widget targets. The
  `.xcodeproj` is generated and git-ignored, so the project structure
  lives in one reviewable file.
- `Packages/NowPlayingCore/` — Swift package: `Snapshot`,
  `SnapshotBuilder`, `QueueOutputParser`, `ArtworkURLPolicy`,
  `WidgetLayout`, `PlayerCommand`, and its tests.
- `App/` — host app: `MusicObserver` (notification), `AppleScriptMusic`
  (`MusicReading` + `MusicCommanding`), `SwiftScriptQueueSource`,
  `ArtworkFetcher`, `SnapshotStore`, `CommandRelay`, login item
  registration, menu bar item with Quit.
- `App/Resources/queue.swift` — the *queue source* script from the
  spike, emitting JSON on stdout.
- `Widget/` — widget extension: timeline provider, the overlay view,
  the three control intents.
- `docs/architecture.md` — the shape above, written with the first task.
- `scripts/check-traceability.sh` — fails if a spec criterion id is not
  cited by a test.

## Data model changes

No database. One JSON file plus image files in the App Group container,
overwritten on every change:

```
snapshot.json
{
  "state": "playing" | "paused" | "notPlaying",
  "current":  { "title", "artist", "album", "artworkFile"? } | null,
  "upcoming": { "title", "artist", "album", "artworkFile"? } | absent (unavailable),
  "updatedAt": ISO-8601,
  "expectedEndAt": ISO-8601 | null
}
current-artwork.jpg, upcoming-artwork.jpg   (downscaled to 600 px)
```

Sensitivity: listening metadata for the song playing now, kept only on
this Mac, replaced on each track change, removed by deleting the app's
group container. No history is kept.

Staleness (spec goal 4): the timeline carries a second entry at
`expectedEndAt` plus a margin that flips the widget to "not playing", so
a crashed or quit host app cannot leave a finished song looking live.
The host app also writes "not playing" when it quits.

### Decisions

- *2026-11-19* — **Shared folder instead of an App Group.** The build
  failed with "requires a provisioning profile" for the App Group
  entitlement, and this Mac has no developer team. The *snapshot* now
  lives in `~/Library/Application Support/NowPlaying/`, which the
  sandboxed widget reads through a read-only sandbox exception. With
  that change the app builds and runs ad hoc-signed, so plan risk 1 (no
  signing identity) no longer blocks anything. Undo: switch
  `SharedContainer` back to an App Group once a team exists.

- *2026-11-19* — **Queue script is piped, not passed by path.** Xcode
  will not copy a `.swift` file as a bundle resource, so the script
  ships as `queue-source.swiftscript` and the host app feeds it to
  `/usr/bin/swift -` on standard input.
- *2026-11-19* — **Current artwork falls back to the queue source's
  URL.** Streamed songs often have no artwork over AppleScript at the
  moment the track changes. The queue's first item is the same song and
  carries an artwork URL, fetched under the same allowlist (R-10).
- *2026-11-19* — **Stale widget process.** macOS keeps the old widget
  extension process running after a rebuild; `scripts/run.sh` stops it.

- *2026-11-19* — **Installed to `/Applications`.** The owner agreed to
  install a release copy there so the login item has a stable path;
  only that copy registers itself. `scripts/uninstall.sh` is the undo.
- *2026-11-19* — **SC-9 is tested in the core package**, not an app
  test target as the test strategy said: the agent flag is read from
  `App/Info.plist`, and login item registration and the Quit command
  are decided by `HostAppPolicy`, which the app only carries out.

- *2026-11-19* — **Details view state lives in the widget extension.**
  The toggle intent runs in the extension and WidgetKit reloads the
  timeline after it, so the state is a `UserDefaults` value there rather
  than a field in the *snapshot* relayed through the host app. It is
  keyed to the *current song*, which is what closes it on a track
  change.

- *2026-11-19* — **Current artwork comes from the queue source's URL
  first; AppleScript is the fallback.** This reverses the order in the
  earlier entry above. Found on the desktop: after a track change the
  widget showed the right title on the previous song's cover, because
  AppleScript was still returning the old artwork when asked. The
  queue's URL belongs to the song by construction. When there is no URL
  (a local file, or the queue source failed) AppleScript is used and
  read a second time 2.5 s later. Regression test:
  `ArtworkURLPolicyTests::currentArtworkPrefersQueueURL`.

- *2026-11-19* — **A "stopped" reading settles for one second before it
  is shown.** Starting a different playlist made Music report "stopped"
  three times within 100 ms before the new song, so the widget flashed
  "Not playing" and spent three reloads. Music not running is still
  shown at once. Regression test:
  `SnapshotBuilderTests::stoppedReadingSettles`.

- *2026-11-19* — **Like is two commands, not a toggle.** The widget
  sends the state it wants (`like` or `removeLike`), chosen from the
  *rating* it is showing, so a press never does the opposite of what the
  icon implied. The *rating* is read with the *current song* over
  AppleScript (`favorited`) and added to the *snapshot*.
- *2026-11-19* — **Dislike was built and removed.** `set disliked` over
  AppleScript returned no error but was never reported back for a
  streamed song, and MediaRemote lists `DislikeTrack` as disabled (and
  as station feedback, "Play Less Like This", not Suggest Less). The
  owner chose to remove the control rather than keep a dead one.

- *2026-11-19* — **Ratings are read back twice, 0.3 s and 3.5 s after
  the command.** Found on the desktop: likes did nothing visible,
  because Music reports a new `favorited` value only about 2.5 s after
  it is set and the single immediate reading still said "none".
  Regression test: `RatingTests::ratingIsReadBackLate`.

## API changes

None external. Internal contracts:

- *Queue source* script: exit 0 with
  `{"items":[{"title","artist","album","artworkURL"}...]}` where item 0
  is the *current song*; anything else (non-zero exit, timeout of 3 s,
  malformed JSON, fewer than two items) means "unavailable".
- Command relay: distributed notifications
  `<bundle-id>.command.next`, `.back`, `.playpause`, no payload.

## Alternatives considered

- **Hand-written `.xcodeproj`** — no extra tool, but an unreviewable
  generated-looking file that is easy to corrupt. XcodeGen is already
  installed here, is a build-time tool only, and is not shipped.
- **Controls sending Apple Events straight from the widget** — one hop
  fewer, but puts an Apple Events sandbox exception and a second
  Automation consent on the extension. Kept as the fallback.
- **Polling Music on a timer** — simpler than notifications, but wastes
  energy and is slower to react. The notification fired reliably in the
  spike.
- **Keeping the queue script running as a daemon** — avoids the 0.2 s
  launch per track change, but adds lifecycle management for no visible
  gain.

## Risks

| Risk | Likelihood | Impact | Mitigation |
| ---- | ---------- | ------ | ---------- |
| No code-signing identity on this Mac (0 found). App Groups and widget loading may not work with ad hoc signing. | High | Blocks the first task | Owner signs in to Xcode with an Apple ID (free) so it creates a development certificate; verified at the start of task 1. |
| WidgetKit throttles reloads; widget lags track changes (R-11). | Medium | Medium | Measure in task 2; report numbers to the owner before continuing. |
| Apple closes the interpreter route or renames private classes (ADR-0001). | Medium | Upcoming song disappears | Spec'd fallback to "unavailable" (R-5); single component to replace. |
| Sandboxed widget cannot post the relay notification. | Low | Controls need the fallback path | Verified in task 1 before any control UI is built. |
| Queue is wrong under shuffle, local playlists or radio. | Unknown | Wrong upcoming song | Manual check matrix in task 3; results recorded against the spec's open question. |
| Automation consent denied or reset. | Low | No data at all | Widget shows "not playing"; menu bar item shows a "needs permission" hint. |

## Rollout

Personal install on one Mac, built from Xcode, no flags. Five tasks,
each a small PR to `main`; the widget is usable after task 2.

Undo: remove the widget from the desktop, choose Quit from the menu bar
item, delete the app. That also removes the login item. Automation
consent can be revoked under System Settings > Privacy & Security >
Automation. Nothing here is irreversible.

## Observability

`os.Logger` in the host app, one subsystem, categories `music`, `queue`,
`widget`, `commands`: each track change, each *queue source* result or
failure reason, each reload request and each relayed command. Viewable
in Console. No metrics or remote reporting (R-10).

## Test strategy

- **Unit (core package, `swift test`)** — every success criterion except
  SC-9: snapshot building, fallback on each failure mode, no
  playlist-order input, state distinctions, layout model (overlay,
  scrim, control visibility, play/pause icon), command mapping with a
  counting fake, artwork URL allowlist. Each test cites its `SC-` id.
- **Integration (app target)** — SC-9: Info.plist agent flag, login item
  registration, Quit command.
- **Manual, recorded in the PR** — the widget appears in the gallery and
  on the desktop; refresh latency; the shuffle / local / radio matrix;
  each control against real Music.
- `scripts/check-traceability.sh` runs locally now and in CI once the
  repository has a remote.
