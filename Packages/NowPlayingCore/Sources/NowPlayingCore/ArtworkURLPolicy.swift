import Foundation

/// An artwork URL the app is allowed to download. It can only be made by
/// `ArtworkURLPolicy`, so the fetcher cannot be handed anything else.
public struct ApprovedArtworkURL: Equatable, Sendable {
    public let url: URL
    fileprivate init(url: URL) { self.url = url }
}

/// The app's only network use is downloading artwork from the URLs Music
/// itself reports (spec R-10). Music's artwork lives on Apple's image CDN, so
/// that is the only host accepted.
public enum ArtworkURLPolicy {
    public static let allowedHostSuffix = "mzstatic.com"

    public static func approve(_ string: String?) -> ApprovedArtworkURL? {
        guard let string, let url = URL(string: string) else { return nil }
        return approve(url)
    }

    public static func approve(_ url: URL) -> ApprovedArtworkURL? {
        guard url.scheme?.lowercased() == "https",
              url.user == nil, url.password == nil,
              let host = url.host?.lowercased(),
              host == allowedHostSuffix || host.hasSuffix("." + allowedHostSuffix)
        else { return nil }
        return ApprovedArtworkURL(url: url)
    }
}
