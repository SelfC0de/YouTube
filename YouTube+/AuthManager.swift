import Foundation
import SwiftData

@MainActor
final class AuthManager: ObservableObject {
    static let shared = AuthManager()

    @Published var isLoggedIn: Bool = false
    @Published var username: String = ""
    @Published var token: String = ""

    private let tokenKey = "invidiousToken"
    private let usernameKey = "invidiousUsername"

    private init() {
        token = UserDefaults.standard.string(forKey: tokenKey) ?? ""
        username = UserDefaults.standard.string(forKey: usernameKey) ?? ""
        isLoggedIn = !token.isEmpty
    }

    func login(username: String, password: String) async throws {
        let t = try await InvidiousAPI.shared.login(username: username, password: password)
        self.token = t
        self.username = username
        self.isLoggedIn = true
        UserDefaults.standard.set(t, forKey: tokenKey)
        UserDefaults.standard.set(username, forKey: usernameKey)
    }

    func logout() {
        token = ""
        username = ""
        isLoggedIn = false
        UserDefaults.standard.removeObject(forKey: tokenKey)
        UserDefaults.standard.removeObject(forKey: usernameKey)
    }

    // MARK: - CSV Import from Google Takeout
    func importSubscriptionsFromCSV(data: Data, context: ModelContext) throws -> Int {
        guard let content = String(data: data, encoding: .utf8) else {
            throw ImportError.invalidFile
        }
        let lines = content.components(separatedBy: "\n").dropFirst() // skip header
        var count = 0
        for line in lines {
            let parts = line.components(separatedBy: ",")
            guard parts.count >= 3 else { continue }
            let channelId = parts[0].trimmingCharacters(in: .whitespacesAndNewlines)
            let channelUrl = parts[1].trimmingCharacters(in: .whitespacesAndNewlines)
            let channelName = parts[2].trimmingCharacters(in: .whitespacesAndNewlines.union(.init(charactersIn: "\"")))
            guard !channelId.isEmpty, channelId.hasPrefix("UC") else { continue }
            let _ = channelUrl
            let sub = LocalSubscription(channelId: channelId, channelName: channelName)
            context.insert(sub)
            count += 1
        }
        try context.save()
        return count
    }

    enum ImportError: LocalizedError {
        case invalidFile
        var errorDescription: String? { "Неверный формат файла" }
    }
}
