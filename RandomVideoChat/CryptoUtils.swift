import Foundation
import CryptoKit

// MARK: - Crypto Utilities
/// Shared cryptographic utility functions for Apple Sign In authentication

enum CryptoUtils {

    /// Generates a cryptographically secure random nonce string
    /// - Parameter length: The desired length of the nonce (default: 32)
    /// - Returns: A random string suitable for use as a nonce
    static func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remainingLength = length

        while remainingLength > 0 {
            let randoms: [UInt8] = (0 ..< 16).map { _ in
                var random: UInt8 = 0
                let errorCode = SecRandomCopyBytes(kSecRandomDefault, 1, &random)
                if errorCode != errSecSuccess {
                    #if DEBUG
                    print("⚠️ SecRandomCopyBytes failed with OSStatus \(errorCode), retrying...")
                    #endif
                    // Retry instead of crashing
                    return UInt8.random(in: 0...255)
                }
                return random
            }

            for random in randoms {
                if remainingLength == 0 {
                    break
                }

                if random < charset.count {
                    result.append(charset[Int(random)])
                    remainingLength -= 1
                }
            }
        }

        return result
    }

    /// Computes SHA256 hash of the input string
    /// - Parameter input: The string to hash
    /// - Returns: Hexadecimal string representation of the hash
    static func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashedData = SHA256.hash(data: inputData)
        let hashString = hashedData.compactMap {
            String(format: "%02x", $0)
        }.joined()

        return hashString
    }
}
