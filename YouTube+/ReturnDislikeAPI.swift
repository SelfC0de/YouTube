import Foundation

final class ReturnDislikeAPI {
    static let shared = ReturnDislikeAPI()
    private let base = "https://returnyoutubedislikeapi.com"
    private let session = DoHResolver.shared.makeSession()
    private init() {}

    func dislikes(videoId: String) async -> DislikeData? {
        guard let url = URL(string: "\(base)/votes?videoId=\(videoId)") else { return nil }
        do {
            let (data, _) = try await session.data(from: url)
            return try JSONDecoder().decode(DislikeData.self, from: data)
        } catch {
            return nil
        }
    }
}
