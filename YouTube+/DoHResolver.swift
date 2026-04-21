import Foundation

// Resolves hostnames via Cloudflare DoH (1.1.1.1) to bypass ISP DNS blocking.
// Then makes requests directly to resolved IP with Host header.
final class DoHResolver: NSObject {
    static let shared = DoHResolver()

    // Raw IP session — bypasses DNS entirely
    private lazy var rawSession: URLSession = {
        let config = URLSessionConfiguration.default
        config.urlCache = nil
        config.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        config.timeoutIntervalForRequest = 15
        // Use Cloudflare & Google DNS IPs directly
        return URLSession(configuration: config, delegate: self, delegateQueue: nil)
    }()

    // Cache: hostname -> [IP]
    private var dnsCache: [String: String] = [:]
    private var cacheLock = NSLock()

    private override init() {}

    // MARK: - Public session factory
    func makeSession() -> URLSession {
        let config = URLSessionConfiguration.default
        config.urlCache = nil
        config.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        config.timeoutIntervalForRequest = 20
        return URLSession(configuration: config, delegate: self, delegateQueue: nil)
    }

    // MARK: - Resolve hostname via DoH
    func resolve(hostname: String) async -> String? {
        cacheLock.lock()
        if let cached = dnsCache[hostname] {
            cacheLock.unlock()
            return cached
        }
        cacheLock.unlock()

        // Try Cloudflare DoH JSON API via IP (no DNS needed for 1.1.1.1)
        let dohEndpoints = [
            "https://1.1.1.1/dns-query?name=\(hostname)&type=A",
            "https://8.8.8.8/resolve?name=\(hostname)&type=A"
        ]

        for endpoint in dohEndpoints {
            guard let url = URL(string: endpoint) else { continue }
            var req = URLRequest(url: url)
            req.setValue("application/dns-json", forHTTPHeaderField: "Accept")
            req.timeoutInterval = 8

            do {
                let (data, _) = try await rawSession.data(for: req)
                if let ip = parseDoHResponse(data) {
                    cacheLock.lock()
                    dnsCache[hostname] = ip
                    cacheLock.unlock()
                    return ip
                }
            } catch { continue }
        }
        return nil
    }

    private func parseDoHResponse(_ data: Data) -> String? {
        guard let json = try? JSONSerialization.jsonObject(data) as? [String: Any],
              let answers = json["Answer"] as? [[String: Any]] else { return nil }
        // type 1 = A record
        return answers.first(where: { $0["type"] as? Int == 1 })?["data"] as? String
    }

    // MARK: - Make request bypassing DNS
    func dataBypassingDNS(for originalURL: URL) async throws -> (Data, URLResponse) {
        let host = originalURL.host ?? ""
        
        // Try DoH resolve
        if let ip = await resolve(hostname: host) {
            var components = URLComponents(url: originalURL, resolvingAgainstBaseURL: false)!
            components.host = ip
            if let resolvedURL = components.url {
                var req = URLRequest(url: resolvedURL)
                req.setValue(host, forHTTPHeaderField: "Host")
                req.setValue("application/json", forHTTPHeaderField: "Accept")
                req.timeoutInterval = 15
                return try await rawSession.data(for: req)
            }
        }

        // Fallback: direct request (works if DNS not blocked)
        var req = URLRequest(url: originalURL)
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        req.timeoutInterval = 15
        return try await rawSession.data(for: req)
    }
}

// MARK: - Trust all certs (needed when connecting to IP directly)
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
