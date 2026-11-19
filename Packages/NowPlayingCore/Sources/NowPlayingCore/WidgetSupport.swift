import Foundation
import WidgetKit

public enum WidgetSupport {
    /// The widget is offered in the large size only (spec R-1).
    public static let supportedFamilies: [WidgetFamily] = [.systemLarge]

    public static let widgetKind = "NowPlayingWidget"
}

/// A control the widget can ask Music to perform, relayed through the host
/// app as a distributed notification with no payload.
public enum PlayerCommand: String, CaseIterable, Sendable {
    case next
    case back
    case playpause
    case like
    case removeLike

    public static let notificationPrefix = "local.nowplaying.command."

    public var notificationName: String { Self.notificationPrefix + rawValue }

    public init?(notificationName: String) {
        guard notificationName.hasPrefix(Self.notificationPrefix) else { return nil }
        self.init(rawValue: String(notificationName.dropFirst(Self.notificationPrefix.count)))
    }

    /// The statement, inside a `tell application "Music"` block, that carries
    /// this command out.
    public var appleScriptCommand: String {
        switch self {
        case .next: "next track"
        case .back: "back track"
        case .playpause: "playpause"
        case .like: "set favorited of current track to true"
        case .removeLike: "set favorited of current track to false"
        }
    }

    /// Rating commands change nothing Music announces, so the host app must
    /// read Music again afterwards to show what it now reports (spec R-25).
    public var needsFreshReading: Bool {
        switch self {
        case .like, .removeLike: true
        case .next, .back, .playpause: false
        }
    }

    /// When, after the command, to read Music again. Music reports a removed
    /// rating at once but a new one only a couple of seconds later (measured
    /// 2026-11-19: `favorited` read true 2.5 s after being set), so there is
    /// an early reading and a late one.
    public var freshReadingDelays: [TimeInterval] {
        needsFreshReading ? [0.3, 3.5] : []
    }
}
