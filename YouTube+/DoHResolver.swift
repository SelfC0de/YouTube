import Foundation

// Shared URLSession that trusts self-signed certificates
// Needed for our own Yattee Server with self-signed SSL
final class DoHResolver: NSObject {
    static let shared = DoHResolver()
    private override init() {}

    func makeSession() -> URLSession {
        let cfg = URLSessionConfiguration.default
        cfg.urlCache = nil
        cfg.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        cfg.timeoutIntervalForRequest = 20
        return URLSession(configuration: cfg, delegate: self, delegateQueue: nil)
    }

    func dataBypassingDNS(for url: URL) async throws -> (Data, URLResponse) {
        var req = URLRequest(url: url)
        req.timeoutInterval = 15
        return try await makeSession().data(for: req)
    }
}

// Trust self-signed certificates
extension DoHResolver: URLSessionDelegate {
    func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge,
                    completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        if challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
           let trust = challenge.protectionSpace.serverTrust {
            completionHandler(.useCredential, URLCredential(trust: trust))
        } else {
            completionHandler(.performDefaultHandling, nil)
        }
    }
}
