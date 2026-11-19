import NowPlayingCore
import SwiftUI
import WidgetKit
import os

@main
struct NowPlayingApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate

    var body: some Scene {
        MenuBarExtra("Now Playing", systemImage: "music.note") {
            Button("Quit Now Playing") { NSApplication.shared.terminate(nil) }
                .keyboardShortcut("q")
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let relay = CommandRelay()

    func applicationDidFinishLaunching(_ notification: Notification) {
        relay.start { command in
            Log.commands.info("relayed command: \(command.rawValue, privacy: .public)")
        }
        publish(.notPlaying(at: Date()))
    }

    func applicationWillTerminate(_ notification: Notification) {
        // A quit host app must not leave a song looking live (spec goal 4).
        publish(.notPlaying(at: Date()))
    }

    private func publish(_ snapshot: Snapshot) {
        do {
            try SharedContainer.write(snapshot)
            WidgetCenter.shared.reloadTimelines(ofKind: WidgetSupport.widgetKind)
            Log.widget.info("published snapshot: \(snapshot.state.rawValue, privacy: .public)")
        } catch {
            Log.widget.error("could not write snapshot: \(error.localizedDescription, privacy: .public)")
        }
    }
}

enum Log {
    private static let subsystem = "local.nowplaying.app"
    static let music = Logger(subsystem: subsystem, category: "music")
    static let queue = Logger(subsystem: subsystem, category: "queue")
    static let widget = Logger(subsystem: subsystem, category: "widget")
    static let commands = Logger(subsystem: subsystem, category: "commands")
}
