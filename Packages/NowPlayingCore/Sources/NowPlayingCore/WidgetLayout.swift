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

    public init(snapshot: Snapshot) {
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
            ]
        )
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
