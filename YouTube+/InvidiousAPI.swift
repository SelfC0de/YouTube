import Foundation

@MainActor
final class InvidiousAPI: ObservableObject {
    static let shared = InvidiousAPI()

    @Published var currentInstance: String = UserDefaults.standard.string(forKey: "selectedInstance") ?? InvidiousAPI.instances[0]

    static let instances: [String] = [
        "https://inv.nadeko.net",
        "https://invidious.fdn.fr",
        "https://invidious.privacydev.net",
        "https://yt.cdaut.de",
        "https://invidious.nerdvpn.de",
        "https://invidious.incogniweb.net"
    ]

    private let session = DoHResolver.shared.makeSession()

    private init() {}

    func setInstance(_ instance: String) {
        currentInstance = instance
        UserDefaults.standard.set(instance, forKey: "selectedInstance")
    }

    // MARK: - Search
    func search(query: String, page: Int = 1) async throws -> [InvidiousVideo] {
        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        let url = URL(string: "\(currentInstance)/api/v1/search?q=\(encoded)&page=\(page)&type=video")!
        let (data, _) = try await session.data(from: url)
        return try JSONDecoder().decode([InvidiousVideo].self, from: data)
    }

    // MARK: - Trending
    func trending(region: String = "RU") async throws -> [InvidiousVideo] {
        let url = URL(string: "\(currentInstance)/api/v1/trending?region=\(region)")!
        let (data, _) = try await session.data(from: url)
        return try JSONDecoder().decode([InvidiousVideo].self, from: data)
    }

    // MARK: - Video detail
    func videoDetail(videoId: String) async throws -> InvidiousVideoDetail {
        let url = URL(string: "\(currentInstance)/api/v1/videos/\(videoId)")!
        let (data, _) = try await session.data(from: url)
        return try JSONDecoder().decode(InvidiousVideoDetail.self, from: data)
    }

    // MARK: - Channel videos
    func channelVideos(channelId: String, page: Int = 1) async throws -> [InvidiousVideo] {
        let url = URL(string: "\(currentInstance)/api/v1/channels/\(channelId)/videos?page=\(page)")!
        let (data, _) = try await session.data(from: url)
        struct Response: Codable { let videos: [InvidiousVideo] }
        let resp = try JSONDecoder().decode(Response.self, from: data)
        return resp.videos
    }

    // MARK: - Channel info
    func channelInfo(channelId: String) async throws -> InvidiousChannel {
        let url = URL(string: "\(currentInstance)/api/v1/channels/\(channelId)")!
        let (data, _) = try await session.data(from: url)
        return try JSONDecoder().decode(InvidiousChannel.self, from: data)
    }

    // MARK: - Subscriptions feed (requires auth token)
    func subscriptionFeed(token: String) async throws -> [InvidiousVideo] {
        var request = URLRequest(url: URL(string: "\(currentInstance)/api/v1/auth/feed")!)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let (data, _) = try await session.data(for: request)
        struct Feed: Codable { let videos: [InvidiousVideo] }
        let feed = try JSONDecoder().decode(Feed.self, from: data)
        return feed.videos
    }

    // MARK: - Login
    func login(username: String, password: String) async throws -> String {
        let url = URL(string: "\(currentInstance)/api/v1/auth/login")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body = ["username": username, "password": password]
        request.httpBody = try JSONEncoder().encode(body)
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw APIError.authFailed
        }
        struct TokenResponse: Codable { let token: String }
        let tokenResp = try JSONDecoder().decode(TokenResponse.self, from: data)
        return tokenResp.token
    }

    // MARK: - Ping instance
    func pingInstance(_ instance: String) async -> Bool {
        guard let url = URL(string: "\(instance)/api/v1/stats") else { return false }
        do {
            let (_, response) = try await session.data(from: url)
            return (response as? HTTPURLResponse)?.statusCode == 200
        } catch {
            return false
        }
    }

    enum APIError: LocalizedError {
        case authFailed
        case noData
        var errorDescription: String? {
            switch self {
            case .authFailed: return "Ошибка авторизации"
            case .noData: return "Нет данных"
            }
        }
    }
}
