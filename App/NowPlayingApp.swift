import NowPlayingCore
import ServiceManagement
import SwiftUI
import os

@main
struct NowPlayingApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate

    var body: some Scene {
        MenuBarExtra {
            ForEach(HostAppPolicy.menu, id: \.rawValue) { command in
                switch command {
                case .quit:
                    Button(command.title) { NSApplication.shared.terminate(nil) }
                        .keyboardShortcut("q")
                }
            }
        } label: {
            Image(nsImage: MenuBarIcon.image)
                .accessibilityLabel("Now Playing")
        }
    }
}

/// The menu bar icon: a pair of beamed notes. There is no two-note system
/// symbol, so it is drawn from the "♫" character as a template image, which
/// the menu bar tints for light and dark like any other icon.
enum MenuBarIcon {
    /// Menu bar icons are about 18 points square; the notes fill most of it.
    static let side: CGFloat = 18
    static let inkHeight: CGFloat = 14

    static let image: NSImage = {
        let image = NSImage(size: NSSize(width: side, height: side), flipped: false) { rect in
            draw(in: rect)
            return true
        }
        image.isTemplate = true
        return image
    }()

    /// Draws the notes centred in `rect`, sized from the glyph's own outline
    /// so nothing depends on the font's line metrics.
    static func draw(in rect: CGRect) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        func line(fontSize: CGFloat) -> CTLine {
            let font = NSFont.systemFont(ofSize: fontSize, weight: .medium)
            return CTLineCreateWithAttributedString(NSAttributedString(
                string: "♫", attributes: [.font: font, .foregroundColor: NSColor.black]))
        }
        let reference = CTLineGetBoundsWithOptions(line(fontSize: 100), .useGlyphPathBounds)
        guard reference.height > 0 else { return }
        let wanted = inkHeight * rect.height / side
        let fitted = line(fontSize: 100 * wanted / reference.height)
        let ink = CTLineGetBoundsWithOptions(fitted, .useGlyphPathBounds)
        context.textPosition = CGPoint(x: rect.midX - ink.midX, y: rect.midY - ink.midY)
        CTLineDraw(fitted, context)
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
