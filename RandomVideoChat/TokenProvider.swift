import Foundation

final class TokenProvider {
    static let shared = TokenProvider()

    private let session: URLSession
    private let endpoint: String?
    private let useToken: Bool

    private init() {
        session = URLSession(configuration: .default)
        endpoint = Bundle.main.object(forInfoDictionaryKey: "AGORA_TOKEN_ENDPOINT") as? String
        useToken = (Bundle.main.object(forInfoDictionaryKey: "USE_AGORA_TOKEN") as? Bool) ?? true
    }

    func isEnabled() -> Bool { useToken }

    func fetchToken(channel: String, uid: UInt, completion: @escaping (String?) -> Void) {
        guard useToken else { completion(nil); return }
        guard let endpoint = endpoint, !endpoint.isEmpty else {
            print("⚠️ Token endpoint not configured. Proceeding without token.")
            completion(nil)
            return
        }
        var comps = URLComponents(string: endpoint)
        var items = comps?.queryItems ?? []
        items.append(URLQueryItem(name: "channel", value: channel))
        items.append(URLQueryItem(name: "uid", value: String(uid)))
        comps?.queryItems = items
        guard let url = comps?.url else { completion(nil); return }

        let task = session.dataTask(with: url) { data, _, error in
            if let error = error {
                print("❌ Token fetch error: \(error)")
                completion(nil)
                return
            }
            guard let data = data else { completion(nil); return }
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    let token = json["token"] as? String
                    completion(token)
                } else {
                    completion(nil)
                }
            } catch {
                print("❌ Token parse error: \(error)")
                completion(nil)
            }
        }
        task.resume()
    }
}

