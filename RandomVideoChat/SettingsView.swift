import SwiftUI
import FirebaseAuth
import FirebaseFirestore

@available(iOS 15.0, *)
struct SettingsView: View {
    @Environment(\.presentationMode) var presentationMode
    @State private var showDeleteAccountAlert = false
    @State private var isDeleting = false
    @State private var showDeleteResult = false
    @State private var deleteSuccess = false
    @State private var deleteMessage = ""
    @StateObject private var userManager = UserManager.shared
    
    var body: some View {
        NavigationView {
            List {
                Section {
                    // 이용약관
                    Link(destination: URL(string: "https://5sec-terms.web.app/terms")!) {
                        HStack {
                            Image(systemName: "doc.text")
                                .foregroundColor(.blue)
                            Text("이용약관")
                            Spacer()
                            Image(systemName: "arrow.up.right.square")
                                .foregroundColor(.gray)
                        }
                    }
                    
                    // 개인정보처리방침
                    Link(destination: URL(string: "https://5sec-terms.web.app/privacy")!) {
                        HStack {
                            Image(systemName: "lock.shield")
                                .foregroundColor(.blue)
                            Text("개인정보처리방침")
                            Spacer()
                            Image(systemName: "arrow.up.right.square")
                                .foregroundColor(.gray)
                        }
                    }
                    
                    // 문의하기
                    Link(destination: URL(string: "mailto:support@5sec-app.com")!) {
                        HStack {
                            Image(systemName: "envelope")
                                .foregroundColor(.blue)
                            Text("문의하기")
                            Spacer()
                            Image(systemName: "arrow.up.right.square")
                                .foregroundColor(.gray)
                        }
                    }
                } header: {
                    Text("정보")
                }
                
                Section {
                    // 로그아웃 버튼
                    Button(action: {
                        userManager.signOut()
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        HStack {
                            Image(systemName: "arrow.backward.circle")
                                .foregroundColor(.blue)
                            Text("로그아웃")
                                .foregroundColor(.blue)
                        }
                    }
                    
                    Button(action: { showDeleteAccountAlert = true }) {
                        HStack {
                            Image(systemName: "person.crop.circle.badge.minus")
                                .foregroundColor(.red)
                            Text("계정 삭제")
                                .foregroundColor(.red)
                        }
                    }
                    .disabled(isDeleting)
                } header: {
                    Text("계정 관리")
                }
            }
            .navigationTitle("설정")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("완료") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
        .onAppear {
            // 사용자 데이터 로드
            if let uid = Auth.auth().currentUser?.uid {
                userManager.loadCurrentUser(uid: uid)
            }
        }
        .alert("Delete Account", isPresented: $showDeleteAccountAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                deleteAccount()
            }
        } message: {
            Text("Are you sure you want to delete your account? This action cannot be undone. All your data will be permanently deleted.")
        }
        .alert("Account Deletion", isPresented: $showDeleteResult) {
            Button("OK") {
                if deleteSuccess {
                    presentationMode.wrappedValue.dismiss()
                }
            }
        } message: {
            Text(deleteMessage)
        }
    }
    
    private func deleteAccount() {
        isDeleting = true
        
        userManager.deleteAccount { [self] result in
            DispatchQueue.main.async {
                self.isDeleting = false
                
                switch result {
                case .success:
                    self.deleteSuccess = true
                    self.deleteMessage = "Your account has been successfully deleted."
                    self.showDeleteResult = true
                case .failure(let error):
                    self.deleteSuccess = false
                    
                    // Provide user-friendly error messages
                    if let nsError = error as NSError? {
                        switch nsError.code {
                        case AuthErrorCode.requiresRecentLogin.rawValue:
                            self.deleteMessage = "For security reasons, please sign in again to delete your account."
                        case AuthErrorCode.networkError.rawValue:
                            self.deleteMessage = "Network error. Please check your connection and try again."
                        default:
                            self.deleteMessage = "Account deletion failed: \(error.localizedDescription)"
                        }
                    } else {
                        self.deleteMessage = "Account deletion failed. Please try again."
                    }
                    
                    self.showDeleteResult = true
                }
            }
        }
    }
}
}

#Preview {
    SettingsView()
}