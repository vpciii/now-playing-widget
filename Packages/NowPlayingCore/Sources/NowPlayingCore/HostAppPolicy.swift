import Foundation

/// Something that can make the host app start at login.
public protocol LoginItemRegistering {
    var isRegistered: Bool { get }
    func register() throws
}

/// How the host app behaves as a background agent (spec R-9).
public enum HostAppPolicy {
    public enum MenuCommand: String, CaseIterable, Sendable {
        case quit

        public var title: String {
            switch self {
            case .quit: "Quit Now Playing"
            }
        }
    }

    /// The menu bar item's commands. The owner must always be able to quit.
    public static let menu: [MenuCommand] = [.quit]

    public static let installDirectory = "/Applications/"

    /// Only an installed copy starts at login. A development build lives in a
    /// folder that is replaced on every rebuild and must not be registered.
    public static func shouldRegisterLoginItem(bundlePath: String) -> Bool {
        bundlePath.hasPrefix(installDirectory)
    }

    /// Registers the app to start at login when it is installed and not yet
    /// registered. Returns true if it registered now.
    @discardableResult
    public static func registerLoginItemIfNeeded(bundlePath: String, registrar: LoginItemRegistering) throws -> Bool {
        guard shouldRegisterLoginItem(bundlePath: bundlePath), !registrar.isRegistered else { return false }
        try registrar.register()
        return true
    }
}
