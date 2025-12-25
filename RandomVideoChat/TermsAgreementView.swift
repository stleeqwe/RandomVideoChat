import SwiftUI
import WebKit

@available(iOS 15.0, *)
struct TermsAgreementView: View {
    @Binding var hasAgreedToTerms: Bool

    @State private var agreedToTerms = false
    @State private var agreedToPrivacy = false
    @State private var agreedToAge = false
    @State private var showTermsDetail = false
    @State private var showPrivacyDetail = false
    @State private var isLoading = false

    private var allAgreed: Bool {
        agreedToTerms && agreedToPrivacy && agreedToAge
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                VStack(spacing: 12) {
                    Text("5sec")
                        .font(.custom("Carter One", size: 48))
                        .foregroundColor(.white)

                    Text("서비스 이용을 위해\n약관에 동의해주세요")
                        .font(.custom("GoogleSansCode-Regular", size: 18).weight(.medium))
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 60)
                .padding(.bottom, 40)

                Spacer()

                // Agreement items
                VStack(spacing: 16) {
                    // All agree
                    Button(action: {
                        let newValue = !allAgreed
                        agreedToTerms = newValue
                        agreedToPrivacy = newValue
                        agreedToAge = newValue
                    }) {
                        HStack(spacing: 12) {
                            Image(systemName: allAgreed ? "checkmark.circle.fill" : "circle")
                                .font(.system(size: 24))
                                .foregroundColor(allAgreed ? .green : .gray)

                            Text("전체 동의")
                                .font(.custom("GoogleSansCode-Regular", size: 18).weight(.semibold))
                                .foregroundColor(.white)

                            Spacer()
                        }
                        .padding()
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(12)
                    }

                    Divider()
                        .background(Color.gray.opacity(0.3))
                        .padding(.vertical, 8)

                    // Terms of Service
                    AgreementRow(
                        isAgreed: $agreedToTerms,
                        title: "[필수] 서비스 이용약관",
                        showDetail: { showTermsDetail = true }
                    )

                    // Privacy Policy
                    AgreementRow(
                        isAgreed: $agreedToPrivacy,
                        title: "[필수] 개인정보 처리방침",
                        showDetail: { showPrivacyDetail = true }
                    )

                    // Age verification
                    Button(action: {
                        agreedToAge.toggle()
                    }) {
                        HStack(spacing: 12) {
                            Image(systemName: agreedToAge ? "checkmark.circle.fill" : "circle")
                                .font(.system(size: 22))
                                .foregroundColor(agreedToAge ? .green : .gray)

                            Text("[필수] 만 18세 이상입니다")
                                .font(.custom("GoogleSansCode-Regular", size: 16))
                                .foregroundColor(.white)

                            Spacer()
                        }
                        .padding(.vertical, 12)
                        .padding(.horizontal, 16)
                    }
                }
                .padding(.horizontal, 24)

                Spacer()

                // Confirm button
                Button(action: {
                    saveAgreement()
                }) {
                    if isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .black))
                    } else {
                        Text("동의하고 시작하기")
                            .font(.custom("GoogleSansCode-Regular", size: 18).weight(.bold))
                            .foregroundColor(.black)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(allAgreed ? Color.white : Color.gray.opacity(0.5))
                .cornerRadius(28)
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
                .disabled(!allAgreed || isLoading)
            }
        }
        .sheet(isPresented: $showTermsDetail) {
            TermsDetailView(title: "서비스 이용약관", url: "https://5sec-terms.web.app/terms")
        }
        .sheet(isPresented: $showPrivacyDetail) {
            TermsDetailView(title: "개인정보 처리방침", url: "https://5sec-terms.web.app/privacy")
        }
    }

    private func saveAgreement() {
        isLoading = true
        let now = Date()

        UserManager.shared.updateTermsAgreement(termsAgreedAt: now, privacyAgreedAt: now) { success in
            isLoading = false
            if success {
                withAnimation {
                    hasAgreedToTerms = true
                }
            }
        }
    }
}

@available(iOS 15.0, *)
struct AgreementRow: View {
    @Binding var isAgreed: Bool
    let title: String
    let showDetail: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: {
                isAgreed.toggle()
            }) {
                Image(systemName: isAgreed ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22))
                    .foregroundColor(isAgreed ? .green : .gray)
            }

            Text(title)
                .font(.custom("GoogleSansCode-Regular", size: 16))
                .foregroundColor(.white)

            Spacer()

            Button(action: showDetail) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 14))
                    .foregroundColor(.gray)
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
    }
}

@available(iOS 15.0, *)
struct TermsDetailView: View {
    let title: String
    let url: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()

                if let url = URL(string: url) {
                    WebViewWrapper(url: url)
                } else {
                    Text("약관을 불러올 수 없습니다")
                        .font(.custom("GoogleSansCode-Regular", size: 16))
                        .foregroundColor(.gray)
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("닫기") {
                        dismiss()
                    }
                    .font(.custom("GoogleSansCode-Regular", size: 16))
                    .foregroundColor(.white)
                }
            }
        }
    }
}

struct WebViewWrapper: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.backgroundColor = .black
        webView.isOpaque = false
        webView.load(URLRequest(url: url))
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}
}
