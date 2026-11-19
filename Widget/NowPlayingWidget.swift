import AppIntents
import NowPlayingCore
import SwiftUI
import WidgetKit
import os

@main
struct NowPlayingWidgetBundle: WidgetBundle {
    var body: some Widget {
        NowPlayingWidget()
    }
}

struct NowPlayingWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: WidgetSupport.widgetKind, provider: SnapshotProvider()) { entry in
            NowPlayingView(layout: WidgetLayout(snapshot: entry.snapshot, detailsExpanded: entry.detailsExpanded))
                .containerBackground(for: .widget) { Color.black }
                .widgetURL(URL(string: "nowplaying://open-music"))
        }
        .configurationDisplayName("Now Playing")
        .description("The song playing in Music and the one coming up next.")
        .supportedFamilies(WidgetSupport.supportedFamilies)
        // The artwork fills the whole widget, edge to edge.
        .contentMarginsDisabled()
        .containerBackgroundRemovable(false)
    }
}

struct SnapshotEntry: TimelineEntry {
    let date: Date
    let snapshot: Snapshot
    var detailsExpanded = false

    init(_ entry: TimelinePlan.Entry) {
        date = entry.date
        snapshot = entry.snapshot
        detailsExpanded = DetailsStore.isExpanded(for: entry.snapshot)
    }
}

/// Remembers, inside the widget extension, which song the details view was
/// opened for. WidgetKit reloads the timeline after an intent runs, so a
/// click shows up without involving the host app.
enum DetailsStore {
    private static let key = "detailsExpandedForSong"

    static func isExpanded(for snapshot: Snapshot?) -> Bool {
        DetailsState.isExpanded(storedKey: UserDefaults.standard.string(forKey: key), snapshot: snapshot)
    }

    static func toggle() {
        let defaults = UserDefaults.standard
        let next = DetailsState.toggled(storedKey: defaults.string(forKey: key),
                                        snapshot: SharedContainer.readSnapshot())
        defaults.set(next, forKey: key)
    }
}

struct ToggleDetailsIntent: AppIntent {
    static var title: LocalizedStringResource = "Show Song Details"
    static var isDiscoverable = false

    func perform() async throws -> some IntentResult {
        DetailsStore.toggle()
        return .result()
    }
}

struct SnapshotProvider: TimelineProvider {
    func placeholder(in context: Context) -> SnapshotEntry {
        SnapshotEntry(TimelinePlan.Entry(date: Date(), snapshot: .notPlaying(at: Date())))
    }

    func getSnapshot(in context: Context, completion: @escaping (SnapshotEntry) -> Void) {
        completion(currentEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SnapshotEntry>) -> Void) {
        let entries = TimelinePlan.entries(for: SharedContainer.readSnapshot(), now: Date())
        WidgetLog.timeline.info("""
            timeline requested: \(entries[0].snapshot.state.rawValue, privacy: .public) \
            "\(entries[0].snapshot.current?.title ?? "-", privacy: .public)"
            """)
        completion(Timeline(entries: entries.map(SnapshotEntry.init), policy: .never))
    }

    private func currentEntry() -> SnapshotEntry {
        SnapshotEntry(TimelinePlan.entries(for: SharedContainer.readSnapshot(), now: Date())[0])
    }
}

enum WidgetLog {
    static let timeline = Logger(subsystem: "local.nowplaying.app.widget", category: "timeline")
}

/// Posts the command for the host app to carry out. The widget never talks
/// to Music itself.
struct PlayerCommandIntent: AppIntent {
    static var title: LocalizedStringResource = "Control Music"
    static var isDiscoverable = false

    @Parameter(title: "Command") var command: String

    init() {}

    init(_ command: PlayerCommand) {
        self.command = command.rawValue
    }

    func perform() async throws -> some IntentResult {
        if let command = PlayerCommand(rawValue: command) {
            DistributedNotificationCenter.default().postNotificationName(
                Notification.Name(command.notificationName), object: nil, userInfo: nil, deliverImmediately: true)
        }
        return .result()
    }
}

/// Draws a `WidgetLayout`: a background filling the widget and, when a song
/// is playing or paused, one overlay on top of it.
struct NowPlayingView: View {
    let layout: WidgetLayout

    /// macOS draws the widget in `.accented` mode when the desktop mutes it
    /// (observed in the logs on macOS 27.2), which washes it out towards white.
    @Environment(\.widgetRenderingMode) private var renderingMode
    private var isMuted: Bool { renderingMode != .fullColor }

    var body: some View {
        ZStack {
            background
            if let overlay = layout.overlay {
                if overlay.showsScrim { scrim }
                overlayContent(overlay)
            } else {
                Label(WidgetLayout.notPlayingText, systemImage: "music.note")
                    .font(.headline)
                    .foregroundStyle(.white.opacity(0.7))
            }
        }
    }

    @ViewBuilder
    private var background: some View {
        if case .artwork(let file) = layout.background, let image = Self.image(named: file) {
            Color.clear.overlay {
                Image(nsImage: image)
                    .resizable()
                    // Keep the artwork an image when the desktop mutes widgets;
                    // by default it would be flattened to a tinted shape.
                    .widgetAccentedRenderingMode(.fullColor)
                    .scaledToFill()
            }
            .clipped()
        } else {
            Self.gradient([(0, 0.28, 1), (1, 0.12, 1)])
                .overlay {
                    if layout.overlay != nil {
                        Image(systemName: "music.note")
                            .font(.system(size: 72))
                            .foregroundStyle(.white.opacity(0.18))
                            .offset(y: -40)
                    }
                }
        }
    }

    /// Darkens the lower part of the artwork so light text stays readable on
    /// any cover (spec R-15).
    private var scrim: some View {
        if layout.overlay?.details != nil {
            // The details view covers most of the widget with text.
            Self.gradient([(0, 0, isMuted ? 0.9 : 0.72), (1, 0, isMuted ? 0.97 : 0.9)])
        } else if isMuted {
            // The wash lifts every dark tone, so start from much darker: veil
            // the whole cover and put a near-solid band behind the text.
            Self.gradient([(0, 0, 0.35), (0.38, 0, 0.45), (0.58, 0, 0.92), (1, 0, 0.97)])
        } else {
            Self.gradient([(0.25, 0, 0), (0.55, 0, 0.55), (1, 0, 0.88)])
        }
    }

    /// A top-to-bottom gradient drawn as a full-colour image.
    ///
    /// When the desktop mutes widgets, macOS repaints every shape and text in
    /// one tint, so a black SwiftUI gradient turns as light as the text on top
    /// of it and the text disappears. Images marked full colour are left
    /// alone, so the scrim is an image.
    private static func gradient(_ stops: [(location: CGFloat, white: CGFloat, alpha: CGFloat)]) -> some View {
        let height = 256
        let space = CGColorSpaceCreateDeviceRGB()
        var image: CGImage?
        if let context = CGContext(data: nil, width: 1, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                                   space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue),
           let cgGradient = CGGradient(
               colorsSpace: space,
               colors: stops.map { CGColor(red: $0.white, green: $0.white, blue: $0.white, alpha: $0.alpha) } as CFArray,
               locations: stops.map(\.location)) {
            // Core Graphics' origin is bottom-left; location 0 is the top.
            context.drawLinearGradient(cgGradient, start: CGPoint(x: 0, y: height), end: CGPoint(x: 0, y: 0),
                                       options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
            image = context.makeImage()
        }
        return Color.clear.overlay {
            if let image {
                Image(decorative: image, scale: 1)
                    .resizable()
                    .widgetAccentedRenderingMode(.fullColor)
            }
        }
    }

    private func overlayContent(_ overlay: WidgetLayout.Overlay) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Spacer(minLength: 0)
            // Clicking the song text opens or closes the details view (R-21).
            Button(intent: ToggleDetailsIntent()) {
                Group {
                    if let details = overlay.details {
                        detailsText(details, status: overlay.statusLabel)
                    } else {
                        summaryText(overlay)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            HStack(alignment: .center, spacing: 8) {
                if let file = overlay.upNextArtworkFile, let image = Self.image(named: file) {
                    Image(nsImage: image).resizable().widgetAccentedRenderingMode(.fullColor)
                        .frame(width: 28, height: 28).clipShape(RoundedRectangle(cornerRadius: 4))
                }
                if overlay.details == nil {
                    Button(intent: ToggleDetailsIntent()) {
                        VStack(alignment: .leading, spacing: 0) {
                            Text("UP NEXT").font(.caption2.weight(.semibold)).opacity(0.7)
                            Text(upNextLine(overlay)).font(.caption).lineLimit(1)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
                Spacer(minLength: 8)
                HStack(spacing: 18) {
                    ForEach(overlay.controls, id: \.command.rawValue) { control in
                        Button(intent: PlayerCommandIntent(control.command)) {
                            Image(systemName: control.systemImage)
                                .font(.title3)
                                .frame(width: 26, height: 26)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        // A fixed light colour: it never varies with the artwork (spec R-15).
        .foregroundStyle(.white)
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
    }

    private func summaryText(_ overlay: WidgetLayout.Overlay) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            if let status = overlay.statusLabel {
                Text(status.uppercased()).font(.caption2.weight(.semibold)).opacity(0.75)
            }
            Text(overlay.title).font(.title3.weight(.bold)).lineLimit(2)
            Text(overlay.artist).font(.subheadline).lineLimit(1).opacity(0.9)
        }
    }

    /// Both songs in full. `lineLimit` comes from the layout (nil: unlimited);
    /// text shrinks a little before anything would be clipped by the widget.
    private func detailsText(_ details: WidgetLayout.Details, status: String?) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            songDetails(heading: status.map { "Now playing · \($0)" } ?? "Now playing", details.current)
            if let upcoming = details.upcoming {
                songDetails(heading: "Up next", upcoming)
            } else {
                VStack(alignment: .leading, spacing: 1) {
                    Text("UP NEXT").font(.caption2.weight(.semibold)).opacity(0.7)
                    Text(WidgetLayout.upNextUnavailableText).font(.subheadline)
                }
            }
        }
        .lineLimit(details.lineLimit)
        .minimumScaleFactor(0.7)
        .multilineTextAlignment(.leading)
    }

    private func songDetails(heading: String, _ song: WidgetLayout.SongDetails) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(heading.uppercased()).font(.caption2.weight(.semibold)).opacity(0.7)
            Text(song.title).font(.subheadline.weight(.bold))
            Text(song.artist).font(.caption).opacity(0.9)
            if !song.album.isEmpty {
                Text(song.album).font(.caption).opacity(0.75)
            }
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    private func upNextLine(_ overlay: WidgetLayout.Overlay) -> String {
        guard let artist = overlay.upNextArtist, !artist.isEmpty else { return overlay.upNextTitle }
        return "\(overlay.upNextTitle) — \(artist)"
    }

    private static func image(named file: String) -> NSImage? {
        guard let url = SharedContainer.url()?.appendingPathComponent(file) else { return nil }
        return NSImage(contentsOf: url)
    }
}
