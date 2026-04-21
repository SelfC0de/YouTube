import Foundation

@MainActor
final class InvidiousAPI: ObservableObject {
    static let shared = InvidiousAPI()

    @Published var currentInstance: String = ""
    @Published var instanceStatus: String = "Поиск..."

    // Official instances from docs.invidious.io/instances + high-uptime extras
    private static let hardcodedInstances: [String] = [
        "https://inv.nadeko.net",          // 🇨🇱 official list
        "https://invidious.nerdvpn.de",    // 🇺🇦 official list
        "https://yewtu.be",                // 🇩🇪 official list
        "https://invidious.privacydev.net",
        "https://invidious.fdn.fr",
        "https://yt.cdaut.de",
        "https://iv.melmac.space",
        "https://invidious.lunar.icu"
    ]

    private let session: URLSession = {
        let cfg = URLSessionConfiguration.default
        cfg.timeoutIntervalForRequest = 12
        cfg.timeoutIntervalForResource = 30
        cfg.urlCache = nil
        cfg.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        return URLSession(configuration: cfg)
    }()

    private var instancesFromAPI: [String] = []
    private var isSearching = false
    private var lastInstanceFetch: Date?

    private init() {}

    // MARK: - Dynamic instance list from api.invidious.io
    private func fetchInstanceList() async {
        // Refresh max once per hour
        if let last = lastInstanceFetch, Date().timeIntervalSince(last) < 3600 { return }
        guard let url = URL(string: "https://api.invidious.io/instances.json?sort_by=health") else { return }
        do {
            var req = URLRequest(url: url)
            req.timeoutInterval = 10
            let (data, _) = try await session.data(for: req)
            // Format: [[name, {uri, ...}], ...]
            if let arr = try? JSONSerialization.jsonObject(with: data) as? [[Any]] {
                let uris = arr.compactMap { pair -> String? in
                    guard let info = pair[safe: 1] as? [String: Any],
                          let uri = info["uri"] as? String,
                          uri.hasPrefix("https://") else { return nil }
                    return uri
                }
                if !uris.isEmpty {
                    instancesFromAPI = uris
                    lastInstanceFetch = Date()
                }
            }
        } catch {}
    }

    var allInstances: [String] {
        // Merge: dynamic list first, then hardcoded as fallback
        var combined = instancesFromAPI
        for inst in InvidiousAPI.hardcodedInstances where !combined.contains(inst) {
            combined.append(inst)
        }
        return combined
    }

    // MARK: - Parallel instance discovery
    func ensureInstance() async {
        guard currentInstance.isEmpty, !isSearching else { return }
        isSearching = true
        defer { isSearching = false }

        instanceStatus = "Поиск инстанса..."

        // Try to get fresh list
        await fetchInstanceList()

        let found = await withTaskGroup(of: (String, Double)?.self) { group in
            for inst in allInstances {
                group.addTask { [inst] in
                    let start = Date()
                    guard await self.ping(inst) else { return nil }
                    let ms = Date().timeIntervalSince(start) * 1000
                    return (inst, ms)
                }
            }
            // Take fastest responder
            var best: (String, Double)? = nil
            for await result in group {
                guard let r = result else { continue }
                if best == nil || r.1 < best!.1 {
                    best = r
                }
            }
            return best?.0
        }

        if let inst = found {
            currentInstance = inst
            instanceStatus = inst
                .replacingOccurrences(of: "https://", with: "")
                .replacingOccurrences(of: "http://", with: "")
        } else {
            instanceStatus = "Нет доступных серверов"
        }
    }

    private func ping(_ instance: String) async -> Bool {
        guard let url = URL(string: "\(instance)/api/v1/stats") else { return false }
        do {
            var req = URLRequest(url: url)
            req.timeoutInterval = 8
            let (_, response) = try await session.data(for: req)
            return (response as? HTTPURLResponse)?.statusCode == 200
        } catch { return false }
    }

    func resetAndFind() async {
        currentInstance = ""
        instancesFromAPI = []
        lastInstanceFetch = nil
        isSearching = false
        await ensureInstance()
    }

    // MARK: - Core fetch with fallback
    func fetch(path: String) async throws -> Data {
        if currentInstance.isEmpty { await ensureInstance() }

        let ordered = currentInstance.isEmpty
            ? allInstances
            : ([currentInstance] + allInstances.filter { $0 != currentInstance })

        var lastErr: Error = APIError.noData
        for inst in ordered {
            guard let url = URL(string: "\(inst)\(path)") else { continue }
            do {
                var req = URLRequest(url: url)
                req.timeoutInterval = 15
                let (data, resp) = try await session.data(for: req)
                guard (resp as? HTTPURLResponse)?.statusCode == 200 else { continue }
                if inst != currentInstance {
                    currentInstance = inst
                    instanceStatus = inst
                        .replacingOccurrences(of: "https://", with: "")
                }
                return data
            } catch {
                lastErr = error
            }
        }
        throw lastErr
    }

    // MARK: - API
    func trending() async throws -> [InvidiousVideo] {
        let data = try await fetch(path: "/api/v1/trending?region=RU&type=default")
        return try decoder.decode([InvidiousVideo].self, from: data)
    }

    func search(query: String, page: Int = 1) async throws -> [InvidiousVideo] {
        let q = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        let data = try await fetch(path: "/api/v1/search?q=\(q)&page=\(page)&type=video&sort_by=relevance")
        return try decoder.decode([InvidiousVideo].self, from: data)
    }

    func videoDetail(videoId: String) async throws -> InvidiousVideoDetail {
        // local=true — Invidious proxies stream URLs through itself, preventing IP-based blocking
        // hlsUrl — HLS manifest, best for AVPlayer (native iOS format, auto quality switching)
        let data = try await fetch(path: "/api/v1/videos/\(videoId)?local=true")
        return try decoder.decode(InvidiousVideoDetail.self, from: data)
    }

    func channelVideos(channelId: String, page: Int = 1) async throws -> [InvidiousVideo] {
        let data = try await fetch(path: "/api/v1/channels/\(channelId)/videos?page=\(page)")
        struct R: Codable { let videos: [InvidiousVideo] }
        return try decoder.decode(R.self, from: data).videos
    }

    func login(username: String, password: String) async throws -> String {
        if currentInstance.isEmpty { await ensureInstance() }
        guard !currentInstance.isEmpty else { throw APIError.noData }
        var req = URLRequest(url: URL(string: "\(currentInstance)/api/v1/auth/login")!)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try encoder.encode(["username": username, "password": password])
        let (data, resp) = try await session.data(for: req)
        guard (resp as? HTTPURLResponse)?.statusCode == 200 else { throw APIError.authFailed }
        struct TR: Codable { let token: String }
        return try decoder.decode(TR.self, from: data).token
    }

    func register(username: String, password: String) async throws {
        if currentInstance.isEmpty { await ensureInstance() }
        guard !currentInstance.isEmpty else { throw APIError.noData }
        var req = URLRequest(url: URL(string: "\(currentInstance)/api/v1/auth/register")!)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try encoder.encode(["username": username, "password": password, "email": ""])
        let (_, resp) = try await session.data(for: req)
        let code = (resp as? HTTPURLResponse)?.statusCode ?? 0
        guard code == 200 || code == 201 else { throw APIError.authFailed }
    }

    // Shared coder instances (reuse = perf win)
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()

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

// Safe array subscript
private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
