# ADR 0001: Private MediaRemote, via an Apple-signed interpreter, for the upcoming song

- **Status:** Accepted
- **Date:** 2026-11-19
- **Deciders:** repo owner

## Context

The widget must show the upcoming song (spec `now-playing-widget`, R-4).
A spike on 2026-11-19 (macOS 27.2.1, Xcode 27.2, Music playing a streamed
97-track playlist, shuffle off) found:

- Music's AppleScript dictionary has no queue or "Playing Next" term.
  For streamed playback `current playlist` errors and tracks report
  track number 0, so the next track cannot even be inferred.
- MusicKit on macOS cannot read what the Music app is playing.
- The private `MediaRemote` framework returns the real queue:
  `MRNowPlayingController` configured with an `MRPlaybackQueueRequest`
  for range `{0, 4}` returned the current item plus the next three, with
  titles, artists, albums and artwork URLs.
- Since macOS 15.4 Apple gates MediaRemote by the caller's signature.
  The identical code returned the queue when run by Xcode's Apple-signed
  `swift` interpreter (about 0.2 s per call) and failed with
  `kMRMediaRemoteFrameworkErrorDomain Code=3 "Operation not permitted"`
  when compiled as a normal ad hoc-signed binary.

The owner chose on 2026-11-19 to use the private route, for a personal
widget on their own Mac.

## Decision

We will fetch the upcoming song from private MediaRemote by having the
host app run a small Swift script through Xcode's `swift` interpreter,
and we will use the supported route (AppleScript + the
`com.apple.Music.playerInfo` notification) for everything else. A queue
failure degrades to "up next unavailable"; it never breaks the current
song.

## Alternatives considered

- **Supported route only** — robust and sanctioned, but shows no
  upcoming song for streamed playback, which is the owner's main use.
  Kept as the fallback rather than the design.
- **Infer the next track from playlist or album order** — fails outright
  for streamed playlists and is wrong under shuffle or a manually edited
  queue. Rejected; the spec forbids guessing (R-6).
- **Load our code into another Apple-signed host such as `/usr/bin/perl`**
  — avoids the Xcode dependency. Not tested: the attempt was blocked by
  the agent's permission policy as working around an OS restriction, and
  it is the same kind of sidestep with a less obvious dependency.
- **Read Music's Playing Next panel through Accessibility** — needs the
  panel open and Accessibility permission, and breaks on UI changes.
- **Call MediaRemote from the host app directly** — blocked by the
  signature gate, as measured.

## Consequences

- The widget can show the true upcoming song, including for streams.
- We deliberately sidestep a restriction Apple added. Apple can close it
  in any macOS or Xcode update without notice; the class and selector
  names are undocumented and can change too.
- Xcode (or its command-line toolchain providing `swift`) must stay
  installed. Without it only the fallback works.
- The app cannot be sandboxed (it spawns a process) and can never be
  distributed through the App Store. Distribution is a non-goal.
- The script runs with the owner's privileges on every track change. It
  ships inside the app bundle and takes no external input.
- Queue behaviour under shuffle, local playlists and radio is unverified.

## Adoption impact

None beyond this project. The queue source sits behind one interface so
that removing or replacing it touches one component.

## References

- `specs/now-playing-widget/spec.md`
- `docs/glossary.md` — *queue source*, *supported route*
