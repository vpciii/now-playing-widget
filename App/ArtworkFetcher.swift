import Foundation
import NowPlayingCore

/// The app's only network use (spec R-10): an HTTPS GET of an artwork URL
/// that `ArtworkURLPolicy` approved. Redirects are held to the same policy.
final class ArtworkFetcher: NSObject, URLSessionTaskDelegate {
    private lazy var session: URLSession = {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 8
        configuration.httpCookieStorage = nil
        configuration.httpShouldSetCookies = false
        return URLSession(configuration: configuration, delegate: self, delegateQueue: nil)
    }()

    /// Downloads the image and calls back on the main thread with its data,
    /// or nil on any failure.
    func fetch(_ approved: ApprovedArtworkURL, completion: @escaping (Data?) -> Void) {
        var request = URLRequest(url: approved.url)
        request.httpMethod = "GET"
        session.dataTask(with: request) { data, response, _ in
            let ok = (response as? HTTPURLResponse)?.statusCode == 200
            DispatchQueue.main.async { completion(ok ? data : nil) }
        }.resume()
    }

    func urlSession(_ session: URLSession, task: URLSessionTask,
                    willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest,
                    completionHandler: @escaping (URLRequest?) -> Void) {
        let allowed = request.url.flatMap(ArtworkURLPolicy.approve) != nil
        completionHandler(allowed ? request : nil)
    }
}
