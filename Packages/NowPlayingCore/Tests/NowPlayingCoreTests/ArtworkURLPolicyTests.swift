import Foundation
import Testing
@testable import NowPlayingCore

@Test("SC-10: HTTPS artwork URLs on Apple's image CDN are approved",
      arguments: [
        "https://is1-ssl.mzstatic.com/image/thumb/Music221/v4/a9/bf/23/x.jpg/600x600bb.jpg",
        "https://IS5-SSL.MZSTATIC.COM/image/thumb/Music/82/35/e6/mzi.ohxflbbf.jpg/600x600bb.jpg",
        "https://mzstatic.com/a.jpg",
      ])
func approvesMusicArtwork(url: String) {
    #expect(ArtworkURLPolicy.approve(url)?.url == URL(string: url))
}

@Test("SC-10: every other request is rejected",
      arguments: [
        "http://is1-ssl.mzstatic.com/a.jpg",            // not HTTPS
        "https://example.com/a.jpg",                    // another host
        "https://mzstatic.com.example.com/a.jpg",       // suffix trick
        "https://evilmzstatic.com/a.jpg",               // not a subdomain
        "https://user:pw@is1-ssl.mzstatic.com/a.jpg",   // credentials
        "file:///etc/passwd",
        "ftp://is1-ssl.mzstatic.com/a.jpg",
        "",
        "not a url",
      ])
func rejectsEverythingElse(url: String) {
    #expect(ArtworkURLPolicy.approve(url) == nil)
}

@Test("SC-10: a missing artwork URL is rejected")
func rejectsMissing() {
    #expect(ArtworkURLPolicy.approve(nil as String?) == nil)
}

private let zelda = MusicReading(state: .playing, title: "Zelda's Lullaby", artist: "VOCES8", album: "Nightfall")
private let zeldaURL = "https://is1-ssl.mzstatic.com/image/thumb/Music/nightfall.jpg/800x800bb.jpg"

@Test("Regression: the current artwork comes from the queue's URL for that song, not from AppleScript")
func currentArtworkPrefersQueueURL() {
    // 2026-11-19: after a track change AppleScript returned the previous
    // song's artwork, so the widget showed the right title on the wrong cover.
    let queue = QueueResult.items([
        QueueItem(title: "Zelda's Lullaby", artist: "VOCES8", album: "Nightfall", artworkURL: zeldaURL),
        QueueItem(title: "Next", artist: "", album: ""),
    ])
    #expect(CurrentArtworkSource.choose(music: zelda, queue: queue) == .download(ArtworkURLPolicy.approve(zeldaURL)!))
}

@Test("The current artwork falls back to AppleScript only when the queue has no usable URL for this song",
      arguments: [
        QueueResult.failed(reason: "Operation not permitted"),
        QueueResult.items([]),
        // The queue is for a different song (readings straddle a track change).
        QueueResult.items([QueueItem(title: "Overture March", artist: "", album: "", artworkURL: zeldaURL)]),
        // No URL, as for a local file.
        QueueResult.items([QueueItem(title: "Zelda's Lullaby", artist: "", album: "")]),
        // A URL the policy rejects.
        QueueResult.items([QueueItem(title: "Zelda's Lullaby", artist: "", album: "", artworkURL: "https://example.com/a.jpg")]),
      ])
func currentArtworkFallsBack(queue: QueueResult) {
    #expect(CurrentArtworkSource.choose(music: zelda, queue: queue) == .appleScript)
}
