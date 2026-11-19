import Foundation
import Testing
@testable import NowPlayingCore

private let now = Date(timeIntervalSince1970: 1_800_000_000)

private func snapshot(_ state: PlayerState, artwork: String? = ArtworkFile.current, upcoming: Song? = nil) -> Snapshot {
    Snapshot(state: state,
             current: state == .notPlaying ? nil : Song(title: "Tetris", artist: "LPO", album: "Greatest", artworkFile: artwork),
             upcoming: upcoming, updatedAt: now, expectedEndAt: nil)
}

private final class CountingCommander: MusicCommanding {
    var sent: [PlayerCommand] = []
    func send(_ command: PlayerCommand) throws { sent.append(command) }
}

@Test("SC-11: song text and controls sit in one overlay above a background that fills the widget")
func overlayAboveBackground() {
    let layout = WidgetLayout(snapshot: snapshot(.playing))
    #expect(layout.background == .artwork(file: ArtworkFile.current))
    #expect(layout.overlay?.title == "Tetris")
    #expect(layout.overlay?.artist == "LPO")
    #expect(layout.overlay?.controls.isEmpty == false)
}

@Test("SC-12: the scrim is present under the overlay whenever there is artwork, and without it",
      arguments: [PlayerState.playing, .paused], [ArtworkFile.current, nil] as [String?])
func scrimAlwaysPresent(state: PlayerState, artwork: String?) {
    #expect(WidgetLayout(snapshot: snapshot(state, artwork: artwork)).overlay?.showsScrim == true)
}

@Test("SC-13, SC-14, SC-17: each control press issues exactly one matching command",
      arguments: [(PlayerCommand.next, "next track"), (.back, "back track"), (.playpause, "playpause")])
func oneCommandPerPress(command: PlayerCommand, script: String) throws {
    let commander = CountingCommander()
    try CommandDispatcher.handle(notificationName: command.notificationName, commander: commander)
    #expect(commander.sent == [command])
    #expect(command.appleScriptCommand == script)
}

@Test("SC-15: controls are offered and dispatched when the queue source has failed")
func controlsIndependentOfQueueSource() throws {
    let music = MusicReading(state: .playing, title: "Tetris", artist: "LPO", album: "Greatest")
    let failed = SnapshotBuilder.build(music: music, queue: .failed(reason: "Operation not permitted"), now: now)
    let layout = WidgetLayout(snapshot: failed)
    #expect(layout.overlay?.upNextTitle == WidgetLayout.upNextUnavailableText)
    #expect(layout.overlay?.controls.map(\.command) == [.back, .playpause, .next])

    let commander = CountingCommander()
    for control in layout.overlay?.controls ?? [] {
        try CommandDispatcher.handle(notificationName: control.command.notificationName, commander: commander)
    }
    #expect(commander.sent == [.back, .playpause, .next])
}

@Test("SC-16: a not-playing layout has no overlay, so no controls or song text")
func notPlayingHasNoControls() {
    let layout = WidgetLayout(snapshot: snapshot(.notPlaying))
    #expect(layout.overlay == nil)
    #expect(layout.background == .placeholder)
}

@Test("SC-17: the play/pause icon shows what a press will do")
func playPauseIcon() {
    func icon(_ state: PlayerState) -> String? {
        WidgetLayout(snapshot: snapshot(state)).overlay?.controls.first { $0.command == .playpause }?.systemImage
    }
    #expect(icon(.playing) == "pause.fill")
    #expect(icon(.paused) == "play.fill")
}

@Test("The overlay shows the upcoming song when there is one, and a paused label when paused")
func upcomingAndPausedLabel() {
    let next = Song(title: "Gusty Garden", artist: "LPO", album: "Greatest")
    let layout = WidgetLayout(snapshot: snapshot(.paused, upcoming: next))
    #expect(layout.overlay?.upNextTitle == "Gusty Garden")
    #expect(layout.overlay?.upNextArtist == "LPO")
    #expect(layout.overlay?.statusLabel == "Paused")
    #expect(WidgetLayout(snapshot: snapshot(.playing)).overlay?.statusLabel == nil)
}

@Test("An unknown notification name issues no command")
func unknownNotificationIgnored() throws {
    let commander = CountingCommander()
    let handled = try CommandDispatcher.handle(notificationName: "com.apple.Music.playerInfo", commander: commander)
    #expect(handled == nil)
    #expect(commander.sent.isEmpty)
}

@Test("SC-18: the details view carries both songs in full, with no line limit")
func detailsCarryEverything() {
    let longTitle = "Kakariko Village [From \"The Legend of Zelda\"] (Arr. Koseki for Guitar)"
    let next = Song(title: "Fields of Dusk (Orchestral Version)", artist: "Tatran",
                    album: "Star Wars Jedi: Survivor (Original Video Game Soundtrack)")
    var playing = snapshot(.playing, upcoming: next)
    playing.current?.title = longTitle

    let details = WidgetLayout(snapshot: playing, detailsExpanded: true).overlay?.details
    #expect(details?.current == .init(title: longTitle, artist: "LPO", album: "Greatest"))
    #expect(details?.upcoming == .init(title: next.title, artist: next.artist, album: next.album))
    #expect(details?.lineLimit == nil)
    #expect(WidgetLayout(snapshot: playing).overlay?.details == nil)
}

@Test("SC-18: with no upcoming song the details view still opens and says so")
func detailsWithoutUpcoming() {
    let layout = WidgetLayout(snapshot: snapshot(.playing), detailsExpanded: true)
    #expect(layout.overlay?.details?.current.title == "Tetris")
    #expect(layout.overlay?.details?.upcoming == nil)
    #expect(layout.overlay?.upNextTitle == WidgetLayout.upNextUnavailableText)
}

@Test("SC-18: clicking twice returns to the normal layout")
func togglingTwiceCloses() {
    let playing = snapshot(.playing)
    let opened = DetailsState.toggled(storedKey: nil, snapshot: playing)
    #expect(DetailsState.isExpanded(storedKey: opened, snapshot: playing))
    let closed = DetailsState.toggled(storedKey: opened, snapshot: playing)
    #expect(closed == nil)
    #expect(!DetailsState.isExpanded(storedKey: closed, snapshot: playing))
}

@Test("SC-18: a change of current song closes the details view")
func trackChangeCloses() {
    let first = snapshot(.playing)
    var second = first
    second.current?.title = "Gusty Garden"
    let opened = DetailsState.toggled(storedKey: nil, snapshot: first)
    #expect(DetailsState.isExpanded(storedKey: opened, snapshot: first))
    #expect(!DetailsState.isExpanded(storedKey: opened, snapshot: second))
    // Pausing the same song keeps it open.
    var paused = first
    paused.state = .paused
    #expect(DetailsState.isExpanded(storedKey: opened, snapshot: paused))
}

@Test("SC-18: a not-playing layout never has the details view")
func notPlayingHasNoDetails() {
    let stopped = snapshot(.notPlaying)
    #expect(WidgetLayout(snapshot: stopped, detailsExpanded: true).overlay == nil)
    #expect(DetailsState.toggled(storedKey: nil, snapshot: stopped) == nil)
    #expect(!DetailsState.isExpanded(storedKey: "anything", snapshot: stopped))
    #expect(!DetailsState.isExpanded(storedKey: "anything", snapshot: nil))
}
