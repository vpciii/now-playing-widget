import NowPlayingCore
import SwiftUI
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
    private let coordinator = NowPlayingCoordinator()

    func applicationDidFinishLaunching(_ notification: Notification) {
        coordinator.start()
    }

    /// Clicking the widget outside its controls opens this app with a URL;
    /// bring Music forward (spec R-13).
    func application(_ application: NSApplication, open urls: [URL]) {
        guard let music = NSWorkspace.shared.urlForApplication(withBundleIdentifier: AppleScriptMusic.musicBundleID)
        else { return }
        NSWorkspace.shared.openApplication(at: music, configuration: NSWorkspace.OpenConfiguration())
    }

    func applicationWillTerminate(_ notification: Notification) {
        // A quit host app must not leave a song looking live (spec goal 4).
        coordinator.stop()
    }
}

enum Log {
    private static let subsystem = "local.nowplaying.app"
    static let music = Logger(subsystem: subsystem, category: "music")
    static let queue = Logger(subsystem: subsystem, category: "queue")
    static let widget = Logger(subsystem: subsystem, category: "widget")
    static let commands = Logger(subsystem: subsystem, category: "commands")
}
