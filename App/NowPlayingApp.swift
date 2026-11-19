import NowPlayingCore
import ServiceManagement
import SwiftUI
import os

@main
struct NowPlayingApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate

    var body: some Scene {
        MenuBarExtra("Now Playing", systemImage: "music.note") {
            ForEach(HostAppPolicy.menu, id: \.rawValue) { command in
                switch command {
                case .quit:
                    Button(command.title) { NSApplication.shared.terminate(nil) }
                        .keyboardShortcut("q")
                }
            }
        }
    }
}

/// Start-at-login through the system's login item service.
struct MainAppLoginItem: LoginItemRegistering {
    var isRegistered: Bool { SMAppService.mainApp.status == .enabled }
    func register() throws { try SMAppService.mainApp.register() }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let coordinator = NowPlayingCoordinator()

    func applicationDidFinishLaunching(_ notification: Notification) {
        registerLoginItem()
        coordinator.start()
    }

    private func registerLoginItem() {
        let registrar = MainAppLoginItem()
        do {
            let registered = try HostAppPolicy.registerLoginItemIfNeeded(
                bundlePath: Bundle.main.bundlePath, registrar: registrar)
            Log.widget.info("""
                login item: registeredNow=\(registered, privacy: .public) \
                enabled=\(registrar.isRegistered, privacy: .public)
                """)
        } catch {
            Log.widget.error("login item registration failed: \(error.localizedDescription, privacy: .public)")
        }
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
