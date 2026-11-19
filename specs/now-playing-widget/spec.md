# Spec: Now Playing desktop widget

- **Status:** Approved
- **Date:** 2026-11-19
- **Author:** Claude (draft); approved by the owner 2026-11-19
- **Related ADRs:** ADR-0001

> This spec is editable while `Draft` / `Under review` / `Approved`.
> When the PR that marks it `Implemented` merges it **freezes** into a
> historical record; a contradiction found later goes to a test, a new
> spec, or an ADR — not back into this file.

## Problem

macOS has no desktop widget that shows what the Music app is playing
together with what it will play next. To see the upcoming song the owner
has to bring Music forward and open its Playing Next panel. Apple's own
Music widget shows recently played items, not the live queue.

The owner wants this at a glance on the desktop, behaving like any stock
widget: added from the widget gallery, placed on the desktop or in
Notification Center, and kept current without interaction.

## Goals

1. A glance at the desktop shows the current song with its artwork.
2. The same glance shows the upcoming song.
3. The widget installs, places and behaves like a stock macOS widget.
4. When information is unavailable the widget says so; it never shows a
   guess or a stale song as if it were live.
5. The owner can skip the current song, go back, or play/pause from the
   widget, without bringing Music forward.
6. The artwork is the visual centre of the widget, with the song
   information laid over it.

## Non-goals

- Controls beyond skip, back and play/pause: no volume, scrubbing,
  shuffle or repeat.
- Widget sizes other than large.
- Players other than Apple's Music app (Spotify, browsers, podcasts).
- Distribution to anyone else: no App Store, no notarized release.
- Showing more than one upcoming song.

## Requirements

Terms in *italics* are defined in `docs/glossary.md`.

- **R-1 (MUST)** The widget is offered in the large family only
  (`systemLarge`: two small widgets wide, two tall) and can be placed on
  the desktop and in Notification Center.
- **R-2 (MUST)** While Music is playing or paused, the widget shows the
  *current song*'s title, artist and album.
- **R-3 (MUST)** The widget shows the *current song*'s artwork filling
  the whole widget when Music provides one, and a neutral placeholder
  background when it does not.
- **R-4 (MUST)** The widget shows the *upcoming song*'s title and artist
  when the *queue source* returns one.
- **R-5 (MUST)** When the *queue source* fails or returns no next item,
  the widget shows an explicit "up next unavailable" state and still
  shows the *current song* from the supported route (R-2, R-3).
- **R-6 (MUST NOT)** The widget does not infer or guess an *upcoming
  song* from playlist or album order.
- **R-7 (MUST)** When Music is not running or is stopped, the widget
  shows a "not playing" state with no song details.
- **R-8 (MUST)** The widget distinguishes paused from playing.
- **R-9 (MUST)** The *host app* starts at login without showing a window
  and can be quit by the owner.
- **R-10 (MUST NOT)** The app sends no data anywhere; its only network
  traffic is downloading artwork images from the artwork URLs Music
  itself reports.
- **R-11 (SHOULD)** The widget reflects a track change within 5 seconds.
  WidgetKit controls refresh timing, so this is measured, not guaranteed
  (see Open questions).
- **R-12 (SHOULD)** The widget shows the *upcoming song*'s artwork as a
  thumbnail when available.
- **R-13 (SHOULD)** Clicking the widget outside its controls brings
  Music to the front.
- **R-14 (MUST)** The *current song* and *upcoming song* text and the
  controls are laid over the artwork, not beside it.
- **R-15 (MUST)** Overlaid text and controls stay legible over any
  artwork, light or dark: they sit on a darkening scrim and use a fixed
  light text colour.
- **R-16 (MUST)** The widget has a skip control that makes Music advance
  to the next song.
- **R-17 (MUST)** The widget has a back control with Music's standard
  back behaviour: it restarts the *current song*, or goes to the
  previous song when the *current song* has only just started.
- **R-18 (MUST)** The controls use the *supported route* only; they do
  not depend on the *queue source*.
- **R-19 (MUST NOT)** The controls are not shown in the "not playing"
  state.
- **R-20 (MUST)** The widget has a play/pause control that toggles
  Music between playing and paused, and its icon reflects which of the
  two it will do.

## Success criteria

- **SC-1** — The widget configuration declares exactly one supported
  family, `systemLarge`. (R-1)
- **SC-2** — Given a *snapshot* with a playing song, the widget entry
  exposes its title, artist and album unchanged. (R-2)
- **SC-3** — Given a *snapshot* with artwork, the entry carries the
  artwork; given one without, it carries the placeholder marker. (R-3)
- **SC-4** — Given *queue source* output with a next item, the
  *snapshot* contains that item's title and artist. (R-4)
- **SC-5** — Given *queue source* failure (non-zero exit, timeout,
  malformed output, or "operation not permitted") or an empty next item,
  the *snapshot* marks the *upcoming song* unavailable and keeps the
  *current song* from the supported route. (R-5)
- **SC-6** — With the *queue source* failing, no code path produces an
  *upcoming song*; the snapshot builder has no playlist-order input.
  (R-6)
- **SC-7** — Given Music not running, or player state stopped, the
  *snapshot* is "not playing" and carries no song fields. (R-7)
- **SC-8** — Paused and playing *snapshots* produce distinguishable
  entries. (R-8)
- **SC-9** — The *host app* is an agent (no Dock icon or window at
  launch), registers as a login item, and exposes a Quit command. (R-9)
- **SC-10** — The only outbound request the app can make is an HTTPS
  GET to an artwork URL taken from Music's own metadata; requests to
  any other host are rejected by the artwork fetcher. (R-10)
- **SC-11** — The widget layout places the song text and controls in a
  layer above the artwork background; no layout variant puts them in a
  separate region beside it. (R-14)
- **SC-12** — Whenever an entry has artwork, the layout includes the
  scrim beneath the text and controls, and the text colour does not
  vary with the artwork. (R-15)
- **SC-13** — Invoking the skip control issues exactly one "next track"
  command to Music. (R-16)
- **SC-14** — Invoking the back control issues exactly one "back track"
  command to Music. (R-17)
- **SC-15** — With the *queue source* failing, every control still
  issues its command. (R-18)
- **SC-16** — A "not playing" entry renders no controls. (R-19)
- **SC-17** — Invoking the play/pause control issues exactly one
  "playpause" command to Music; a playing entry shows the pause icon
  and a paused entry shows the play icon. (R-20)

## Open questions

- [x] Can a widget button command Music directly from the sandboxed
      widget extension, or must it relay through the *host app*?
      **Resolved 2026-11-19:** the relay works; all three controls were
      confirmed against Music by the owner.
- [x] How fast does the desktop widget actually refresh after a track
      change (R-11)? **Measured 2026-11-19:** under one second across 12
      changes (figures in `tasks.md`, task 2). Open remainder: whether
      WidgetKit throttles reloads over a long listening day.
- [ ] Does the *queue source* return a correct next item under shuffle,
      for local-library playlists, and for radio/Autoplay? The spike
      only covered a streamed playlist with shuffle off.

## Out of scope (for now)

- Medium or extra-large layouts.
- A second upcoming song or a short queue list.

## Traceability

Built up during implementation; complete before `Implemented`.

| Criterion | Requirement(s) | Verified by (test) |
|---|---|---|
| SC-1 | R-1 | `NowPlayingCoreTests/SnapshotBuilderTests.swift::supportedFamilies` |
| SC-2 | R-2 | `NowPlayingCoreTests/SnapshotBuilderTests.swift::currentSongFields` |
| SC-3 | R-3 | `NowPlayingCoreTests/SnapshotBuilderTests.swift::artworkOrPlaceholder` |
| SC-4 | R-4 | `NowPlayingCoreTests/SnapshotBuilderTests.swift::upcomingFromQueue` |
| SC-5 | R-5 | `NowPlayingCoreTests/SnapshotBuilderTests.swift::queueFailureFallsBack`, `…::queueOutOfStepWithCurrentSong` |
| SC-6 | R-6 | `NowPlayingCoreTests/SnapshotBuilderTests.swift::noInferenceWithoutQueue` |
| SC-7 | R-7 | `NowPlayingCoreTests/SnapshotBuilderTests.swift::notPlaying` |
| SC-8 | R-8 | `NowPlayingCoreTests/SnapshotBuilderTests.swift::pausedVersusPlaying` |
| SC-9 | R-9 | `NowPlayingCoreTests/HostAppPolicyTests.swift::hostAppIsAnAgent`, `…::installedCopyRegisters`, `…::developmentBuildDoesNotRegister`, `…::menuHasQuit` |
| SC-10 | R-10 | `NowPlayingCoreTests/ArtworkURLPolicyTests.swift::approvesMusicArtwork`, `…::rejectsEverythingElse`, `…::rejectsMissing` |
| SC-11 | R-14 | `NowPlayingCoreTests/WidgetLayoutTests.swift::overlayAboveBackground` |
| SC-12 | R-15 | `NowPlayingCoreTests/WidgetLayoutTests.swift::scrimAlwaysPresent` |
| SC-13 | R-16 | `NowPlayingCoreTests/WidgetLayoutTests.swift::oneCommandPerPress` |
| SC-14 | R-17 | `NowPlayingCoreTests/WidgetLayoutTests.swift::oneCommandPerPress` |
| SC-15 | R-18 | `NowPlayingCoreTests/WidgetLayoutTests.swift::controlsIndependentOfQueueSource` |
| SC-16 | R-19 | `NowPlayingCoreTests/WidgetLayoutTests.swift::notPlayingHasNoControls` |
| SC-17 | R-20 | `NowPlayingCoreTests/WidgetLayoutTests.swift::oneCommandPerPress`, `…::playPauseIcon` |
