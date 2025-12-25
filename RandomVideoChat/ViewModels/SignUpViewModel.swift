import SwiftUI
import Foundation
import AuthenticationServices
import FirebaseAuth
import FirebaseFirestore

@MainActor
class SignUpViewModel: ObservableObject {
    // MARK: - Published Properties

    @Published var selectedYear: Int = 2000
    @Published var isLoading = false
    @Published var showError = false
    @Published var errorMessage = ""
    @Published var showYearPicker = false
    @Published var isAuthenticated = false

    // MARK: - Private Properties

    private var currentNonce: String?
    private let minimumAge = 18

    // MARK: - Computed Properties

    var currentYear: Int {
        Calendar.current.component(.year, from: Date())
    }

    var birthDate: Date {
        let components = DateComponents(year: selectedYear, month: 1, day: 1)
        return Calendar.current.date(from: components) ?? Date()
    }

    var userAge: Int {
        currentYear - selectedYear
    }

    var isValidAge: Bool {
        userAge >= minimumAge
    }

    var minYear: Int {
        currentYear - 100
    }

    var maxYear: Int {
        currentYear - minimumAge
    }

    // MARK: - Apple Sign In

    func prepareAppleSignInRequest(_ request: ASAuthorizationAppleIDRequest) {
        let nonce = CryptoUtils.randomNonceString()
        currentNonce = nonce
        request.nonce = CryptoUtils.sha256(nonce)
        request.requestedScopes = [.fullName, .email]
    }

    func handleAppleSignIn(result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authorization):
            guard let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential else {
                setError("Failed to get Apple ID credential")
                return
            }

            guard let identityToken = appleIDCredential.identityToken,
                  let idTokenString = String(data: identityToken, encoding: .utf8) else {
                setError("Failed to get identity token")
                return
            }

            guard let nonce = currentNonce else {
                setError("Invalid authentication state")
                return
            }

            let credential = OAuthProvider.credential(
                withProviderID: "apple.com",
                idToken: idTokenString,
                rawNonce: nonce
            )

            signInWithFirebase(credential: credential, appleCredential: appleIDCredential)

        case .failure(let error):
            ErrorHandler.shared.log(AuthError.appleSignInFailed(reason: error.localizedDescription), context: "SignUpViewModel")
            setError("Apple Sign In failed: \(error.localizedDescription)")
        }
    }

    private func signInWithFirebase(credential: AuthCredential, appleCredential: ASAuthorizationAppleIDCredential) {
        isLoading = true

        Auth.auth().signIn(with: credential) { [weak self] authResult, error in
            guard let self = self else { return }

            if let error = error {
                ErrorHandler.shared.log(AuthError.signInFailed(underlying: error), context: "SignUpViewModel.signInWithFirebase")
                self.setError("Firebase sign in failed: \(error.localizedDescription)")
                return
            }

            guard let user = authResult?.user else {
                ErrorHandler.shared.log(AuthError.noUserReturned, context: "SignUpViewModel.signInWithFirebase")
                self.setError("No user returned from authentication")
                return
            }

            self.saveUserToFirestore(user: user, appleCredential: appleCredential)
        }
    }

    private func saveUserToFirestore(user: FirebaseAuth.User, appleCredential: ASAuthorizationAppleIDCredential) {
        let db = Firestore.firestore()
        let userRef = db.collection("users").document(user.uid)

        userRef.getDocument { [weak self] document, error in
            guard let self = self else { return }

            let existingHeartCount = document?.data()?["heartCount"] as? Int

            let userData: [String: Any] = [
                "uid": user.uid,
                "email": user.email ?? "",
                "displayName": user.displayName ?? self.formatPersonName(appleCredential.fullName) ?? "",
                "birthDate": Timestamp(date: self.birthDate),
                "heartCount": existingHeartCount ?? 3,
                "ageVerified": true,
                "authProvider": "apple.com",
                "createdAt": document?.exists == true ? (document?.data()?["createdAt"] as? Timestamp ?? Timestamp()) : Timestamp(),
                "updatedAt": Timestamp(),
                "blockedUsers": document?.data()?["blockedUsers"] as? [String] ?? []
            ]

            userRef.setData(userData, merge: true) { [weak self] error in
                Task { @MainActor in
                    guard let self = self else { return }

                    if let error = error {
                        #if DEBUG
                        print("❌ Failed to save user data: \(error.localizedDescription)")
                        #endif
                        self.setError("사용자 데이터 저장 실패")
                    } else {
                        #if DEBUG
                        print("✅ User data saved successfully")
                        #endif
                        UserManager.shared.loadCurrentUser(uid: user.uid)
                        self.isAuthenticated = true
                        self.isLoading = false
                    }
                }
            }
        }
    }

    // MARK: - Guest Login

    func handleGuestLogin() {
        isLoading = true

        Auth.auth().signInAnonymously { [weak self] authResult, error in
            guard let self = self else { return }

            if let error = error {
                ErrorHandler.shared.log(AuthError.signInFailed(underlying: error), context: "SignUpViewModel.handleGuestLogin")
                self.setError("게스트 로그인 실패: \(error.localizedDescription)")
                return
            }

            guard let user = authResult?.user else {
                ErrorHandler.shared.log(AuthError.noUserReturned, context: "SignUpViewModel.handleGuestLogin")
                self.setError("사용자 정보를 가져올 수 없습니다.")
                return
            }

            self.saveGuestUserToFirestore(user: user)
        }
    }

    private func saveGuestUserToFirestore(user: FirebaseAuth.User) {
        let db = Firestore.firestore()
        let userData: [String: Any] = [
            "uid": user.uid,
            "displayName": "Guest",
            "birthDate": Timestamp(date: birthDate),
            "heartCount": 10,
            "ageVerified": true,
            "authProvider": "anonymous",
            "createdAt": Timestamp(),
            "updatedAt": Timestamp(),
            "blockedUsers": [],
            "isGuest": true
        ]

        db.collection("users").document(user.uid).setData(userData) { [weak self] error in
            Task { @MainActor in
                guard let self = self else { return }

                if let error = error {
                    self.setError("사용자 데이터 저장 실패: \(error.localizedDescription)")
                } else {
                    UserManager.shared.loadCurrentUser(uid: user.uid)
                    self.isAuthenticated = true
                }
                self.isLoading = false
            }
        }
    }

    // MARK: - Helper Methods

    private func formatPersonName(_ personName: PersonNameComponents?) -> String? {
        guard let personName = personName else { return nil }
        let formatter = PersonNameComponentsFormatter()
        formatter.style = .default
        return formatter.string(from: personName)
    }

    private func setError(_ message: String) {
        Task { @MainActor in
            errorMessage = message
            showError = true
            isLoading = false
        }
    }
}
