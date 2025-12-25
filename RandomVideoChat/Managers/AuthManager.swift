import Foundation
import Firebase
import FirebaseAuth
import AuthenticationServices

/// Handles authentication-related operations
class AuthManager: ObservableObject {
    static let shared = AuthManager()

    @Published var isAuthenticated: Bool = false
    @Published var currentUserId: String?

    private init() {
        updateAuthState()
        setupAuthStateListener()
    }

    // MARK: - Auth State

    private func setupAuthStateListener() {
        Auth.auth().addStateDidChangeListener { [weak self] _, user in
            self?.updateAuthState()
        }
    }

    private func updateAuthState() {
        let user = Auth.auth().currentUser
        isAuthenticated = user != nil
        currentUserId = user?.uid
    }

    /// Check if user is currently authenticated
    func checkAutoLoginStatus() -> Bool {
        return Auth.auth().currentUser != nil
    }

    /// Get current user ID
    func getCurrentUserId() -> String? {
        return Auth.auth().currentUser?.uid
    }

    // MARK: - Sign Out

    func signOut() {
        do {
            try Auth.auth().signOut()
            UserManager.shared.currentUser = nil
            UserManager.shared.clearRecentMatches()
            #if DEBUG
            print("✅ 로그아웃 완료")
            #endif
        } catch {
            #if DEBUG
            print("❌ 로그아웃 실패: \(error.localizedDescription)")
            #endif
        }
    }

    // MARK: - Anonymous Sign In

    func signInAnonymously(completion: @escaping (Result<String, Error>) -> Void) {
        Auth.auth().signInAnonymously { authResult, error in
            if let error = error {
                ErrorHandler.shared.log(AuthError.signInFailed(underlying: error), context: "signInAnonymously")
                completion(.failure(AuthError.signInFailed(underlying: error)))
                return
            }

            guard let user = authResult?.user else {
                ErrorHandler.shared.log(AuthError.noUserReturned, context: "signInAnonymously")
                completion(.failure(AuthError.noUserReturned))
                return
            }

            #if DEBUG
            print("✅ 익명 로그인 성공! User ID: \(user.uid)")
            #endif

            UserManager.shared.loadCurrentUser(uid: user.uid)
            completion(.success(user.uid))
        }
    }

    // MARK: - Account Deletion

    func deleteAccount(completion: @escaping (Result<Void, Error>) -> Void) {
        guard let currentUser = Auth.auth().currentUser else {
            ErrorHandler.shared.log(AuthError.noAuthenticatedUser, context: "deleteAccount")
            completion(.failure(AuthError.noAuthenticatedUser))
            return
        }

        let uid = currentUser.uid

        // Clean up user data first, then delete account
        UserManager.shared.cleanupUserData(uid: uid) { [weak self] cleanupResult in
            switch cleanupResult {
            case .success:
                self?.deleteFirebaseAccount(currentUser: currentUser, completion: completion)
            case .failure(let cleanupError):
                #if DEBUG
                print("⚠️ 데이터 삭제 실패했지만 계정 삭제 시도: \(cleanupError.localizedDescription)")
                #endif
                self?.deleteFirebaseAccount(currentUser: currentUser, completion: completion)
            }
        }
    }

    private func deleteFirebaseAccount(currentUser: FirebaseAuth.User, completion: @escaping (Result<Void, Error>) -> Void) {
        currentUser.delete { [weak self] error in
            if let error = error as NSError? {
                if error.code == AuthErrorCode.requiresRecentLogin.rawValue {
                    // Re-authenticate required
                    self?.reauthenticateWithApple { reauthResult in
                        switch reauthResult {
                        case .success:
                            Auth.auth().currentUser?.delete { deleteError in
                                if let deleteError = deleteError {
                                    completion(.failure(deleteError))
                                } else {
                                    self?.handleAccountDeletionSuccess()
                                    completion(.success(()))
                                }
                            }
                        case .failure(let reauthError):
                            completion(.failure(reauthError))
                        }
                    }
                } else {
                    completion(.failure(error))
                }
            } else {
                self?.handleAccountDeletionSuccess()
                completion(.success(()))
            }
        }
    }

    private func handleAccountDeletionSuccess() {
        #if DEBUG
        print("✅ 계정 삭제 성공")
        #endif
        UserManager.shared.currentUser = nil
        UserManager.shared.clearRecentMatches()
    }

    // MARK: - Apple Re-authentication

    private func reauthenticateWithApple(completion: @escaping (Result<Void, Error>) -> Void) {
        let nonce = CryptoUtils.randomNonceString()
        let request = ASAuthorizationAppleIDProvider().createRequest()
        request.nonce = CryptoUtils.sha256(nonce)
        request.requestedScopes = []

        let coordinator = AppleReauthCoordinator(
            currentNonce: nonce,
            completion: completion
        )

        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = coordinator
        controller.presentationContextProvider = coordinator

        // Keep reference to prevent deallocation
        objc_setAssociatedObject(self, &AssociatedKeys.reauthCoordinator, coordinator, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)

        controller.performRequests()
    }
}

// MARK: - Associated Keys

private struct AssociatedKeys {
    static var reauthCoordinator = "reauthCoordinator"
}

// MARK: - Apple Re-authentication Coordinator

class AppleReauthCoordinator: NSObject, ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
    private let currentNonce: String
    private let completion: (Result<Void, Error>) -> Void

    init(currentNonce: String, completion: @escaping (Result<Void, Error>) -> Void) {
        self.currentNonce = currentNonce
        self.completion = completion
        super.init()
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        guard let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential,
              let identityToken = appleIDCredential.identityToken,
              let idTokenString = String(data: identityToken, encoding: .utf8) else {
            let error = AuthError.appleSignInFailed(reason: "Failed to get Apple ID token")
            ErrorHandler.shared.log(error, context: "AppleReauth")
            completion(.failure(error))
            return
        }

        let credential = OAuthProvider.credential(
            withProviderID: "apple.com",
            idToken: idTokenString,
            rawNonce: currentNonce
        )

        Auth.auth().currentUser?.reauthenticate(with: credential) { _, error in
            if let error = error {
                ErrorHandler.shared.log(AuthError.signInFailed(underlying: error), context: "AppleReauth")
                self.completion(.failure(AuthError.signInFailed(underlying: error)))
            } else {
                self.completion(.success(()))
            }
        }
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        ErrorHandler.shared.log(AuthError.appleSignInFailed(reason: error.localizedDescription), context: "AppleReauth")
        completion(.failure(AuthError.appleSignInFailed(reason: error.localizedDescription)))
    }

    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        if let windowScene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive }),
           let window = windowScene.windows.first(where: { $0.isKeyWindow }) {
            return window
        }

        if let window = UIApplication.shared.windows.first(where: { $0.isKeyWindow }) {
            return window
        }

        if let window = UIApplication.shared.windows.first {
            return window
        }

        let window = UIWindow(frame: UIScreen.main.bounds)
        window.makeKeyAndVisible()
        return window
    }
}
