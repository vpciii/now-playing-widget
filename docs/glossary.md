# Glossary

- **Current song** — the track Music is playing or has paused on.
- **Upcoming song** — the single track Music will play next, as reported
  by Music's real playback queue. Never an inference from playlist order.
- **Host app** — the background macOS app that reads Music's state and
  feeds the widget. It contains the widget extension.
- **Widget** — the WidgetKit extension that renders the latest snapshot.
  It reads no live data itself.
- **Snapshot** — the record the host app writes for the widget: player
  state, current song, upcoming song (or "unavailable"), and artwork.
- **Supported route** — Music's AppleScript interface plus its
  `com.apple.Music.playerInfo` distributed notification.
- **Queue source** — the private MediaRemote query that returns the
  playback queue (ADR-0001).
- **Details view** — the widget's expanded state, opened by clicking the
  song text: full title, artist and album of the current and upcoming
  songs.
