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

    public static let notificationPrefix = "local.nowplaying.command."

    public var notificationName: String { Self.notificationPrefix + rawValue }

    public init?(notificationName: String) {
        guard notificationName.hasPrefix(Self.notificationPrefix) else { return nil }
        self.init(rawValue: String(notificationName.dropFirst(Self.notificationPrefix.count)))
    }

    /// The Music AppleScript command this maps to.
    public var appleScriptCommand: String {
        switch self {
        case .next: "next track"
        case .back: "back track"
        case .playpause: "playpause"
        }
    }
}
