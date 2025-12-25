import SwiftUI
import AVFoundation

@available(iOS 15.0, *)
struct MainView: View {
    @AppStorage("isMainPreviewOn") private var isMainPreviewOn: Bool = true
    @StateObject private var viewModel = MainViewModel()
    @State private var swipeOffset: CGFloat = 0
    @State private var showSwipeHint = true
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ZStack {
            // Camera preview or placeholder
            cameraPreviewLayer

            // Gradient overlay
            gradientOverlay

            // Main content
            mainContent

            // Debug info (development only)
            #if DEBUG
            debugOverlay
            #endif
        }
        .animation(.none, value: isMainPreviewOn)
        .gesture(swipeGesture)
        .alert(isPresented: $viewModel.showPermissionAlert) {
            permissionAlert
        }
        .onAppear {
            viewModel.onAppear(isMainPreviewOn: isMainPreviewOn)
        }
        .alert("출석 보상", isPresented: $viewModel.showDailyRewardAlert) {
            Button("확인") { }
        } message: {
            Text(viewModel.dailyRewardMessage)
        }
        .onChange(of: scenePhase) { newPhase in
            viewModel.handleScenePhase(newPhase, isMainPreviewOn: isMainPreviewOn)
        }
        .fullScreenCover(isPresented: $viewModel.showMatchingView) {
            MatchingView(isPresented: $viewModel.showMatchingView)
        }
        .sheet(isPresented: $viewModel.showSettings) {
            SettingsView()
        }
    }

    // MARK: - View Components

    private var cameraPreviewLayer: some View {
        Group {
            if isMainPreviewOn {
                ImprovedCameraPreview(isOn: $isMainPreviewOn)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ZStack {
                    Color.black.ignoresSafeArea()
                    Image(systemName: "person.crop.circle.fill")
                        .font(.system(size: 200))
                        .foregroundColor(.white.opacity(0.3))
                }
            }
        }
    }

    private var gradientOverlay: some View {
        LinearGradient(
            gradient: Gradient(stops: [
                .init(color: Color.black.opacity(0.4), location: 0.0),
                .init(color: Color.black.opacity(0.05), location: 0.25),
                .init(color: Color.black.opacity(0.02), location: 0.5),
                .init(color: Color.black.opacity(0.05), location: 0.75),
                .init(color: Color.black.opacity(0.7), location: 1.0)
            ]),
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
        .animation(.none, value: isMainPreviewOn)
    }

    private var mainContent: some View {
        VStack {
            // Top bar with settings
            HStack {
                Spacer()
                Button(action: { viewModel.showSettings = true }) {
                    Image(systemName: "gearshape")
                        .font(.system(size: 24))
                        .foregroundColor(.white)
                }
                .accessibilityLabel("설정")
                .accessibilityHint("설정 화면을 엽니다")
                .padding(.top, 50)
                .padding(.trailing, 20)
            }

            Spacer()

            // Gender selection and controls
            HStack {
                genderSelectionPanel
                Spacer()
                controlsPanel
            }
            .padding(.bottom, 30)

            // Swipe indicator
            swipeIndicator
        }
    }

    private var genderSelectionPanel: some View {
        VStack(spacing: 20) {
            GenderSelectionView(
                title: "내 성별",
                isRequired: true,
                selectedGender: $viewModel.myGender,
                onGenderSelected: { viewModel.updateMyGender($0) }
            )

            GenderSelectionView(
                title: "선호 성별",
                isRequired: false,
                selectedGender: $viewModel.preferredGender,
                onGenderSelected: { viewModel.updatePreferredGender($0) }
            )
        }
        .padding(.leading, 20)
    }

    private var controlsPanel: some View {
        VStack(spacing: 12) {
            Button(action: {
                withAnimation(.none) {
                    isMainPreviewOn.toggle()
                }
            }) {
                Image(systemName: isMainPreviewOn ? "camera.fill" : "camera")
                    .font(.system(size: 28))
                    .foregroundColor(.white)
            }
            .accessibilityLabel(isMainPreviewOn ? "카메라 끄기" : "카메라 켜기")
            .accessibilityHint("카메라 프리뷰를 토글합니다")

            HStack(spacing: 4) {
                Image(systemName: "heart.fill")
                    .font(.system(size: 22))
                    .foregroundColor(.red)
                Text("X  \(viewModel.heartCount)")
                    .font(.custom("Carter One", size: 22))
                    .foregroundColor(.white)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("보유 하트 \(viewModel.heartCount)개")
        }
        .padding(.trailing, 20)
    }

    private var swipeIndicator: some View {
        VStack(spacing: 16) {
            VStack(spacing: 6) {
                ForEach(0..<3, id: \.self) { index in
                    Image(systemName: "chevron.up")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(.white)
                        .opacity(showSwipeHint ? 1.0 : 0.3)
                        .scaleEffect(showSwipeHint ? 1.0 : 0.7)
                        .animation(
                            .easeInOut(duration: 0.6)
                                .repeatForever(autoreverses: true)
                                .delay(Double(index) * 0.2),
                            value: showSwipeHint
                        )
                }
            }
            .offset(y: swipeOffset)
            .accessibilityHidden(true)

            Text("SWIPE UP & START")
                .font(.custom("Carter One", size: 20))
                .foregroundColor(.white)
        }
        .padding(.bottom, 70)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("위로 스와이프하여 매칭 시작")
        .accessibilityHint("화면을 위로 스와이프하면 랜덤 매칭이 시작됩니다")
        .accessibilityAddTraits(.startsMediaSession)
        .onAppear {
            withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                swipeOffset = -15
            }
            withAnimation(.easeInOut(duration: 3.0).repeatForever(autoreverses: true)) {
                showSwipeHint.toggle()
            }
        }
    }

    #if DEBUG
    private var debugOverlay: some View {
        VStack {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("세션 제외: \(viewModel.debugSessionExcludedCount)명")
                        .font(.caption2)
                    Text("영구 차단: \(viewModel.debugBlockedCount)명")
                        .font(.caption2)
                    Text(String(format: "선호도: %.1f%%", viewModel.debugPreferenceRate))
                        .font(.caption2)
                    Text("통화 횟수: \(viewModel.debugTotalCalls)회")
                        .font(.caption2)
                }
                .padding(5)
                .background(Color.black.opacity(0.7))
                .foregroundColor(.white)
                .cornerRadius(5)

                Spacer()
            }
            .padding(.top, 60)
            .padding(.horizontal)

            Spacer()
        }
    }
    #endif

    // MARK: - Gestures & Alerts

    private var swipeGesture: some Gesture {
        DragGesture()
            .onEnded { value in
                if value.translation.height < -50 {
                    viewModel.handleSwipeUp()
                }
            }
    }

    private var permissionAlert: Alert {
        if viewModel.permissionMessage.contains("성별") {
            return Alert(
                title: Text("성별 선택 필요"),
                message: Text(viewModel.permissionMessage),
                dismissButton: .default(Text("확인"))
            )
        } else {
            return Alert(
                title: Text("권한 필요"),
                message: Text(viewModel.permissionMessage),
                primaryButton: .default(Text("설정 열기"), action: {
                    viewModel.openSettings()
                }),
                secondaryButton: .cancel(Text("닫기"))
            )
        }
    }
}

// MARK: - Gender Selection Component

struct GenderSelectionView: View {
    let title: String
    let isRequired: Bool
    @Binding var selectedGender: Gender?
    let onGenderSelected: (Gender) -> Void

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 4) {
                Text(title)
                    .font(.custom("GoogleSansCode", size: 14))
                    .foregroundColor(.white)

                if isRequired {
                    Text("*")
                        .font(.custom("GoogleSansCode", size: 14))
                        .foregroundColor(.red)
                        .accessibilityLabel("필수")
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(isRequired ? "\(title), 필수 항목" : title)

            HStack(spacing: 12) {
                ForEach(Gender.allCases, id: \.self) { gender in
                    Button(action: {
                        onGenderSelected(gender)
                    }) {
                        VStack(spacing: 4) {
                            ZStack {
                                Circle()
                                    .fill(selectedGender == gender ? Color.white : Color.white.opacity(0.3))
                                    .frame(width: 40, height: 40)

                                Image(systemName: gender.icon)
                                    .font(.system(size: 20, weight: .medium))
                                    .foregroundColor(selectedGender == gender ? .black : .white)
                            }

                            Text(gender.displayName)
                                .font(.custom("GoogleSansCode", size: 12))
                                .foregroundColor(selectedGender == gender ? .white : .white.opacity(0.7))
                        }
                    }
                    .accessibilityLabel("\(title) \(gender.displayName)")
                    .accessibilityHint(selectedGender == gender ? "선택됨" : "탭하여 선택")
                    .accessibilityAddTraits(selectedGender == gender ? [.isButton, .isSelected] : .isButton)
                    .scaleEffect(selectedGender == gender ? 1.1 : 1.0)
                    .animation(.easeInOut(duration: 0.1), value: selectedGender)
                }
            }
        }
    }
}

#Preview {
    MainView()
}
