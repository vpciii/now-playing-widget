import AppIntents
import NowPlayingCore
import SwiftUI
import WidgetKit

@main
struct NowPlayingWidgetBundle: WidgetBundle {
    var body: some Widget {
        NowPlayingWidget()
    }
}

struct NowPlayingWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: WidgetSupport.widgetKind, provider: SnapshotProvider()) { entry in
            NowPlayingView(snapshot: entry.snapshot)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Now Playing")
        .description("The song playing in Music and the one coming up next.")
        .supportedFamilies(WidgetSupport.supportedFamilies)
    }
}

struct SnapshotEntry: TimelineEntry {
    let date: Date
    let snapshot: Snapshot
}

struct SnapshotProvider: TimelineProvider {
    func placeholder(in context: Context) -> SnapshotEntry {
        SnapshotEntry(date: Date(), snapshot: .notPlaying(at: Date()))
    }

    func getSnapshot(in context: Context, completion: @escaping (SnapshotEntry) -> Void) {
        completion(currentEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SnapshotEntry>) -> Void) {
        completion(Timeline(entries: [currentEntry()], policy: .never))
    }

    private func currentEntry() -> SnapshotEntry {
        let now = Date()
        return SnapshotEntry(date: now, snapshot: SharedContainer.readSnapshot() ?? .notPlaying(at: now))
    }
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

/// Task 1 placeholder layout; the overlay layout arrives in task 4.
struct NowPlayingView: View {
    let snapshot: Snapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let song = snapshot.current {
                Text(snapshot.state == .paused ? "Paused" : "Now Playing")
                    .font(.caption).foregroundStyle(.secondary)
                Text(song.title).font(.title3).bold().lineLimit(2)
                Text(song.artist).font(.subheadline).lineLimit(1)
                Spacer()
                Text("Up next").font(.caption).foregroundStyle(.secondary)
                Text(snapshot.upcoming?.title ?? "Up next unavailable").font(.subheadline).lineLimit(1)
                HStack(spacing: 20) {
                    Button(intent: PlayerCommandIntent(.back)) { Image(systemName: "backward.fill") }
                    Button(intent: PlayerCommandIntent(.playpause)) {
                        Image(systemName: snapshot.state == .playing ? "pause.fill" : "play.fill")
                    }
                    Button(intent: PlayerCommandIntent(.next)) { Image(systemName: "forward.fill") }
                }
                .buttonStyle(.plain)
                .font(.title2)
            } else {
                Spacer()
                Label("Not playing", systemImage: "music.note").foregroundStyle(.secondary)
                Spacer()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}
