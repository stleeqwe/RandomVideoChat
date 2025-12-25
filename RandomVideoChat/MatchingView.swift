import SwiftUI
import FirebaseAuth

@available(iOS 15.0, *)
struct MatchingView: View {
    @Binding var isPresented: Bool
    @EnvironmentObject var matchingManager: MatchingManager
    @State private var dotCount = 0
    @State private var pulseAnimation = false
    @State private var navigateToVideoCall = false
    @State private var showMatchedAnimation = false
    @State private var dotTimer: Timer?
    
    // 백그라운드 상태 관리
    @Environment(\.scenePhase) private var scenePhase
    @State private var isInBackground = false
    
    var body: some View {
        ZStack {
            // Gradient background
            GradientBackgroundView(style: .matching)

            // Floating particles
            FloatingParticlesView(style: .matching, animationTrigger: $pulseAnimation)

            VStack {
                Spacer()
                
                // 매칭 중 또는 매칭 완료 상태 (VideoCall로 이동하지 않은 경우에만, 상대방에 의해 종료되지 않은 경우에만)
                if matchingManager.isMatched && !navigateToVideoCall && !matchingManager.callEndedByOpponent {
                    // Enhanced match success animation
                    VStack(spacing: 30) {
                        ZStack {
                            // Simple purple success icon
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 80, weight: .medium))
                                .foregroundColor(Color(.sRGB, red: 0.6, green: 0.4, blue: 0.8))
                            .scaleEffect(showMatchedAnimation ? 1 : 0)
                            .animation(.spring(response: 0.6, dampingFraction: 0.5), value: showMatchedAnimation)
                        }
                        
                        Text("MATCHED!")
                            .font(.custom("Carter One", size: 38))
                            .foregroundColor(.white)
                            .scaleEffect(showMatchedAnimation ? 1 : 0)
                            .animation(.spring(response: 0.7, dampingFraction: 0.6).delay(0.2), value: showMatchedAnimation)
                    }
                    .onAppear {
                        withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
                            showMatchedAnimation = true
                        }
                        // 0.8초 후 자동으로 영상통화로 이동
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                            navigateToVideoCall = true
                        }
                    }
                } else if !navigateToVideoCall {
                    // 로딩 인디케이터
                    VStack(spacing: 30) {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(1.5)
                        
                        // SEARCHING 텍스트 + 점 애니메이션
                        HStack(spacing: 4) {
                            Text("SEARCHING")
                                .font(.custom("Carter One", size: 28))
                                .foregroundColor(.white)
                            
                            // 애니메이션 점들
                            HStack(spacing: 2) {
                                ForEach(0..<3, id: \.self) { index in
                                    Text(".")
                                        .font(.custom("Carter One", size: 28))
                                        .foregroundColor(.white)
                                        .opacity(dotCount > index ? 1 : 0.3)
                                        .scaleEffect(dotCount > index ? 1.1 : 0.9)
                                        .animation(
                                            .easeInOut(duration: 0.3),
                                            value: dotCount
                                        )
                                }
                            }
                        }
                    }
                    .onAppear {
                        startDotAnimation()
                    }
                }
                
                Spacer()
                
                // 인터랙티브 하향 스와이프 인디케이터
                if !matchingManager.isMatched && !navigateToVideoCall {
                    SwipeHintView()
                }
            }
        }
        .gesture(
            DragGesture()
                .onEnded { value in
                    // 아래로 스와이프 감지
                    if value.translation.height > 50 {
                        print("⬇️ 스와이프 감지 - 매칭 취소")
                        matchingManager.cancelMatching()
                        isPresented = false
                    }
                }
        )
        .onAppear {
            startMatchingIfNeeded()
            pulseAnimation = true
        }
        .onDisappear {
            stopDotAnimation()
        }
        .onChange(of: matchingManager.isMatched) { isMatched in
            if !isMatched && navigateToVideoCall {
                // 매칭이 취소되었는데 VideoCall이 활성화되어 있다면 즉시 리셋
                navigateToVideoCall = false
                showMatchedAnimation = false
            }
        }
        .onChange(of: matchingManager.callEndedByOpponent) { endedByOpponent in
            if endedByOpponent {
                // 상대방에 의해 통화가 종료된 경우 즉시 상태 리셋
                navigateToVideoCall = false
                showMatchedAnimation = false
            }
        }
        .onChange(of: scenePhase) { newPhase in
            handleScenePhaseChange(newPhase)
        }
        .fullScreenCover(isPresented: $navigateToVideoCall, onDismiss: {
            resetMatchingState()
        }) {
            VideoCallView()
        }
    }
    
    private func startMatchingIfNeeded() {
        if !matchingManager.isMatching && !matchingManager.isMatched {
            // 콘텐츠 안전성 검사 후 매칭 시작
            UserManager.shared.checkContentSafety { isAllowed, errorMessage in
                DispatchQueue.main.async {
                    if isAllowed {
                        self.matchingManager.startMatching()
                    } else {
                        // 안전성 검사 실패 시 매칭 중단하고 메인으로 돌아가기
                        print("❌ 콘텐츠 안전성 검사 실패: \(errorMessage ?? "알 수 없는 오류")")
                        self.isPresented = false
                    }
                }
            }
        }
    }
    
    private func startDotAnimation() {
        stopDotAnimation() // 기존 타이머가 있으면 정리
        dotTimer = Timer.scheduledTimer(withTimeInterval: 0.6, repeats: true) { _ in
            withAnimation(.easeInOut(duration: 0.2)) {
                dotCount = (dotCount + 1) % 4
            }
        }
    }
    
    private func stopDotAnimation() {
        dotTimer?.invalidate()
        dotTimer = nil
    }
    
    private func resetMatchingState() {
        // VideoCallView가 dismiss될 때 상태 리셋
        navigateToVideoCall = false
        showMatchedAnimation = false
        
        // MatchingManager 상태도 확인하여 필요시 리셋
        if matchingManager.isMatched && !matchingManager.isMatching {
            matchingManager.cancelMatching()
        }
    }
    
    // MARK: - Background Handling
    private func handleScenePhaseChange(_ newPhase: ScenePhase) {
        switch newPhase {
        case .background, .inactive:
            if !isInBackground {
                isInBackground = true
                #if DEBUG
                print("📱 매칭 화면 - 백그라운드 진입: 매칭 큐에서 제거")
                #endif
                // 백그라운드로 갈 때 매칭 취소 (큐에서 제거)
                if matchingManager.isMatching {
                    matchingManager.cancelMatching()
                }
            }
        case .active:
            if isInBackground {
                isInBackground = false
                #if DEBUG
                print("📱 매칭 화면 - 포어그라운드 복귀: 매칭 재시작")
                #endif
                // 포어그라운드로 돌아오면 매칭 다시 시작
                // 단, 이미 매칭된 상태가 아닐 때만
                if !matchingManager.isMatched && !navigateToVideoCall {
                    startMatchingIfNeeded()
                }
            }
        default:
            break
        }
    }
    
}
