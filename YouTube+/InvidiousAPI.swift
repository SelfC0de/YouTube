import Foundation

@MainActor
final class InvidiousAPI: ObservableObject {
    static let shared = InvidiousAPI()

    @Published var currentInstance: String = ""
    @Published var instanceStatus: String = "Поиск инстанса..."

    static let instances: [String] = [
        "https://inv.nadeko.net",
        "https://invidious.fdn.fr",
        "https://invidious.privacydev.net",
        "https://yt.cdaut.de",
        "https://invidious.nerdvpn.de",
        "https://invidious.incogniweb.net",
        "https://iv.melmac.space",
        "https://invidious.lunar.icu"
    ]

    private let session = DoHResolver.shared.makeSession()
    private var instanceChecked = false

    private init() {}

    func ensureInstance() async {
        guard currentInstance.isEmpty else { return }
        instanceChecked = true
        for instance in InvidiousAPI.instances {
            if await ping(instance) {
                currentInstance = instance
                instanceStatus = instance.replacingOccurrences(of: "https://", with: "")
                return
            }
        }
        currentInstance = InvidiousAPI.instances[0]
        instanceStatus = "Нет доступных инстансов"
    }

    private func ping(_ instance: String) async -> Bool {
        guard let url = URL(string: "\(instance)/api/v1/stats") else { return false }
        do {
            let (_, response) = try await session.data(from: url)
            return (response as? HTTPURLResponse)?.statusCode == 200
        } catch { return false }
    }

    private func requestData(path: String) async throws -> Data {
        await ensureInstance()
        var lastError: Error = APIError.noData
        let ordered = ([currentInstance] + InvidiousAPI.instances.filter { $0 != currentInstance })
        for instance in ordered {
            guard let url = URL(string: "\(instance)\(path)") else { continue }
            do {
                let (data, response) = try await session.data(from: url)
                guard (response as? HTTPURLResponse)?.statusCode == 200 else { continue }
                if instance != currentInstance {
                    currentInstance = instance
                    instanceStatus = instance.replacingOccurrences(of: "https://", with: "")
                }
                return data
            } catch { lastError = error; continue }
        }
        throw lastError
    }

    func search(query: String, page: Int = 1) async throws -> [InvidiousVideo] {
        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        let data = try await requestData(path: "/api/v1/search?q=\(encoded)&page=\(page)&type=video")
        return try JSONDecoder().decode([InvidiousVideo].self, from: data)
    }

    func trending() async throws -> [InvidiousVideo] {
        let data = try await requestData(path: "/api/v1/trending?region=RU")
        return try JSONDecoder().decode([InvidiousVideo].self, from: data)
    }

    func videoDetail(videoId: String) async throws -> InvidiousVideoDetail {
        let data = try await requestData(path: "/api/v1/videos/\(videoId)")
        return try JSONDecoder().decode(InvidiousVideoDetail.self, from: data)
    }

    func channelVideos(channelId: String, page: Int = 1) async throws -> [InvidiousVideo] {
        let data = try await requestData(path: "/api/v1/channels/\(channelId)/videos?page=\(page)")
        struct R: Codable { let videos: [InvidiousVideo] }
        return try JSONDecoder().decode(R.self, from: data).videos
    }

    func channelInfo(channelId: String) async throws -> InvidiousChannel {
        let data = try await requestData(path: "/api/v1/channels/\(channelId)")
        return try JSONDecoder().decode(InvidiousChannel.self, from: data)
    }

    func subscriptionFeed(token: String) async throws -> [InvidiousVideo] {
        await ensureInstance()
        var req = URLRequest(url: URL(string: "\(currentInstance)/api/v1/auth/feed")!)
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let (data, _) = try await session.data(for: req)
        struct Feed: Codable { let videos: [InvidiousVideo] }
        return try JSONDecoder().decode(Feed.self, from: data).videos
    }

    func login(username: String, password: String) async throws -> String {
        await ensureInstance()
        var req = URLRequest(url: URL(string: "\(currentInstance)/api/v1/auth/login")!)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONEncoder().encode(["username": username, "password": password])
        let (data, response) = try await session.data(for: req)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw APIError.authFailed }
        struct TR: Codable { let token: String }
        return try JSONDecoder().decode(TR.self, from: data).token
    }

    enum APIError: LocalizedError {
        case authFailed, noData
        var errorDescription: String? {
            switch self {
            case .authFailed: return "Ошибка авторизации"
            case .noData: return "Нет данных"
            }
        }
    }
}

// MARK: - Register (extension)
extension InvidiousAPI {
    func register(username: String, password: String) async throws {
        await ensureInstance()
        // Invidious registration endpoint
        let url = URL(string: "\(currentInstance)/api/v1/auth/register")!
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONEncoder().encode([
            "username": username,
            "password": password,
            "email": ""
        ])
        let (_, response) = try await session.data(for: req)
        let code = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard code == 200 || code == 201 else {
            throw APIError.registrationFailed(code)
        }
    }
}

extension InvidiousAPI.APIError {
    static func registrationFailed(_ code: Int) -> InvidiousAPI.APIError {
        return .authFailed
    }
}
