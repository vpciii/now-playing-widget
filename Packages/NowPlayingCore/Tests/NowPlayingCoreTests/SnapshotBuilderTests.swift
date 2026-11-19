import Foundation
import Testing
import WidgetKit
@testable import NowPlayingCore

private let now = Date(timeIntervalSince1970: 1_800_000_000)

private func reading(_ state: MusicReading.State = .playing, title: String = "Frozen Tears") -> MusicReading {
    MusicReading(state: state, title: title, artist: "LSO", album: "Heart of Ice", duration: 200, position: 50)
}

private let goodQueue = QueueResult.items([
    QueueItem(title: "Frozen Tears", artist: "LSO", album: "Heart of Ice"),
    QueueItem(title: "Lost in the Storm", artist: "Gareth Coker", album: "Ori"),
    QueueItem(title: "Gusty Garden", artist: "LPO", album: "Greatest"),
])

@Test("SC-1: the widget supports exactly the large family")
func supportedFamilies() {
    #expect(WidgetSupport.supportedFamilies == [.systemLarge])
}

@Test("SC-2: a playing song's title, artist and album pass through unchanged")
func currentSongFields() {
    let snapshot = SnapshotBuilder.build(music: reading(), queue: goodQueue, now: now)
    #expect(snapshot.current?.title == "Frozen Tears")
    #expect(snapshot.current?.artist == "LSO")
    #expect(snapshot.current?.album == "Heart of Ice")
}

@Test("SC-4: the queue source's next item becomes the upcoming song")
func upcomingFromQueue() {
    let snapshot = SnapshotBuilder.build(music: reading(), queue: goodQueue, now: now)
    #expect(snapshot.upcoming?.title == "Lost in the Storm")
    #expect(snapshot.upcoming?.artist == "Gareth Coker")
}

@Test("SC-5: any queue source failure marks upcoming unavailable and keeps the current song",
      arguments: [
        QueueOutputParser.parse(stdout: Data(), exitCode: 1, timedOut: false),
        QueueOutputParser.parse(stdout: Data(), exitCode: 0, timedOut: true),
        QueueOutputParser.parse(stdout: Data("not json".utf8), exitCode: 0, timedOut: false),
        QueueResult.failed(reason: "Operation not permitted"),
        QueueResult.items([]),
        QueueResult.items([QueueItem(title: "Frozen Tears", artist: "LSO", album: "Heart of Ice")]),
        QueueResult.items([QueueItem(title: "Frozen Tears", artist: "LSO", album: "Heart of Ice"),
                           QueueItem(title: "", artist: "", album: "")]),
      ])
func queueFailureFallsBack(queue: QueueResult) {
    let snapshot = SnapshotBuilder.build(music: reading(), queue: queue, now: now)
    #expect(snapshot.upcoming == nil)
    #expect(snapshot.current?.title == "Frozen Tears")
    #expect(snapshot.state == .playing)
}

@Test("SC-5: a queue that does not start with the current song is not trusted")
func queueOutOfStepWithCurrentSong() {
    let snapshot = SnapshotBuilder.build(music: reading(title: "A Different Song"), queue: goodQueue, now: now)
    #expect(snapshot.upcoming == nil)
    #expect(snapshot.current?.title == "A Different Song")
}

@Test("SC-6: with the queue source failing, nothing else can supply an upcoming song")
func noInferenceWithoutQueue() {
    // The builder's only inputs are the supported-route reading and the queue
    // result; a reading carries no playlist or album-order information.
    for state in [MusicReading.State.playing, .paused] {
        let snapshot = SnapshotBuilder.build(music: reading(state), queue: .failed(reason: "x"), now: now,
                                             upcomingArtworkFile: "upcoming-artwork.jpg")
        #expect(snapshot.upcoming == nil)
    }
}

@Test("SC-7: Music not running or stopped gives a not-playing snapshot with no song fields")
func notPlaying() {
    for music in [nil, reading(.stopped)] as [MusicReading?] {
        let snapshot = SnapshotBuilder.build(music: music, queue: goodQueue, now: now,
                                             currentArtworkFile: "current-artwork.jpg")
        #expect(snapshot.state == .notPlaying)
        #expect(snapshot.current == nil)
        #expect(snapshot.upcoming == nil)
        #expect(snapshot.expectedEndAt == nil)
    }
}

@Test("SC-8: paused and playing snapshots are distinguishable")
func pausedVersusPlaying() {
    let playing = SnapshotBuilder.build(music: reading(.playing), queue: goodQueue, now: now)
    let paused = SnapshotBuilder.build(music: reading(.paused), queue: goodQueue, now: now)
    #expect(playing.state == .playing)
    #expect(paused.state == .paused)
    #expect(playing.state != paused.state)
    #expect(playing.expectedEndAt == now.addingTimeInterval(150))
    #expect(paused.expectedEndAt == nil)
}

@Test("A snapshot survives a round trip through its file format")
func roundTrip() throws {
    let snapshot = SnapshotBuilder.build(music: reading(), queue: goodQueue, now: now,
                                         currentArtworkFile: "current-artwork.jpg")
    #expect(try Snapshot.decode(snapshot.encoded()) == snapshot)
}

@Test("A valid queue source run parses into its items")
func parsesQueueOutput() {
    let json = #"{"items":[{"title":"A","artist":"B","album":"C","artworkURL":"https://is1-ssl.mzstatic.com/x.jpg"},{"title":"D","artist":"E","album":"F"}]}"#
    let result = QueueOutputParser.parse(stdout: Data(json.utf8), exitCode: 0, timedOut: false)
    #expect(result == .items([
        QueueItem(title: "A", artist: "B", album: "C", artworkURL: "https://is1-ssl.mzstatic.com/x.jpg"),
        QueueItem(title: "D", artist: "E", album: "F"),
    ]))
}

@Test("Player commands map to notification names and back")
func commandNames() {
    for command in PlayerCommand.allCases {
        #expect(PlayerCommand(notificationName: command.notificationName) == command)
    }
    #expect(PlayerCommand(notificationName: "com.apple.Music.playerInfo") == nil)
}

@Test("SC-3: artwork is carried when Music provides it and absent (placeholder) when it does not")
func artworkOrPlaceholder() {
    let with = SnapshotBuilder.build(music: reading(), queue: goodQueue, now: now,
                                     currentArtworkFile: ArtworkFile.current)
    let without = SnapshotBuilder.build(music: reading(), queue: goodQueue, now: now, currentArtworkFile: nil)
    #expect(with.current?.artworkFile == ArtworkFile.current)
    #expect(without.current?.artworkFile == nil)
    #expect(without.current?.title == "Frozen Tears")
}

@Test("A playing song turns into not playing once it is well past its expected end")
func staleProtection() {
    let playing = SnapshotBuilder.build(music: reading(.playing), queue: goodQueue, now: now)
    let end = now.addingTimeInterval(150)

    let live = TimelinePlan.entries(for: playing, now: now)
    #expect(live.count == 2)
    #expect(live[0].snapshot == playing)
    #expect(live[1].date == end.addingTimeInterval(TimelinePlan.staleMargin))
    #expect(live[1].snapshot.state == .notPlaying)
    #expect(live[1].snapshot.current == nil)

    let late = TimelinePlan.entries(for: playing, now: end.addingTimeInterval(TimelinePlan.staleMargin + 1))
    #expect(late.map(\.snapshot.state) == [.notPlaying])
}

@Test("Paused and missing snapshots get a single entry")
func timelineWithoutExpectedEnd() {
    let paused = SnapshotBuilder.build(music: reading(.paused), queue: goodQueue, now: now)
    #expect(TimelinePlan.entries(for: paused, now: now).map(\.snapshot) == [paused])
    #expect(TimelinePlan.entries(for: nil, now: now).map(\.snapshot.state) == [.notPlaying])
}

@Test("Regression: a stopped reading waits before showing not playing; Music not running does not")
func stoppedReadingSettles() {
    // 2026-11-19: starting a different playlist logged three "notPlaying"
    // publishes within 100 ms before the new song, flashing the widget.
    #expect(NotPlayingTiming.decide(for: reading(.stopped)) == .publishIfStillCurrent(after: NotPlayingTiming.settleDelay))
    #expect(NotPlayingTiming.decide(for: nil) == .publishNow)
    #expect(NotPlayingTiming.settleDelay >= 0.5)
}
