import Foundation

final class DoHResolver: NSObject {
    static let shared = DoHResolver()

    private var dnsCache: [String: String] = [:]

    private lazy var rawSession: URLSession = {
        let config = URLSessionConfiguration.default
        config.urlCache = nil
        config.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        config.timeoutIntervalForRequest = 15
        return URLSession(configuration: config, delegate: self, delegateQueue: nil)
    }()

    private override init() {}

    func makeSession() -> URLSession {
        let config = URLSessionConfiguration.default
        config.urlCache = nil
        config.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        config.timeoutIntervalForRequest = 20
        return URLSession(configuration: config, delegate: self, delegateQueue: nil)
    }

    // MARK: - Resolve via DoH
    func resolve(hostname: String) async -> String? {
        if let cached = dnsCache[hostname] { return cached }

        let endpoints = [
            "https://1.1.1.1/dns-query?name=\(hostname)&type=A",
            "https://8.8.8.8/resolve?name=\(hostname)&type=A"
        ]
        for endpoint in endpoints {
            guard let url = URL(string: endpoint) else { continue }
            var req = URLRequest(url: url)
            req.setValue("application/dns-json", forHTTPHeaderField: "Accept")
            req.timeoutInterval = 8
            do {
                let (data, _) = try await rawSession.data(for: req)
                if let ip = parseDoH(data) {
                    dnsCache[hostname] = ip
                    return ip
                }
            } catch { continue }
        }
        return nil
    }

    private func parseDoH(_ data: Data) -> String? {
        guard let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
              let answers = json["Answer"] as? [[String: Any]] else { return nil }
        for answer in answers {
            if let type_ = answer["type"] as? Int, type_ == 1,
               let ip = answer["data"] as? String {
                return ip
            }
        }
        return nil
    }

    // MARK: - Request with DoH bypass
    func dataBypassingDNS(for originalURL: URL) async throws -> (Data, URLResponse) {
        let host = originalURL.host ?? ""
        if let ip = await resolve(hostname: host),
           var components = URLComponents(url: originalURL, resolvingAgainstBaseURL: false) {
            components.host = ip
            if let resolvedURL = components.url {
                var req = URLRequest(url: resolvedURL)
                req.setValue(host, forHTTPHeaderField: "Host")
                req.timeoutInterval = 15
                return try await rawSession.data(for: req)
            }
        }
        // fallback: direct
        var req = URLRequest(url: originalURL)
        req.timeoutInterval = 15
        return try await rawSession.data(for: req)
    }
}

// MARK: - Trust all certs (needed when connecting via IP)
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
