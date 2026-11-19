import Foundation

/// What the supported route reports about Music right now.
public struct MusicReading: Equatable, Sendable {
    public enum State: Sendable { case playing, paused, stopped }

    public var state: State
    public var title: String
    public var artist: String
    public var album: String
    public var duration: TimeInterval?
    public var position: TimeInterval?

    public init(state: State, title: String, artist: String, album: String,
                duration: TimeInterval? = nil, position: TimeInterval? = nil) {
        self.state = state
        self.title = title
        self.artist = artist
        self.album = album
        self.duration = duration
        self.position = position
    }
}

public struct QueueItem: Codable, Equatable, Sendable {
    public var title: String
    public var artist: String
    public var album: String
    public var artworkURL: String?

    public init(title: String, artist: String, album: String, artworkURL: String? = nil) {
        self.title = title
        self.artist = artist
        self.album = album
        self.artworkURL = artworkURL
    }
}

/// The outcome of asking the queue source. Item 0 is the current song.
public enum QueueResult: Equatable, Sendable {
    case items([QueueItem])
    case failed(reason: String)
}

public enum SnapshotBuilder {
    /// Merges the supported route and the queue source into a snapshot.
    ///
    /// The upcoming song comes only from `queue`. There is deliberately no
    /// playlist or album-order input: when the queue source cannot name the
    /// next song, the upcoming song is unavailable (spec R-5, R-6).
    ///
    /// - Parameter music: nil when Music is not running.
    public static func build(
        music: MusicReading?,
        queue: QueueResult,
        now: Date,
        currentArtworkFile: String? = nil,
        upcomingArtworkFile: String? = nil
    ) -> Snapshot {
        guard let music, music.state != .stopped else {
            return .notPlaying(at: now)
        }

        let current = Song(title: music.title, artist: music.artist, album: music.album,
                           artworkFile: currentArtworkFile)

        var expectedEndAt: Date?
        if music.state == .playing, let duration = music.duration, let position = music.position {
            expectedEndAt = now.addingTimeInterval(max(0, duration - position))
        }

        return Snapshot(
            state: music.state == .playing ? .playing : .paused,
            current: current,
            upcoming: upcomingSong(after: music, in: queue, artworkFile: upcomingArtworkFile),
            updatedAt: now,
            expectedEndAt: expectedEndAt
        )
    }

    /// The queue item to show as upcoming, or nil. The queue is trusted only
    /// when its first item is the song the supported route says is current;
    /// otherwise the two readings straddle a track change and item 1 could be
    /// the wrong song.
    public static func upcomingItem(after music: MusicReading, in queue: QueueResult) -> QueueItem? {
        guard case .items(let items) = queue, items.count >= 2 else { return nil }
        guard items[0].title == music.title else { return nil }
        let next = items[1]
        guard !next.title.isEmpty else { return nil }
        return next
    }

    private static func upcomingSong(after music: MusicReading, in queue: QueueResult, artworkFile: String?) -> Song? {
        guard let next = upcomingItem(after: music, in: queue) else { return nil }
        return Song(title: next.title, artist: next.artist, album: next.album, artworkFile: artworkFile)
    }
}

/// When to show "not playing".
public enum NotPlayingTiming: Equatable, Sendable {
    case publishNow
    /// Publish after `delay` unless a newer reading has arrived by then.
    case publishIfStillCurrent(after: TimeInterval)

    /// How long a "stopped" reading must stand before the widget shows it.
    public static let settleDelay: TimeInterval = 1.0

    /// Music reports "stopped" for a fraction of a second while it switches to
    /// a different playlist, then "playing" again. Showing that would flash
    /// "Not playing" on the widget and spend reloads, so a stopped reading
    /// waits to see whether it lasts. Music not running at all is not
    /// transient and is shown at once.
    public static func decide(for reading: MusicReading?) -> NotPlayingTiming {
        guard let reading else { return .publishNow }
        return reading.state == .stopped ? .publishIfStillCurrent(after: settleDelay) : .publishNow
    }
}
