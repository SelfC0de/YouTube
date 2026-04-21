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

    private var isSearching = false
    private init() {}

    // MARK: - Find working instance (parallel ping)
    func ensureInstance() async {
        guard currentInstance.isEmpty, !isSearching else { return }
        isSearching = true
        instanceStatus = "Поиск инстанса..."

        if let found = await findWorkingInstance() {
            currentInstance = found
            instanceStatus = found.replacingOccurrences(of: "https://", with: "")
        } else {
            instanceStatus = "Нет доступных серверов"
        }
        isSearching = false
    }

    // Параллельный пинг — берём первый ответивший
    private func findWorkingInstance() async -> String? {
        await withTaskGroup(of: String?.self) { group in
            for inst in InvidiousAPI.instances {
                group.addTask { [inst] in
                    await self.ping(inst) ? inst : nil
                }
            }
            for await result in group {
                if let found = result {
                    group.cancelAll()
                    return found
                }
            }
            return nil
        }
    }

    private func ping(_ instance: String) async -> Bool {
        guard let url = URL(string: "\(instance)/api/v1/trending?region=RU") else { return false }
        do {
            var req = URLRequest(url: url)
            req.timeoutInterval = 10
            let (data, response) = try await URLSession.shared.data(for: req)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else { return false }
            // Verify it actually returns video data
            let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [[String: Any]]
            return json != nil && !(json!.isEmpty)
        } catch { return false }
    }

    // MARK: - Core fetch with auto-retry
    func requestData(path: String) async throws -> Data {
        // If no instance yet, find one
        if currentInstance.isEmpty {
            await ensureInstance()
        }

        // Try current first, then others
        let ordered = currentInstance.isEmpty
            ? InvidiousAPI.instances
            : ([currentInstance] + InvidiousAPI.instances.filter { $0 != currentInstance })

        var lastError: Error = APIError.noData
        for inst in ordered {
            guard let url = URL(string: "\(inst)\(path)") else { continue }
            do {
                var req = URLRequest(url: url)
                req.timeoutInterval = 15
                let (data, response) = try await URLSession.shared.data(for: req)
                guard (response as? HTTPURLResponse)?.statusCode == 200 else { continue }
                // Update current if we switched
                if inst != currentInstance {
                    currentInstance = inst
                    instanceStatus = inst.replacingOccurrences(of: "https://", with: "")
                }
                return data
            } catch {
                lastError = error
                continue
            }
        }
        throw lastError
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
        if currentInstance.isEmpty { await ensureInstance() }
        var req = URLRequest(url: URL(string: "\(currentInstance)/api/v1/auth/login")!)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONEncoder().encode(["username": username, "password": password])
        let (data, response) = try await URLSession.shared.data(for: req)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw APIError.authFailed }
        struct TR: Codable { let token: String }
        return try JSONDecoder().decode(TR.self, from: data).token
    }

    func register(username: String, password: String) async throws {
        if currentInstance.isEmpty { await ensureInstance() }
        var req = URLRequest(url: URL(string: "\(currentInstance)/api/v1/auth/register")!)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONEncoder().encode(["username": username, "password": password, "email": ""])
        let (_, response) = try await URLSession.shared.data(for: req)
        let code = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard code == 200 || code == 201 else { throw APIError.authFailed }
    }

    // Force re-search (for settings refresh button)
    func resetAndFind() async {
        currentInstance = ""
        isSearching = false
        await ensureInstance()
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
