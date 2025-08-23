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
        .alert("계정 삭제", isPresented: $showDeleteAccountAlert) {
            Button("취소", role: .cancel) { }
            Button("삭제", role: .destructive) {
                deleteAccount()
            }
        } message: {
            Text("정말로 계정을 삭제하시겠습니까? 이 작업은 취소할 수 없으며, 모든 데이터가 영구적으로 삭제됩니다.")
        }
        .alert("계정 삭제", isPresented: $showDeleteResult) {
            Button("확인") {
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
                    self.deleteMessage = "계정이 성공적으로 삭제되었습니다."
                    self.showDeleteResult = true
                case .failure(let error):
                    self.deleteSuccess = false
                    
                    // Provide user-friendly error messages in Korean
                    if let nsError = error as NSError? {
                        switch nsError.code {
                        case AuthErrorCode.requiresRecentLogin.rawValue:
                            self.deleteMessage = "보안상의 이유로 다시 로그인하신 후 계정을 삭제해 주세요."
                        case AuthErrorCode.networkError.rawValue:
                            self.deleteMessage = "네트워크 오류가 발생했습니다. 인터넷 연결을 확인하고 다시 시도해 주세요."
                        default:
                            self.deleteMessage = "계정 삭제 실패: \(error.localizedDescription)"
                        }
                    } else {
                        self.deleteMessage = "계정 삭제에 실패했습니다. 다시 시도해 주세요."
                    }
                    
                    self.showDeleteResult = true
                }
            }
        }
    }
}

#Preview {
    SettingsView()
}