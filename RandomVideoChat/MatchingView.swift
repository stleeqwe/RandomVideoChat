import SwiftUI
import FirebaseAuth

@available(iOS 15.0, *)
struct MatchingView: View {
    @Binding var isPresented: Bool
    @StateObject private var matchingManager = MatchingManager.shared
    @State private var dotCount = 0
    @State private var pulseAnimation = false
    @State private var navigateToVideoCall = false
    @State private var showMatchedAnimation = false
    @State private var swipeOffset: CGFloat = 0
    @State private var showSwipeHint = true
    @State private var dotTimer: Timer?
    @State private var swipeHintTimer: Timer?
    
    // 백그라운드 상태 관리
    @Environment(\.scenePhase) private var scenePhase
    @State private var isInBackground = false
    
    var body: some View {
        ZStack {
            // Enhanced purple gradient background
            ZStack {
                LinearGradient(
                    gradient: Gradient(stops: [
                        .init(color: Color(.sRGB, red: 0.05, green: 0.02, blue: 0.15), location: 0.0),
                        .init(color: Color(.sRGB, red: 0.12, green: 0.06, blue: 0.25), location: 0.3),
                        .init(color: Color(.sRGB, red: 0.20, green: 0.10, blue: 0.35), location: 0.7),
                        .init(color: Color(.sRGB, red: 0.08, green: 0.03, blue: 0.18), location: 1.0)
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                
                // Enhanced radial purple accent
                RadialGradient(
                    gradient: Gradient(colors: [
                        Color(.sRGB, red: 0.4, green: 0.2, blue: 0.6).opacity(0.6),
                        Color(.sRGB, red: 0.3, green: 0.15, blue: 0.5).opacity(0.3),
                        Color.clear
                    ]),
                    center: .center,
                    startRadius: 80,
                    endRadius: 400
                )
                
                // Additional purple glow spots
                RadialGradient(
                    gradient: Gradient(colors: [
                        Color(.sRGB, red: 0.5, green: 0.3, blue: 0.8).opacity(0.4),
                        Color.clear
                    ]),
                    center: .topTrailing,
                    startRadius: 50,
                    endRadius: 250
                )
                
                RadialGradient(
                    gradient: Gradient(colors: [
                        Color(.sRGB, red: 0.6, green: 0.2, blue: 0.7).opacity(0.3),
                        Color.clear
                    ]),
                    center: .bottomLeading,
                    startRadius: 60,
                    endRadius: 300
                )
            }
            .ignoresSafeArea()
            
            // Enhanced floating particles with varied behavior
            GeometryReader { geometry in
                ForEach(0..<15, id: \.self) { index in
                    let size = CGFloat.random(in: 4...12)
                    let baseOpacity = Double.random(in: 0.05...0.15)
                    
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(baseOpacity),
                                    Color(.sRGB, red: 0.7, green: 0.4, blue: 0.9).opacity(baseOpacity * 0.8)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: size, height: size)
                        .position(
                            x: CGFloat.random(in: 0...geometry.size.width),
                            y: CGFloat.random(in: 0...geometry.size.height)
                        )
                        .blur(radius: CGFloat.random(in: 2...6))
                        .opacity(pulseAnimation ? 0.8 : 0.3)
                        .scaleEffect(pulseAnimation ? 1.4 : 0.6)
                        .animation(
                            .easeInOut(duration: Double.random(in: 2...4))
                                .repeatForever(autoreverses: true)
                                .delay(Double(index) * 0.2),
                            value: pulseAnimation
                        )
                }
            }
            
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
                    VStack(spacing: 16) {
                        VStack(spacing: 6) {
                            ForEach(0..<3, id: \.self) { index in
                                Image(systemName: "chevron.down")
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
                        
                        Text("HOME")
                            .font(.custom("Carter One", size: 20))
                            .foregroundColor(.white)
                    }
                    .padding(.bottom, 70)
                    .onAppear {
                        startSwipeAnimation()
                    }
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
        
        // 스와이프 애니메이션도 정리
        stopSwipeAnimation()
    }
    
    private func resetMatchingState() {
        // VideoCallView가 dismiss될 때 상태 리셋
        navigateToVideoCall = false
        showMatchedAnimation = false
        
        // 스와이프 애니메이션 재시작
        startSwipeAnimation()
        
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
                    // 스와이프 애니메이션 재시작
                    startSwipeAnimation()
                    
                    startMatchingIfNeeded()
                }
            }
        default:
            break
        }
    }
    
    // MARK: - Swipe Animation
    private func startSwipeAnimation() {
        // 기존 타이머 정리
        swipeHintTimer?.invalidate()
        
        // 매칭 화면 진입 시 상태 초기화 (기존 초기값으로)
        swipeOffset = 0
        showSwipeHint = true
        
        // Enhanced floating animation (downward) - 기존 방식
        withAnimation(
            .easeInOut(duration: 2.0)
                .repeatForever(autoreverses: true)
        ) {
            swipeOffset = 15  // Positive value for downward movement
        }
        
        // Timer를 사용한 주기적 토글 애니메이션
        swipeHintTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { _ in
            withAnimation(.easeInOut(duration: 1.5)) {
                showSwipeHint.toggle()
            }
        }
    }
    
    private func stopSwipeAnimation() {
        swipeHintTimer?.invalidate()
        swipeHintTimer = nil
    }
    
}