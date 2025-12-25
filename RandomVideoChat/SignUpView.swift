import SwiftUI
import Foundation
import AuthenticationServices

@available(iOS 15.0, *)
struct SignUpView: View {
    @Binding var isAuthenticated: Bool
    @StateObject private var viewModel = SignUpViewModel()

    var body: some View {
        ZStack {
            GradientBackgroundView(style: .splash)

            VStack(spacing: 60) {
                logoSection
                Spacer()
                birthYearSection
                Spacer()
                signInSection
            }

            if viewModel.isLoading {
                loadingOverlay
            }
        }
        .sheet(isPresented: $viewModel.showYearPicker) {
            YearPickerSheet(
                selectedYear: $viewModel.selectedYear,
                minYear: viewModel.minYear,
                maxYear: viewModel.maxYear,
                isPresented: $viewModel.showYearPicker
            )
        }
        .alert("Authentication Error", isPresented: $viewModel.showError) {
            Button("OK") { }
        } message: {
            Text(viewModel.errorMessage)
        }
        .onChange(of: viewModel.isAuthenticated) { newValue in
            if newValue {
                isAuthenticated = true
            }
        }
    }

    // MARK: - View Components

    private var logoSection: some View {
        VStack(spacing: -50) {
            Text("5")
                .font(.custom("Carter One", size: 120))
                .foregroundColor(.white)
            Text("SEC")
                .font(.custom("Carter One", size: 32))
                .foregroundColor(.white)
        }
        .padding(.top, 80)
    }

    private var birthYearSection: some View {
        VStack(spacing: 24) {
            Text("Welcome!")
                .font(.custom("Carter One", size: 24))
                .foregroundColor(.white)

            VStack(spacing: 16) {
                Text("출생연도를 선택해주세요")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white.opacity(0.8))

                birthYearButton

                if !viewModel.isValidAge {
                    Text("18세 이상만 이용 가능합니다")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.red.opacity(0.8))
                }
            }
        }
        .padding(.horizontal, 40)
    }

    private var birthYearButton: some View {
        Button(action: {
            viewModel.showYearPicker = true
        }) {
            HStack {
                Image(systemName: "calendar")
                    .foregroundColor(.white.opacity(0.7))
                Text("\(viewModel.selectedYear)년")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
                Text("(\(viewModel.userAge)세)")
                    .font(.system(size: 16, weight: .regular))
                    .foregroundColor(.white.opacity(0.7))
                Spacer()
                Image(systemName: "chevron.down")
                    .foregroundColor(.white.opacity(0.7))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(.ultraThinMaterial)
            )
        }
    }

    private var signInSection: some View {
        VStack(spacing: 20) {
            SignInWithAppleButton(
                onRequest: { request in
                    viewModel.prepareAppleSignInRequest(request)
                },
                onCompletion: { result in
                    viewModel.handleAppleSignIn(result: result)
                }
            )
            .signInWithAppleButtonStyle(.white)
            .frame(height: 55)
            .cornerRadius(28)
            .disabled(!viewModel.isValidAge)
            .opacity(viewModel.isValidAge ? 1.0 : 0.6)
            .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)

            Button(action: {
                viewModel.handleGuestLogin()
            }) {
                Text("게스트로 시작하기")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))
                    .underline()
            }
            .disabled(!viewModel.isValidAge)
            .opacity(viewModel.isValidAge ? 1.0 : 0.5)
        }
        .padding(.horizontal, 40)
        .padding(.bottom, 50)
    }

    private var loadingOverlay: some View {
        ZStack {
            Color.black.opacity(0.5)
                .ignoresSafeArea()

            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                .scaleEffect(2)
        }
    }
}

// MARK: - Year Picker Sheet

@available(iOS 15.0, *)
struct YearPickerSheet: View {
    @Binding var selectedYear: Int
    let minYear: Int
    let maxYear: Int
    @Binding var isPresented: Bool

    @State private var tempYear: Int

    init(selectedYear: Binding<Int>, minYear: Int, maxYear: Int, isPresented: Binding<Bool>) {
        self._selectedYear = selectedYear
        self.minYear = minYear
        self.maxYear = maxYear
        self._isPresented = isPresented
        self._tempYear = State(initialValue: selectedYear.wrappedValue)
    }

    var body: some View {
        NavigationView {
            ZStack {
                Color(.systemBackground)
                    .ignoresSafeArea()

                VStack(spacing: 30) {
                    Text("출생연도 선택")
                        .font(.system(size: 20, weight: .bold))
                        .padding(.top, 30)

                    Text("\(Calendar.current.component(.year, from: Date()) - tempYear)세")
                        .font(.system(size: 24, weight: .medium))
                        .foregroundColor(.white.opacity(0.8))

                    Picker("", selection: $tempYear) {
                        ForEach((minYear...maxYear).reversed(), id: \.self) { year in
                            Text("\(year)년")
                                .tag(year)
                                .font(.system(size: 20))
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(height: 200)

                    Spacer()
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("취소") {
                        isPresented = false
                    }
                    .foregroundColor(.red)
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        selectedYear = tempYear
                        isPresented = false
                    }) {
                        Text("완료")
                            .font(.system(size: 17, weight: .semibold))
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

#Preview {
    SignUpView(isAuthenticated: .constant(false))
}
