import AppKit
import NowPlayingCore

/// The supported route: Music's AppleScript interface. Runs in-process so the
/// Automation consent belongs to this app. Call on the main thread.
struct AppleScriptMusic: MusicCommanding {
    static let musicBundleID = "com.apple.Music"

    enum Failure: Error {
        case script(String)
    }

    /// Asking a non-running Music anything would launch it, so check first.
    var isMusicRunning: Bool {
        !NSRunningApplication.runningApplications(withBundleIdentifier: Self.musicBundleID).isEmpty
    }

    /// The current reading, or nil when Music is not running.
    func read() throws -> MusicReading? {
        guard isMusicRunning else { return nil }
        let result = try run("""
            tell application "Music"
                set s to player state as text
                if s is "stopped" then return {s}
                try
                    set t to current track
                    set fav to false
                    try
                        set fav to favorited of t
                    end try
                    return {s, name of t, artist of t, album of t, duration of t, player position, fav}
                on error
                    return {"stopped"}
                end try
            end tell
            """)
        guard result.numberOfItems >= 1, let state = result.atIndex(1)?.stringValue else {
            throw Failure.script("unexpected reply")
        }
        guard state == "playing" || state == "paused", result.numberOfItems >= 6 else {
            return MusicReading(state: .stopped, title: "", artist: "", album: "")
        }
        return MusicReading(
            state: state == "playing" ? .playing : .paused,
            title: result.atIndex(2)?.stringValue ?? "",
            artist: result.atIndex(3)?.stringValue ?? "",
            album: result.atIndex(4)?.stringValue ?? "",
            duration: result.atIndex(5)?.doubleValue,
            position: result.atIndex(6)?.doubleValue,
            rating: (result.atIndex(7)?.booleanValue ?? false) ? .liked : .none
        )
    }

    /// The current song's artwork in its original format, or nil if it has none.
    func currentArtwork() -> Data? {
        guard isMusicRunning else { return nil }
        let result = try? run("""
            tell application "Music"
                try
                    return raw data of artwork 1 of current track
                on error
                    return missing value
                end try
            end tell
            """)
        guard let data = result?.data, data.count > 64 else { return nil }
        return data
    }

    func send(_ command: PlayerCommand) throws {
        guard isMusicRunning else { return }
        _ = try run("tell application \"Music\"\n\(command.appleScriptCommand)\nend tell")
    }

    private func run(_ source: String) throws -> NSAppleEventDescriptor {
        var error: NSDictionary?
        guard let script = NSAppleScript(source: source) else { throw Failure.script("could not compile") }
        let result = script.executeAndReturnError(&error)
        if let error {
            throw Failure.script((error[NSAppleScript.errorMessage] as? String) ?? "unknown error")
        }
        return result
    }
}
