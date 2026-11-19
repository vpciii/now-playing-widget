import Foundation

/// What the widget draws for a snapshot, decided here so it can be tested
/// without WidgetKit. The view renders exactly this and adds nothing.
///
/// The shape is the layout rule (spec R-14): one background that fills the
/// widget, and at most one overlay drawn on top of it. There is no region
/// beside the artwork.
public struct WidgetLayout: Equatable, Sendable {
    public enum Background: Equatable, Sendable {
        /// The current song's artwork, filling the whole widget.
        case artwork(file: String)
        case placeholder
    }

    public struct Overlay: Equatable, Sendable {
        public var statusLabel: String?
        public var title: String
        public var artist: String
        public var album: String
        public var upNextTitle: String
        public var upNextArtist: String?
        public var upNextArtworkFile: String?
        /// The darkening layer under the text and controls (spec R-15).
        public var showsScrim: Bool
        public var controls: [Control]
        /// The like control: the command for its next press, and a filled icon
        /// when Music reports the song as liked (spec R-22, R-25).
        public var ratingControls: [Control]
        /// Present when the details view is open (spec R-21).
        public var details: Details?
    }

    /// The details view: everything about both songs, never cut short.
    public struct Details: Equatable, Sendable {
        public var current: SongDetails
        /// nil when the upcoming song is unavailable.
        public var upcoming: SongDetails?
        /// nil means no line limit; the view applies exactly this.
        public var lineLimit: Int?
    }

    public struct SongDetails: Equatable, Sendable {
        public var title: String
        public var artist: String
        public var album: String
    }

    public struct Control: Equatable, Sendable {
        public var command: PlayerCommand
        public var systemImage: String
    }

    public static let upNextUnavailableText = "Up next unavailable"
    public static let notPlayingText = "Not playing"

    public var background: Background
    /// nil in the "not playing" state: no song text and no controls.
    public var overlay: Overlay?

    public init(snapshot: Snapshot, detailsExpanded: Bool = false) {
        guard snapshot.state != .notPlaying, let song = snapshot.current else {
            background = .placeholder
            overlay = nil
            return
        }
        background = song.artworkFile.map { .artwork(file: $0) } ?? .placeholder
        overlay = Overlay(
            statusLabel: snapshot.state == .paused ? "Paused" : nil,
            title: song.title,
            artist: song.artist,
            album: song.album,
            upNextTitle: snapshot.upcoming?.title ?? Self.upNextUnavailableText,
            upNextArtist: snapshot.upcoming?.artist,
            upNextArtworkFile: snapshot.upcoming?.artworkFile,
            showsScrim: true,
            controls: [
                Control(command: .back, systemImage: "backward.fill"),
                // The icon shows what a press will do.
                Control(command: .playpause, systemImage: snapshot.state == .playing ? "pause.fill" : "play.fill"),
                Control(command: .next, systemImage: "forward.fill"),
            ],
            ratingControls: [
                snapshot.rating == .liked
                    ? Control(command: .removeLike, systemImage: "hand.thumbsup.fill")
                    : Control(command: .like, systemImage: "hand.thumbsup"),
            ],
            details: detailsExpanded
                ? Details(
                    current: SongDetails(title: song.title, artist: song.artist, album: song.album),
                    upcoming: snapshot.upcoming.map { SongDetails(title: $0.title, artist: $0.artist, album: $0.album) },
                    lineLimit: nil)
                : nil
        )
    }
}

/// Whether the details view is open. The widget remembers which song it was
/// opened for, so it closes by itself when the current song changes.
public enum DetailsState {
    /// Identifies a song for this purpose.
    public static func key(for snapshot: Snapshot?) -> String? {
        guard let snapshot, snapshot.state != .notPlaying, let song = snapshot.current else { return nil }
        return [song.title, song.artist, song.album].joined(separator: "\u{1F}")
    }

    public static func isExpanded(storedKey: String?, snapshot: Snapshot?) -> Bool {
        guard let storedKey, let current = key(for: snapshot) else { return false }
        return storedKey == current
    }

    /// The key to store after a click on the song text: open for the current
    /// song, or nil to close.
    public static func toggled(storedKey: String?, snapshot: Snapshot?) -> String? {
        isExpanded(storedKey: storedKey, snapshot: snapshot) ? nil : key(for: snapshot)
    }
}

/// Something that can send Music a command over the supported route.
public protocol MusicCommanding {
    func send(_ command: PlayerCommand) throws
}

/// Turns a relayed control press into one command to Music. It takes no
/// queue-source input, so the controls work whether or not the queue source
/// does (spec R-18).
public enum CommandDispatcher {
    @discardableResult
    public static func handle(notificationName: String, commander: MusicCommanding) throws -> PlayerCommand? {
        guard let command = PlayerCommand(notificationName: notificationName) else { return nil }
        try commander.send(command)
        return command
    }
}
