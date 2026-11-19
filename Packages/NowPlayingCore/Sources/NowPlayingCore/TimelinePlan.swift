import Foundation

/// The dated snapshots the widget should show for one stored snapshot.
public enum TimelinePlan {
    /// How long past a song's expected end the widget keeps showing it before
    /// assuming the host app has stopped updating.
    public static let staleMargin: TimeInterval = 30

    public struct Entry: Equatable, Sendable {
        public var date: Date
        public var snapshot: Snapshot
    }

    /// The stored snapshot now, followed by a "not playing" entry once a
    /// playing song is well past its expected end. The host app replaces the
    /// snapshot on every track change, so the second entry is only reached
    /// when the host app has quit or crashed: a finished song must not keep
    /// looking live (spec goal 4).
    public static func entries(for snapshot: Snapshot?, now: Date) -> [Entry] {
        guard let snapshot else {
            return [Entry(date: now, snapshot: .notPlaying(at: now))]
        }
        guard snapshot.state == .playing, let end = snapshot.expectedEndAt else {
            return [Entry(date: now, snapshot: snapshot)]
        }
        let staleAt = end.addingTimeInterval(staleMargin)
        if staleAt <= now {
            return [Entry(date: now, snapshot: .notPlaying(at: now))]
        }
        return [
            Entry(date: now, snapshot: snapshot),
            Entry(date: staleAt, snapshot: .notPlaying(at: staleAt)),
        ]
    }
}

public enum ArtworkFile {
    public static let current = "current-artwork.jpg"
    public static let upcoming = "upcoming-artwork.jpg"
    /// Longest edge, in pixels, of artwork stored for the widget.
    public static let maxPixelSize = 600
}
