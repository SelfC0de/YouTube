import Foundation

final class DoHResolver {
    static let shared = DoHResolver()

    private let dohURL = "https://cloudflare-dns.com/dns-query"

    private init() {
        configureURLSession()
    }

    private func configureURLSession() {
        URLSession.shared.configuration.urlCache = nil
    }

    func makeSession() -> URLSession {
        let config = URLSessionConfiguration.default
        config.urlCache = nil
        config.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        return URLSession(configuration: config)
    }
}
