import SwiftUI
import FirebaseAuth
import FirebaseFirestore

@available(iOS 15.0, *)
struct SettingsView: View {
    @Environment(\.presentationMode) var presentationMode
    @State private var showDeleteAccountAlert = false
    @State private var isDeleting = false
    @StateObject private var userManager = UserManager.shared
    
    var body: some View {
        NavigationView {
            List {
                Section {
                    // 이용약관
                    Link(destination: URL(string: "https://example.com/terms")!) {
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
                    Link(destination: URL(string: "https://example.com/privacy")!) {
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
                    Link(destination: URL(string: "mailto:support@example.com")!) {
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
            Text("계정을 삭제하시겠습니까? 이 작업은 되돌릴 수 없습니다. 모든 데이터가 영구적으로 삭제됩니다.")
        }
    }
    
    private func deleteAccount() {
        guard let user = Auth.auth().currentUser else { return }
        
        isDeleting = true
        let uid = user.uid
        
        // 1. Firestore 사용자 데이터 삭제
        let db = Firestore.firestore()
        db.collection("users").document(uid).delete { error in
            if let error = error {
                print("❌ Firestore 데이터 삭제 실패: \(error)")
                isDeleting = false
                return
            }
            
            // 2. Firebase Auth 계정 삭제
            user.delete { error in
                isDeleting = false
                
                if let error = error {
                    print("❌ 계정 삭제 실패: \(error)")
                } else {
                    print("✅ 계정 삭제 완료")
                    // 메인 화면으로 이동 (로그인 화면으로 자동 이동됨)
                    presentationMode.wrappedValue.dismiss()
                }
            }
        }
    }
}

#Preview {
    SettingsView()
}