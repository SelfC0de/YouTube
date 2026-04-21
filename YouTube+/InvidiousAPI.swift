import Foundation

@MainActor
final class InvidiousAPI: ObservableObject {
    static let shared = InvidiousAPI()

    @Published var currentInstance: String = ""
    @Published var instanceStatus: String = "Поиск..."

    // MARK: - Свой сервер (приоритет)
    private enum Primary {
        static let url  = "https://youtubeplus.ydns.eu"
        static let user = "admin"
        static let pass = "ea399iEa2zEP9KmW3L"
        static var auth: String {
            "Basic " + Data("\(user):\(pass)".utf8).base64EncodedString()
        }
    }

    // MARK: - Публичные инстансы (fallback)
    private static let publicInstances: [String] = [
        "https://inv.nadeko.net",
        "https://invidious.nerdvpn.de",
        "https://yewtu.be",
        "https://invidious.privacydev.net",
        "https://invidious.fdn.fr",
        "https://yt.cdaut.de",
        "https://iv.melmac.space",
        "https://invidious.lunar.icu"
    ]

    private let session: URLSession = {
        let cfg = URLSessionConfiguration.default
        cfg.timeoutIntervalForRequest = 20
        cfg.timeoutIntervalForResource = 60
        cfg.urlCache = nil
        cfg.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        return URLSession(configuration: cfg, delegate: TrustAllDelegate(), delegateQueue: nil)
    }()

    private var instancesFromAPI: [String] = []
    private var isSearching = false
    private var lastInstanceFetch: Date?
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()

    private init() {}

    // MARK: - Ensure instance
    func ensureInstance() async {
        guard currentInstance.isEmpty, !isSearching else { return }
        isSearching = true
        defer { isSearching = false }
        instanceStatus = "Подключение..."

        // Пробуем свой сервер первым
        if await pingOwn() {
            currentInstance = Primary.url
            instanceStatus = "youtubeplus.ydns.eu (свой)"
            return
        }

        // Fallback — публичные параллельно
        instanceStatus = "Поиск публичного..."
        await fetchInstanceList()

        let all = instancesFromAPI.isEmpty ? InvidiousAPI.publicInstances : instancesFromAPI
        let found = await withTaskGroup(of: (String, Double)?.self) { group in
            for inst in all {
                group.addTask { [inst] in
                    let t = Date()
                    guard await self.pingPublic(inst) else { return nil }
                    return (inst, Date().timeIntervalSince(t))
                }
            }
            var best: (String, Double)? = nil
            for await r in group {
                guard let r else { continue }
                if best == nil || r.1 < best!.1 { best = r }
            }
            return best?.0
        }

        if let inst = found {
            currentInstance = inst
            instanceStatus = inst.replacingOccurrences(of: "https://", with: "")
        } else {
            instanceStatus = "Нет подключения"
        }
    }

    private func pingOwn() async -> Bool {
        guard let url = URL(string: "\(Primary.url)/api/v1/search?q=ping") else { return false }
        do {
            var req = URLRequest(url: url)
            req.setValue(Primary.auth, forHTTPHeaderField: "Authorization")
            req.timeoutInterval = 10
            let (_, resp) = try await session.data(for: req)
            return (resp as? HTTPURLResponse)?.statusCode == 200
        } catch { return false }
    }

    private func pingPublic(_ instance: String) async -> Bool {
        guard let url = URL(string: "\(instance)/api/v1/stats") else { return false }
        do {
            var req = URLRequest(url: url); req.timeoutInterval = 8
            let (_, resp) = try await session.data(for: req)
            return (resp as? HTTPURLResponse)?.statusCode == 200
        } catch { return false }
    }

    private func fetchInstanceList() async {
        if let last = lastInstanceFetch, Date().timeIntervalSince(last) < 3600 { return }
        guard let url = URL(string: "https://api.invidious.io/instances.json?sort_by=health") else { return }
        do {
            var req = URLRequest(url: url); req.timeoutInterval = 10
            let (data, _) = try await session.data(for: req)
            if let arr = try? JSONSerialization.jsonObject(with: data) as? [[Any]] {
                instancesFromAPI = arr.compactMap { pair in
                    guard let info = pair[safe: 1] as? [String: Any],
                          let uri = info["uri"] as? String,
                          uri.hasPrefix("https://") else { return nil }
                    return uri
                }
                lastInstanceFetch = Date()
            }
        } catch {}
    }

    func resetAndFind() async {
        currentInstance = ""; isSearching = false
        instancesFromAPI = []; lastInstanceFetch = nil
        await ensureInstance()
    }

    // MARK: - Core fetch
    func fetch(path: String) async throws -> Data {
        if currentInstance.isEmpty { await ensureInstance() }

        // Всегда пробуем свой сервер первым
        if let data = try? await fetchFrom(Primary.url, path: path, auth: Primary.auth) {
            if currentInstance != Primary.url {
                currentInstance = Primary.url
                instanceStatus = "youtubeplus.ydns.eu (свой)"
            }
            return data
        }

        // Fallback публичные
        let all = ([currentInstance] + InvidiousAPI.publicInstances).filter { !$0.isEmpty }
        var lastErr: Error = APIError.noData
        for inst in all where inst != Primary.url {
            do {
                let data = try await fetchFrom(inst, path: path, auth: nil)
                if inst != currentInstance {
                    currentInstance = inst
                    instanceStatus = inst.replacingOccurrences(of: "https://", with: "")
                }
                return data
            } catch { lastErr = error }
        }
        throw lastErr
    }

    private func fetchFrom(_ base: String, path: String, auth: String?) async throws -> Data {
        guard let url = URL(string: "\(base)\(path)") else { throw APIError.noData }
        var req = URLRequest(url: url)
        req.timeoutInterval = 20
        if let auth { req.setValue(auth, forHTTPHeaderField: "Authorization") }
        let (data, resp) = try await session.data(for: req)
        guard (resp as? HTTPURLResponse)?.statusCode == 200 else { throw APIError.noData }
        return data
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
        let isOwn = currentInstance == Primary.url
        var req = URLRequest(url: URL(string: "\(currentInstance)/api/v1/auth/login")!)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if isOwn { req.setValue(Primary.auth, forHTTPHeaderField: "Authorization") }
        req.httpBody = try encoder.encode(["username": username, "password": password])
        let (data, resp) = try await session.data(for: req)
        guard (resp as? HTTPURLResponse)?.statusCode == 200 else { throw APIError.authFailed }
        struct TR: Codable { let token: String }
        return try decoder.decode(TR.self, from: data).token
    }

    func register(username: String, password: String) async throws {
        if currentInstance.isEmpty { await ensureInstance() }
        let isOwn = currentInstance == Primary.url
        var req = URLRequest(url: URL(string: "\(currentInstance)/api/v1/auth/register")!)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if isOwn { req.setValue(Primary.auth, forHTTPHeaderField: "Authorization") }
        req.httpBody = try encoder.encode(["username": username, "password": password, "email": ""])
        let (_, resp) = try await session.data(for: req)
        let code = (resp as? HTTPURLResponse)?.statusCode ?? 0
        guard code == 200 || code == 201 else { throw APIError.authFailed }
    }

    enum APIError: LocalizedError {
        case authFailed, noData
        var errorDescription: String? {
            switch self {
            case .authFailed: return "Ошибка авторизации"
            case .noData: return "Нет подключения"
            }
        }
    }
}

// Trust self-signed SSL certificates (needed for own server)
private final class TrustAllDelegate: NSObject, URLSessionDelegate {
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

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
