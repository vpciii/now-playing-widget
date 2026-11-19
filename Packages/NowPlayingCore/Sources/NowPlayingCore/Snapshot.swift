import Foundation

public enum PlayerState: String, Codable, Sendable {
    case playing
    case paused
    case notPlaying
}

/// A song as the widget shows it. `artworkFile` is a file name inside the
/// shared container, or nil when there is no artwork.
public struct Song: Codable, Equatable, Sendable {
    public var title: String
    public var artist: String
    public var album: String
    public var artworkFile: String?

    public init(title: String, artist: String, album: String, artworkFile: String? = nil) {
        self.title = title
        self.artist = artist
        self.album = album
        self.artworkFile = artworkFile
    }
}

/// The record the host app writes for the widget (glossary: snapshot).
public struct Snapshot: Codable, Equatable, Sendable {
    public var state: PlayerState
    /// The current song; nil when `state` is `.notPlaying`.
    public var current: Song?
    /// The upcoming song; nil means "up next unavailable".
    public var upcoming: Song?
    public var updatedAt: Date
    /// When the current song is expected to finish, if it is playing.
    public var expectedEndAt: Date?

    public init(state: PlayerState, current: Song?, upcoming: Song?, updatedAt: Date, expectedEndAt: Date?) {
        self.state = state
        self.current = current
        self.upcoming = upcoming
        self.updatedAt = updatedAt
        self.expectedEndAt = expectedEndAt
    }

    public static func notPlaying(at date: Date) -> Snapshot {
        Snapshot(state: .notPlaying, current: nil, upcoming: nil, updatedAt: date, expectedEndAt: nil)
    }

    public static let fileName = "snapshot.json"

    public func encoded() throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(self)
    }

    public static func decode(_ data: Data) throws -> Snapshot {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(Snapshot.self, from: data)
    }
}
