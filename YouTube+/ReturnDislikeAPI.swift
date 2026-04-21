import Foundation

final class ReturnDislikeAPI {
    static let shared = ReturnDislikeAPI()
    private let base = "https://returnyoutubedislikeapi.com"
    private init() {}

    func dislikes(videoId: String) async -> DislikeData? {
        guard let url = URL(string: "\(base)/votes?videoId=\(videoId)") else { return nil }
        do {
            let (data, _) = try await DoHResolver.shared.dataBypassingDNS(for: url)
            return try? JSONDecoder().decode(DislikeData.self, from: data)
        } catch { return nil }
    }
}
