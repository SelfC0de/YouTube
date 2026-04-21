import Foundation

@MainActor
final class InvidiousAPI: ObservableObject {
    static let shared = InvidiousAPI()

    @Published var currentInstance: String = ""
    @Published var instanceStatus: String = "Поиск инстанса..."

    static let instances: [String] = [
        "https://inv.nadeko.net",
        "https://invidious.privacydev.net",
        "https://invidious.fdn.fr",
        "https://yt.cdaut.de",
        "https://invidious.nerdvpn.de",
        "https://iv.melmac.space",
        "https://invidious.lunar.icu",
        "https://invidious.incogniweb.net"
    ]

    private init() {}

    // MARK: - Instance discovery
    func ensureInstance() async {
        guard currentInstance.isEmpty else { return }
        instanceStatus = "Поиск инстанса..."

        // Pass 1: normal DNS
        for inst in InvidiousAPI.instances {
            if await ping(inst, useDoh: false) {
                currentInstance = inst
                instanceStatus = inst.replacingOccurrences(of: "https://", with: "")
                return
            }
        }

        // Pass 2: DoH bypass
        instanceStatus = "DoH обход..."
        for inst in InvidiousAPI.instances {
            if await ping(inst, useDoh: true) {
                currentInstance = inst
                instanceStatus = inst.replacingOccurrences(of: "https://", with: "") + " (DoH)"
                return
            }
        }

        currentInstance = InvidiousAPI.instances[0]
        instanceStatus = "Нет подключения"
    }

    private func ping(_ instance: String, useDoh: Bool) async -> Bool {
        guard let url = URL(string: "\(instance)/api/v1/stats") else { return false }
        do {
            let (_, response): (Data, URLResponse)
            if useDoh {
                (_, response) = try await DoHResolver.shared.dataBypassingDNS(for: url)
            } else {
                var req = URLRequest(url: url)
                req.timeoutInterval = 8
                (_, response) = try await DoHResolver.shared.makeSession().data(for: req)
            }
            return (response as? HTTPURLResponse)?.statusCode == 200
        } catch { return false }
    }

    // MARK: - Core fetch
    private func requestData(path: String) async throws -> Data {
        await ensureInstance()
        let ordered = [currentInstance] + InvidiousAPI.instances.filter { $0 != currentInstance }

        // Pass 1: normal
        for inst in ordered {
            if let data = try? await fetch(inst + path, useDoh: false) {
                if inst != currentInstance {
                    currentInstance = inst
                    instanceStatus = inst.replacingOccurrences(of: "https://", with: "")
                }
                return data
            }
        }
        // Pass 2: DoH
        for inst in ordered {
            if let data = try? await fetch(inst + path, useDoh: true) {
                if inst != currentInstance {
                    currentInstance = inst
                    instanceStatus = inst.replacingOccurrences(of: "https://", with: "") + " (DoH)"
                }
                return data
            }
        }
        throw APIError.noData
    }

    private func fetch(_ urlString: String, useDoh: Bool) async throws -> Data {
        guard let url = URL(string: urlString) else { throw APIError.noData }
        let (data, response): (Data, URLResponse)
        if useDoh {
            (data, response) = try await DoHResolver.shared.dataBypassingDNS(for: url)
        } else {
            var req = URLRequest(url: url)
            req.timeoutInterval = 15
            (data, response) = try await DoHResolver.shared.makeSession().data(for: req)
        }
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw APIError.noData }
        return data
    }

    // MARK: - Public API
    func search(query: String, page: Int = 1) async throws -> [InvidiousVideo] {
        let q = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        let data = try await requestData(path: "/api/v1/search?q=\(q)&page=\(page)&type=video")
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

    func login(username: String, password: String) async throws -> String {
        await ensureInstance()
        var req = URLRequest(url: URL(string: "\(currentInstance)/api/v1/auth/login")!)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONEncoder().encode(["username": username, "password": password])
        let (data, response) = try await DoHResolver.shared.makeSession().data(for: req)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw APIError.authFailed }
        struct TR: Codable { let token: String }
        return try JSONDecoder().decode(TR.self, from: data).token
    }

    func register(username: String, password: String) async throws {
        await ensureInstance()
        var req = URLRequest(url: URL(string: "\(currentInstance)/api/v1/auth/register")!)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONEncoder().encode(["username": username, "password": password, "email": ""])
        let (_, response) = try await DoHResolver.shared.makeSession().data(for: req)
        let code = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard code == 200 || code == 201 else { throw APIError.authFailed }
    }

    enum APIError: LocalizedError {
        case authFailed, noData
        var errorDescription: String? {
            switch self {
            case .authFailed: return "Ошибка авторизации"
            case .noData: return "Нет подключения к серверу"
            }
        }
    }
}
