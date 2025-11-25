import Foundation

// MARK: - Token Provider Error
enum TokenProviderError: Error, LocalizedError {
    case notConfigured
    case invalidEndpoint
    case networkError(Error)
    case invalidResponse
    case serverError(statusCode: Int)
    case tokenMissing
    case timeout

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "Token endpoint not configured. Set AGORA_TOKEN_ENDPOINT in Info.plist"
        case .invalidEndpoint:
            return "Invalid token endpoint URL"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .invalidResponse:
            return "Invalid response from token server"
        case .serverError(let code):
            return "Token server error: HTTP \(code)"
        case .tokenMissing:
            return "Token missing in server response"
        case .timeout:
            return "Token request timed out"
        }
    }
}

// MARK: - Token Response
struct TokenResponse: Codable {
    let token: String
    let expiresIn: Int?        // Seconds until expiration
    let uid: UInt?

    enum CodingKeys: String, CodingKey {
        case token
        case expiresIn = "expires_in"
        case uid
    }
}

// MARK: - Token Cache Entry
private struct CachedToken {
    let token: String
    let channel: String
    let uid: UInt
    let fetchedAt: Date
    let expiresIn: TimeInterval

    var isExpired: Bool {
        // Consider expired 5 minutes before actual expiration for safety
        let safetyMargin: TimeInterval = 300
        return Date().timeIntervalSince(fetchedAt) > (expiresIn - safetyMargin)
    }
}

// MARK: - Token Provider
/// Production-grade Token Provider for Agora RTC
/// Features:
/// - Automatic token caching with expiration
/// - Retry logic with exponential backoff
/// - Request deduplication
/// - Proactive token refresh
final class TokenProvider {

    // MARK: - Singleton
    static let shared = TokenProvider()

    // MARK: - Configuration
    private struct Config {
        static let requestTimeout: TimeInterval = 10.0
        static let maxRetries: Int = 3
        static let baseRetryDelay: TimeInterval = 1.0
        static let defaultTokenLifetime: TimeInterval = 3600  // 1 hour default
        static let refreshThreshold: TimeInterval = 300       // Refresh 5 min before expiry
    }

    // MARK: - Properties
    private let session: URLSession
    private let endpoint: String?
    private let useToken: Bool

    // Token cache
    private var tokenCache: [String: CachedToken] = [:]
    private let cacheLock = NSLock()

    // Pending requests (for deduplication)
    private var pendingRequests: [String: [(Result<String, TokenProviderError>) -> Void]] = [:]
    private let requestLock = NSLock()

    // MARK: - Initialization
    private init() {
        // Configure URL session with timeout
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = Config.requestTimeout
        config.timeoutIntervalForResource = Config.requestTimeout * 2
        self.session = URLSession(configuration: config)

        // Load configuration from Info.plist
        self.endpoint = Bundle.main.object(forInfoDictionaryKey: "AGORA_TOKEN_ENDPOINT") as? String
        // In production, tokens should be required by default
        self.useToken = (Bundle.main.object(forInfoDictionaryKey: "USE_AGORA_TOKEN") as? Bool) ?? true

        #if DEBUG
        print("🔐 TokenProvider initialized")
        print("   Endpoint configured: \(endpoint != nil)")
        print("   Token required: \(useToken)")
        #endif
    }

    // MARK: - Public API

    /// Check if token authentication is enabled
    func isEnabled() -> Bool {
        return useToken
    }

    /// Check if token provider is properly configured
    func isConfigured() -> Bool {
        guard let endpoint = endpoint, !endpoint.isEmpty else { return false }
        return URL(string: endpoint) != nil
    }

    /// Fetch token with caching and retry logic
    /// - Parameters:
    ///   - channel: Agora channel name
    ///   - uid: Local user ID
    ///   - completion: Callback with token or nil on failure
    func fetchToken(channel: String, uid: UInt, completion: @escaping (String?) -> Void) {
        fetchTokenWithResult(channel: channel, uid: uid) { result in
            switch result {
            case .success(let token):
                completion(token)
            case .failure(let error):
                #if DEBUG
                print("❌ Token fetch failed: \(error.localizedDescription)")
                #endif
                completion(nil)
            }
        }
    }

    /// Fetch token with detailed error handling
    func fetchTokenWithResult(
        channel: String,
        uid: UInt,
        completion: @escaping (Result<String, TokenProviderError>) -> Void
    ) {
        // If tokens not required, return immediately
        guard useToken else {
            completion(.success(""))
            return
        }

        // Check if configured
        guard isConfigured() else {
            completion(.failure(.notConfigured))
            return
        }

        // Check cache first
        let cacheKey = "\(channel)_\(uid)"
        if let cached = getCachedToken(for: cacheKey), !cached.isExpired {
            #if DEBUG
            print("✅ Using cached token for \(channel)")
            #endif
            completion(.success(cached.token))
            return
        }

        // Deduplicate concurrent requests
        requestLock.lock()
        if var pending = pendingRequests[cacheKey] {
            pending.append(completion)
            pendingRequests[cacheKey] = pending
            requestLock.unlock()
            #if DEBUG
            print("⏳ Deduplicating token request for \(channel)")
            #endif
            return
        }
        pendingRequests[cacheKey] = [completion]
        requestLock.unlock()

        // Perform the fetch with retry
        performFetchWithRetry(channel: channel, uid: uid, attempt: 0) { [weak self] result in
            guard let self = self else { return }

            // Cache successful result
            if case .success(let token) = result {
                self.cacheToken(token, channel: channel, uid: uid)
            }

            // Notify all pending completions
            self.requestLock.lock()
            let completions = self.pendingRequests.removeValue(forKey: cacheKey) ?? []
            self.requestLock.unlock()

            for completion in completions {
                DispatchQueue.main.async {
                    completion(result)
                }
            }
        }
    }

    /// Proactively refresh token before expiration
    func refreshTokenIfNeeded(channel: String, uid: UInt) {
        let cacheKey = "\(channel)_\(uid)"

        guard let cached = getCachedToken(for: cacheKey) else { return }

        let timeUntilExpiry = cached.expiresIn - Date().timeIntervalSince(cached.fetchedAt)

        if timeUntilExpiry < Config.refreshThreshold {
            #if DEBUG
            print("🔄 Proactively refreshing token for \(channel)")
            #endif
            invalidateCachedToken(for: cacheKey)
            fetchTokenWithResult(channel: channel, uid: uid) { _ in }
        }
    }

    /// Clear all cached tokens
    func clearCache() {
        cacheLock.lock()
        tokenCache.removeAll()
        cacheLock.unlock()
    }

    // MARK: - Private Methods

    private func performFetchWithRetry(
        channel: String,
        uid: UInt,
        attempt: Int,
        completion: @escaping (Result<String, TokenProviderError>) -> Void
    ) {
        guard attempt < Config.maxRetries else {
            completion(.failure(.timeout))
            return
        }

        performSingleFetch(channel: channel, uid: uid) { [weak self] result in
            switch result {
            case .success:
                completion(result)

            case .failure(let error):
                // Retry on network errors
                if case .networkError = error, attempt < Config.maxRetries - 1 {
                    let delay = Config.baseRetryDelay * pow(2.0, Double(attempt))
                    #if DEBUG
                    print("🔄 Retrying token fetch in \(delay)s (attempt \(attempt + 1))")
                    #endif
                    DispatchQueue.global().asyncAfter(deadline: .now() + delay) {
                        self?.performFetchWithRetry(
                            channel: channel,
                            uid: uid,
                            attempt: attempt + 1,
                            completion: completion
                        )
                    }
                } else {
                    completion(result)
                }
            }
        }
    }

    private func performSingleFetch(
        channel: String,
        uid: UInt,
        completion: @escaping (Result<String, TokenProviderError>) -> Void
    ) {
        guard let endpoint = endpoint,
              var components = URLComponents(string: endpoint) else {
            completion(.failure(.invalidEndpoint))
            return
        }

        // Add query parameters
        var queryItems = components.queryItems ?? []
        queryItems.append(URLQueryItem(name: "channel", value: channel))
        queryItems.append(URLQueryItem(name: "uid", value: String(uid)))
        components.queryItems = queryItems

        guard let url = components.url else {
            completion(.failure(.invalidEndpoint))
            return
        }

        #if DEBUG
        print("🌐 Fetching token from: \(url.absoluteString)")
        #endif

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let task = session.dataTask(with: request) { data, response, error in
            // Network error
            if let error = error {
                completion(.failure(.networkError(error)))
                return
            }

            // Check HTTP status
            if let httpResponse = response as? HTTPURLResponse {
                guard (200...299).contains(httpResponse.statusCode) else {
                    completion(.failure(.serverError(statusCode: httpResponse.statusCode)))
                    return
                }
            }

            // Parse response
            guard let data = data else {
                completion(.failure(.invalidResponse))
                return
            }

            do {
                // Try to parse structured response
                let decoder = JSONDecoder()
                let tokenResponse = try decoder.decode(TokenResponse.self, from: data)

                guard !tokenResponse.token.isEmpty else {
                    completion(.failure(.tokenMissing))
                    return
                }

                #if DEBUG
                print("✅ Token received (expires in: \(tokenResponse.expiresIn ?? 3600)s)")
                #endif

                completion(.success(tokenResponse.token))
            } catch {
                // Try simple JSON format as fallback
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let token = json["token"] as? String, !token.isEmpty {
                    completion(.success(token))
                } else {
                    completion(.failure(.invalidResponse))
                }
            }
        }

        task.resume()
    }

    // MARK: - Cache Management

    private func getCachedToken(for key: String) -> CachedToken? {
        cacheLock.lock()
        defer { cacheLock.unlock() }
        return tokenCache[key]
    }

    private func cacheToken(_ token: String, channel: String, uid: UInt, expiresIn: TimeInterval? = nil) {
        let entry = CachedToken(
            token: token,
            channel: channel,
            uid: uid,
            fetchedAt: Date(),
            expiresIn: expiresIn ?? Config.defaultTokenLifetime
        )

        let cacheKey = "\(channel)_\(uid)"

        cacheLock.lock()
        tokenCache[cacheKey] = entry
        cacheLock.unlock()
    }

    private func invalidateCachedToken(for key: String) {
        cacheLock.lock()
        tokenCache.removeValue(forKey: key)
        cacheLock.unlock()
    }
}

// MARK: - Token Server Template (For Reference)
/*
 Token Server Endpoint Implementation (Node.js + Express example):

 const { RtcTokenBuilder, RtcRole } = require('agora-access-token');

 app.get('/token', (req, res) => {
   const { channel, uid } = req.query;

   if (!channel) {
     return res.status(400).json({ error: 'Channel name required' });
   }

   const appId = process.env.AGORA_APP_ID;
   const appCertificate = process.env.AGORA_APP_CERTIFICATE;
   const role = RtcRole.PUBLISHER;

   // Token expires in 1 hour
   const expirationTimeInSeconds = 3600;
   const currentTimestamp = Math.floor(Date.now() / 1000);
   const privilegeExpiredTs = currentTimestamp + expirationTimeInSeconds;

   const token = RtcTokenBuilder.buildTokenWithUid(
     appId,
     appCertificate,
     channel,
     parseInt(uid) || 0,
     role,
     privilegeExpiredTs
   );

   res.json({
     token,
     expires_in: expirationTimeInSeconds,
     uid: parseInt(uid) || 0
   });
 });
*/
