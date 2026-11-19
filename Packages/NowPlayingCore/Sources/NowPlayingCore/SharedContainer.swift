import Foundation

/// The folder the host app writes and the widget reads:
/// `~/Library/Application Support/NowPlaying`.
///
/// Not an App Group: that entitlement needs a provisioning profile, and this
/// Mac has no developer team. The sandboxed widget reaches the folder through
/// a read-only sandbox exception in its entitlements instead.
public enum SharedContainer {
    public static let homeRelativePath = "Library/Application Support/NowPlaying"

    public static func url() -> URL? {
        // NSHomeDirectory() is the sandbox container inside the widget, so ask
        // the user database for the real home folder.
        guard let entry = getpwuid(getuid()), let home = entry.pointee.pw_dir else { return nil }
        return URL(fileURLWithPath: String(cString: home), isDirectory: true)
            .appendingPathComponent(homeRelativePath, isDirectory: true)
    }

    public static func readSnapshot() -> Snapshot? {
        guard let file = url()?.appendingPathComponent(Snapshot.fileName),
              let data = try? Data(contentsOf: file) else { return nil }
        return try? Snapshot.decode(data)
    }

    public static func write(_ snapshot: Snapshot) throws {
        guard let directory = url() else { throw CocoaError(.fileNoSuchFile) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try snapshot.encoded().write(to: directory.appendingPathComponent(Snapshot.fileName), options: .atomic)
    }
}
