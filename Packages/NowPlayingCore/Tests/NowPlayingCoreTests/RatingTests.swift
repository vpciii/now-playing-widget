import Foundation
import Testing
@testable import NowPlayingCore

private let now = Date(timeIntervalSince1970: 1_800_000_000)

private func snapshot(_ rating: Rating, state: PlayerState = .playing) -> Snapshot {
    Snapshot(state: state,
             current: state == .notPlaying ? nil : Song(title: "Blue Bayou", artist: "Linda Ronstadt", album: "Simple Dreams"),
             upcoming: nil, updatedAt: now, expectedEndAt: nil, rating: rating)
}

private final class CountingCommander: MusicCommanding {
    var sent: [PlayerCommand] = []
    func send(_ command: PlayerCommand) throws { sent.append(command) }
}

@Test("SC-19: the like control likes an unliked song and removes the like from a liked one, one command per press",
      arguments: [(Rating.none, PlayerCommand.like, "set favorited of current track to true"),
                  (.liked, .removeLike, "set favorited of current track to false")])
func likeControl(rating: Rating, expected: PlayerCommand, script: String) throws {
    let controls = WidgetLayout(snapshot: snapshot(rating)).overlay?.ratingControls ?? []
    #expect(controls.count == 1)
    let control = try #require(controls.first)
    #expect(control.command == expected)
    #expect(expected.appleScriptCommand == script)

    let commander = CountingCommander()
    try CommandDispatcher.handle(notificationName: control.command.notificationName, commander: commander)
    #expect(commander.sent == [expected])
}

@Test("SC-22: the snapshot carries the rating Music reported, and the like icon is filled only when liked",
      arguments: [(Rating.none, "hand.thumbsup"), (.liked, "hand.thumbsup.fill")])
func iconFollowsMusic(rating: Rating, icon: String) {
    let reading = MusicReading(state: .playing, title: "Blue Bayou", artist: "", album: "", rating: rating)
    let built = SnapshotBuilder.build(music: reading, queue: .failed(reason: "x"), now: now)
    #expect(built.rating == rating)
    let controls = WidgetLayout(snapshot: built).overlay?.ratingControls ?? []
    #expect(controls.map(\.systemImage) == [icon])
}

@Test("SC-22: like commands need a fresh reading afterwards; playback commands do not")
func ratingCommandsNeedFreshReading() {
    for command in [PlayerCommand.like, .removeLike] {
        #expect(command.needsFreshReading)
    }
    for command in [PlayerCommand.next, .back, .playpause] {
        #expect(!command.needsFreshReading)
    }
}

@Test("Regression: after a like command Music is read again late enough to see the new rating")
func ratingIsReadBackLate() {
    // 2026-11-19: a like was accepted but read back as "none" 0.4 s later, so
    // the icon never filled. Music reported it after about 2.5 s.
    for command in [PlayerCommand.like, .removeLike] {
        let last = command.freshReadingDelays.max() ?? 0
        #expect(last >= 3)
        #expect(command.freshReadingDelays.count == 2)
    }
    #expect(PlayerCommand.next.freshReadingDelays.isEmpty)
}

@Test("There is no dislike command (withdrawn: Music discards it for streamed songs)")
func noDislikeCommand() {
    #expect(PlayerCommand.allCases == [.next, .back, .playpause, .like, .removeLike])
    #expect(PlayerCommand(notificationName: PlayerCommand.notificationPrefix + "dislike") == nil)
}

@Test("A not-playing layout has no like control, and a not-playing snapshot has no rating")
func noRatingWhenNotPlaying() {
    #expect(WidgetLayout(snapshot: snapshot(.liked, state: .notPlaying)).overlay == nil)
    let stopped = MusicReading(state: .stopped, title: "", artist: "", album: "", rating: .liked)
    #expect(SnapshotBuilder.build(music: stopped, queue: .failed(reason: "x"), now: now).rating == .none)
}

@Test("Snapshot files from earlier builds still decode")
func decodesOlderSnapshots() throws {
    // Before ratings existed there was no key at all.
    let older = try Snapshot.decode(Data(#"{"state":"notPlaying","updatedAt":"2026-11-19T19:33:33Z"}"#.utf8))
    #expect(older.rating == .none)
    // A value from the withdrawn dislike control reads as no rating.
    let withdrawn = try Snapshot.decode(Data(#"{"state":"notPlaying","updatedAt":"2026-11-19T19:33:33Z","rating":"disliked"}"#.utf8))
    #expect(withdrawn.rating == .none)
    let liked = snapshot(.liked)
    let roundTripped = try Snapshot.decode(liked.encoded())
    #expect(roundTripped == liked)
}
