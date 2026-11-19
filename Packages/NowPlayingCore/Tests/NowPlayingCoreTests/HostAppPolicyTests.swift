import Foundation
import Testing
@testable import NowPlayingCore

private final class FakeRegistrar: LoginItemRegistering {
    var isRegistered: Bool
    var registerCalls = 0
    init(isRegistered: Bool) { self.isRegistered = isRegistered }
    func register() throws {
        registerCalls += 1
        isRegistered = true
    }
}

/// The repository root, found from this file's location.
private let repositoryRoot = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    .deletingLastPathComponent().deletingLastPathComponent()

@Test("SC-9: the host app is declared as an agent, so it has no Dock icon or window at launch")
func hostAppIsAnAgent() throws {
    let data = try Data(contentsOf: repositoryRoot.appendingPathComponent("App/Info.plist"))
    let plist = try #require(PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any])
    #expect(plist["LSUIElement"] as? Bool == true)
}

@Test("SC-9: an installed copy registers as a login item once")
func installedCopyRegisters() throws {
    let registrar = FakeRegistrar(isRegistered: false)
    let path = "/Applications/NowPlaying.app"
    #expect(try HostAppPolicy.registerLoginItemIfNeeded(bundlePath: path, registrar: registrar) == true)
    #expect(try HostAppPolicy.registerLoginItemIfNeeded(bundlePath: path, registrar: registrar) == false)
    #expect(registrar.registerCalls == 1)
}

@Test("SC-9: a development build does not register as a login item")
func developmentBuildDoesNotRegister() throws {
    let registrar = FakeRegistrar(isRegistered: false)
    let path = "/Users/someone/project/build/Build/Products/Debug/NowPlaying.app"
    #expect(try HostAppPolicy.registerLoginItemIfNeeded(bundlePath: path, registrar: registrar) == false)
    #expect(registrar.registerCalls == 0)
}

@Test("SC-9: the menu bar item exposes a Quit command")
func menuHasQuit() {
    #expect(HostAppPolicy.menu.contains(.quit))
    #expect(HostAppPolicy.MenuCommand.quit.title == "Quit Now Playing")
}
