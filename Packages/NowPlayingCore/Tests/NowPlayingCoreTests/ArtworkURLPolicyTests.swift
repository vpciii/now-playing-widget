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
