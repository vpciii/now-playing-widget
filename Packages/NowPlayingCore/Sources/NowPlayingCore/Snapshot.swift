import Foundation

public enum PlayerState: String, Codable, Sendable {
    case playing
    case paused
    case notPlaying
}

/// Whether the current song is liked (glossary: rating).
public enum Rating: String, Codable, Sendable {
    case none
    case liked
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
    /// The current song's rating as Music last reported it.
    public var rating: Rating

    public init(state: PlayerState, current: Song?, upcoming: Song?, updatedAt: Date, expectedEndAt: Date?,
                rating: Rating = .none) {
        self.state = state
        self.current = current
        self.upcoming = upcoming
        self.updatedAt = updatedAt
        self.expectedEndAt = expectedEndAt
        self.rating = rating
    }

    /// Snapshot files written before ratings existed have no `rating` key, and
    /// one written while a dislike control existed may hold a value that is no
    /// longer known. Both read as no rating.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        state = try container.decode(PlayerState.self, forKey: .state)
        current = try container.decodeIfPresent(Song.self, forKey: .current)
        upcoming = try container.decodeIfPresent(Song.self, forKey: .upcoming)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
        expectedEndAt = try container.decodeIfPresent(Date.self, forKey: .expectedEndAt)
        rating = (try? container.decodeIfPresent(Rating.self, forKey: .rating)) ?? .none
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
