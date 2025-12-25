import Foundation

// MARK: - Base App Error Protocol

protocol AppErrorProtocol: Error, LocalizedError {
    var userMessage: String { get }
    var logMessage: String { get }
}

// MARK: - Auth Errors

enum AuthError: AppErrorProtocol {
    case noUserReturned
    case noAuthenticatedUser
    case signInFailed(underlying: Error)
    case signOutFailed(underlying: Error)
    case deleteAccountFailed(underlying: Error)
    case requiresReAuthentication
    case appleSignInFailed(reason: String)
    case invalidCredentials

    var userMessage: String {
        switch self {
        case .noUserReturned, .noAuthenticatedUser:
            return "로그인 정보를 찾을 수 없습니다. 다시 로그인해주세요."
        case .signInFailed:
            return "로그인에 실패했습니다. 잠시 후 다시 시도해주세요."
        case .signOutFailed:
            return "로그아웃에 실패했습니다."
        case .deleteAccountFailed:
            return "계정 삭제에 실패했습니다. 고객센터에 문의해주세요."
        case .requiresReAuthentication:
            return "보안을 위해 다시 로그인이 필요합니다."
        case .appleSignInFailed:
            return "Apple 로그인에 실패했습니다. 다시 시도해주세요."
        case .invalidCredentials:
            return "잘못된 인증 정보입니다."
        }
    }

    var logMessage: String {
        switch self {
        case .noUserReturned:
            return "Auth: No user returned from sign in"
        case .noAuthenticatedUser:
            return "Auth: No authenticated user found"
        case .signInFailed(let error):
            return "Auth: Sign in failed - \(error.localizedDescription)"
        case .signOutFailed(let error):
            return "Auth: Sign out failed - \(error.localizedDescription)"
        case .deleteAccountFailed(let error):
            return "Auth: Delete account failed - \(error.localizedDescription)"
        case .requiresReAuthentication:
            return "Auth: Re-authentication required"
        case .appleSignInFailed(let reason):
            return "Auth: Apple sign in failed - \(reason)"
        case .invalidCredentials:
            return "Auth: Invalid credentials"
        }
    }

    var errorDescription: String? { userMessage }
}

// MARK: - Network Errors

enum NetworkError: AppErrorProtocol {
    case noConnection
    case timeout
    case serverError(statusCode: Int)
    case invalidResponse
    case requestFailed(underlying: Error)

    var userMessage: String {
        switch self {
        case .noConnection:
            return "인터넷 연결을 확인해주세요."
        case .timeout:
            return "요청 시간이 초과되었습니다. 다시 시도해주세요."
        case .serverError:
            return "서버에 문제가 발생했습니다. 잠시 후 다시 시도해주세요."
        case .invalidResponse:
            return "서버 응답을 처리할 수 없습니다."
        case .requestFailed:
            return "요청에 실패했습니다. 다시 시도해주세요."
        }
    }

    var logMessage: String {
        switch self {
        case .noConnection:
            return "Network: No connection"
        case .timeout:
            return "Network: Request timeout"
        case .serverError(let code):
            return "Network: Server error with status code \(code)"
        case .invalidResponse:
            return "Network: Invalid response"
        case .requestFailed(let error):
            return "Network: Request failed - \(error.localizedDescription)"
        }
    }

    var errorDescription: String? { userMessage }
}

// MARK: - Matching Errors

enum MatchingError: AppErrorProtocol, Equatable {
    case alreadyMatching
    case matchingFailed
    case opponentDisconnected
    case queueRegistrationFailed(underlying: Error)
    case noOpponentFound
    case callSetupFailed
    case notAuthenticated
    case networkError
    case queueFull
    case serverError
    case timeout
    case cancelled

    static func == (lhs: MatchingError, rhs: MatchingError) -> Bool {
        switch (lhs, rhs) {
        case (.alreadyMatching, .alreadyMatching),
             (.matchingFailed, .matchingFailed),
             (.opponentDisconnected, .opponentDisconnected),
             (.noOpponentFound, .noOpponentFound),
             (.callSetupFailed, .callSetupFailed),
             (.notAuthenticated, .notAuthenticated),
             (.networkError, .networkError),
             (.queueFull, .queueFull),
             (.serverError, .serverError),
             (.timeout, .timeout),
             (.cancelled, .cancelled):
            return true
        case (.queueRegistrationFailed, .queueRegistrationFailed):
            return true
        default:
            return false
        }
    }

    var userMessage: String {
        switch self {
        case .alreadyMatching:
            return "이미 매칭 중입니다."
        case .matchingFailed:
            return "매칭에 실패했습니다. 다시 시도해주세요."
        case .opponentDisconnected:
            return "상대방이 연결을 종료했습니다."
        case .queueRegistrationFailed:
            return "매칭 대기열 등록에 실패했습니다."
        case .noOpponentFound:
            return "매칭 상대를 찾을 수 없습니다."
        case .callSetupFailed:
            return "통화 연결에 실패했습니다."
        case .notAuthenticated:
            return "로그인이 필요합니다."
        case .networkError:
            return "네트워크 오류가 발생했습니다."
        case .queueFull:
            return "대기열이 가득 찼습니다. 잠시 후 다시 시도해주세요."
        case .serverError:
            return "서버 오류가 발생했습니다."
        case .timeout:
            return "매칭 시간이 초과되었습니다."
        case .cancelled:
            return "매칭이 취소되었습니다."
        }
    }

    var logMessage: String {
        switch self {
        case .alreadyMatching:
            return "Matching: Already in matching state"
        case .matchingFailed:
            return "Matching: Failed to find match"
        case .opponentDisconnected:
            return "Matching: Opponent disconnected"
        case .queueRegistrationFailed(let error):
            return "Matching: Queue registration failed - \(error.localizedDescription)"
        case .noOpponentFound:
            return "Matching: No opponent found in queue"
        case .callSetupFailed:
            return "Matching: Call setup failed"
        case .notAuthenticated:
            return "Matching: User not authenticated"
        case .networkError:
            return "Matching: Network error"
        case .queueFull:
            return "Matching: Queue full"
        case .serverError:
            return "Matching: Server error"
        case .timeout:
            return "Matching: Timeout"
        case .cancelled:
            return "Matching: Cancelled"
        }
    }

    var errorDescription: String? { userMessage }
}

// MARK: - Store Errors

enum StoreError: AppErrorProtocol {
    case productNotFound
    case purchaseFailed(underlying: Error)
    case purchaseCancelled
    case notAuthorized
    case networkError

    var userMessage: String {
        switch self {
        case .productNotFound:
            return "상품을 찾을 수 없습니다."
        case .purchaseFailed:
            return "구매에 실패했습니다. 다시 시도해주세요."
        case .purchaseCancelled:
            return "구매가 취소되었습니다."
        case .notAuthorized:
            return "구매 권한이 없습니다. 설정을 확인해주세요."
        case .networkError:
            return "네트워크 오류로 구매할 수 없습니다."
        }
    }

    var logMessage: String {
        switch self {
        case .productNotFound:
            return "Store: Product not found"
        case .purchaseFailed(let error):
            return "Store: Purchase failed - \(error.localizedDescription)"
        case .purchaseCancelled:
            return "Store: Purchase cancelled by user"
        case .notAuthorized:
            return "Store: Not authorized for purchases"
        case .networkError:
            return "Store: Network error during purchase"
        }
    }

    var errorDescription: String? { userMessage }
}

// MARK: - Data Errors

enum DataError: AppErrorProtocol {
    case saveFailed(underlying: Error)
    case loadFailed(underlying: Error)
    case invalidData
    case notFound

    var userMessage: String {
        switch self {
        case .saveFailed:
            return "데이터 저장에 실패했습니다."
        case .loadFailed:
            return "데이터를 불러올 수 없습니다."
        case .invalidData:
            return "잘못된 데이터입니다."
        case .notFound:
            return "데이터를 찾을 수 없습니다."
        }
    }

    var logMessage: String {
        switch self {
        case .saveFailed(let error):
            return "Data: Save failed - \(error.localizedDescription)"
        case .loadFailed(let error):
            return "Data: Load failed - \(error.localizedDescription)"
        case .invalidData:
            return "Data: Invalid data format"
        case .notFound:
            return "Data: Not found"
        }
    }

    var errorDescription: String? { userMessage }
}

// MARK: - Error Handler Utility

final class ErrorHandler {
    static let shared = ErrorHandler()
    private init() {}

    /// Convert any error to user-friendly message
    func userMessage(for error: Error) -> String {
        if let appError = error as? AppErrorProtocol {
            return appError.userMessage
        }

        // Firebase Auth errors
        let nsError = error as NSError
        if nsError.domain == "FIRAuthErrorDomain" {
            return mapFirebaseAuthError(code: nsError.code)
        }

        // Default fallback
        return "오류가 발생했습니다. 다시 시도해주세요."
    }

    /// Log error for debugging
    func log(_ error: Error, context: String = "") {
        #if DEBUG
        if let appError = error as? AppErrorProtocol {
            print("❌ [\(context)] \(appError.logMessage)")
        } else {
            print("❌ [\(context)] \(error.localizedDescription)")
        }
        #endif
    }

    /// Handle error with both logging and user message
    func handle(_ error: Error, context: String = "") -> String {
        log(error, context: context)
        return userMessage(for: error)
    }

    private func mapFirebaseAuthError(code: Int) -> String {
        switch code {
        case 17005:
            return "이 계정은 비활성화되었습니다."
        case 17008:
            return "잘못된 이메일 형식입니다."
        case 17009:
            return "비밀번호가 틀렸습니다."
        case 17011:
            return "등록되지 않은 이메일입니다."
        case 17020:
            return "네트워크 연결을 확인해주세요."
        case 17026:
            return "비밀번호가 너무 짧습니다."
        default:
            return "인증에 실패했습니다. 다시 시도해주세요."
        }
    }
}
