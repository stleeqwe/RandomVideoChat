import SwiftUI
<<<<<<< HEAD

// MatchingView.swift에서 수정할 부분

struct MatchingView: View {
    @Binding var isPresented: Bool
    @State private var navigateToVideoCall = false
    @StateObject private var matchingManager = MatchingManager.shared
    @State private var hasStartedMatching = false
    @State private var isReturningFromCall = false  // 통화에서 돌아온 상태 추적
    
    var body: some View {
        ZStack {
            // 배경
            Color.black
                .ignoresSafeArea()
=======
import FirebaseAuth

struct MatchingView: View {
    @Binding var isPresented: Bool
    @StateObject private var matchingManager = MatchingManager.shared
    @State private var dotCount = 0
    @State private var pulseAnimation = false
    @State private var navigateToVideoCall = false
    @State private var showMatchedAnimation = false
    
    var body: some View {
        ZStack {
            // Enhanced dark gradient background
            ZStack {
                LinearGradient(
                    gradient: Gradient(stops: [
                        .init(color: Color(.sRGB, red: 0.02, green: 0.02, blue: 0.08), location: 0.0),
                        .init(color: Color(.sRGB, red: 0.08, green: 0.03, blue: 0.12), location: 0.4),
                        .init(color: Color(.sRGB, red: 0.12, green: 0.05, blue: 0.18), location: 0.8),
                        .init(color: Color(.sRGB, red: 0.05, green: 0.02, blue: 0.1), location: 1.0)
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                
                // Subtle radial accent
                RadialGradient(
                    gradient: Gradient(colors: [
                        Color(.sRGB, red: 0.2, green: 0.1, blue: 0.3).opacity(0.4),
                        Color.clear
                    ]),
                    center: .center,
                    startRadius: 50,
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
                        .blur(radius: CGFloat.random(in: 3...8))
                        .opacity(pulseAnimation ? 0.6 : 0.2)
                        .scaleEffect(pulseAnimation ? 1.2 : 0.8)
                        .animation(
                            .easeInOut(duration: Double.random(in: 3...6))
                                .repeatForever(autoreverses: true)
                                .delay(Double(index) * 0.3),
                            value: pulseAnimation
                        )
                }
            }
>>>>>>> fefefa2 (Initial Commit)
            
            VStack {
                Spacer()
                
<<<<<<< HEAD
                // 통화에서 돌아온 경우 매칭 상태 표시
                if isReturningFromCall {
                    VStack(spacing: 20) {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(3)
                        
                        Text("SEARCHING...")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(.white)
                    }
                } else if matchingManager.isMatching && !matchingManager.isMatched {
                    // 매칭 중 인디케이터
                    VStack(spacing: 20) {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(3)
                        
                        Text("SEARCHING...")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(.white)
                    }
                } else if matchingManager.isMatched && !navigateToVideoCall {
                    // 매칭 완료 - 짧게 표시 후 바로 이동
                    VStack(spacing: 20) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 80))
                            .foregroundColor(.green)
                        
                        Text("MATCHED!")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(.white)
                    }
                    .onAppear {
                        // 0.5초 후 자동으로 영상통화로 이동
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            navigateToVideoCall = true
                        }
                    }
=======
                // 매칭 중 또는 매칭 완료 상태
                if matchingManager.isMatched && !navigateToVideoCall {
                    // Enhanced match success animation
                    VStack(spacing: 30) {
                        ZStack {
                            // Multiple expanding rings
                            ForEach(0..<4, id: \.self) { index in
                                Circle()
                                    .stroke(
                                        LinearGradient(
                                            colors: [
                                                Color(.sRGB, red: 0.2, green: 0.8, blue: 0.4).opacity(0.6),
                                                Color(.sRGB, red: 0.1, green: 0.9, blue: 0.5).opacity(0.3)
                                            ],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ),
                                        lineWidth: 3 - CGFloat(index) * 0.5
                                    )
                                    .frame(width: 80 + CGFloat(index * 25), height: 80 + CGFloat(index * 25))
                                    .scaleEffect(showMatchedAnimation ? 2.0 + CGFloat(index) * 0.3 : 0)
                                    .opacity(showMatchedAnimation ? 0 : 0.8 - Double(index) * 0.2)
                                    .animation(
                                        .easeOut(duration: 1.2)
                                            .delay(Double(index) * 0.1),
                                        value: showMatchedAnimation
                                    )
                            }
                            
                            // Main success icon with glow
                            ZStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 80, weight: .medium))
                                    .foregroundStyle(
                                        LinearGradient(
                                            colors: [
                                                Color(.sRGB, red: 0.2, green: 0.8, blue: 0.4),
                                                Color(.sRGB, red: 0.1, green: 0.9, blue: 0.5)
                                            ],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .blur(radius: 8)
                                    .opacity(0.7)
                                
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 80, weight: .medium))
                                    .foregroundStyle(
                                        LinearGradient(
                                            colors: [
                                                Color(.sRGB, red: 0.2, green: 0.8, blue: 0.4),
                                                Color(.sRGB, red: 0.1, green: 0.9, blue: 0.5)
                                            ],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                            }
                            .scaleEffect(showMatchedAnimation ? 1 : 0)
                            .animation(.spring(response: 0.6, dampingFraction: 0.5), value: showMatchedAnimation)
                        }
                        
                        Text("MATCHED!")
                            .font(.system(size: 38, weight: .black, design: .rounded))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [
                                        Color.white,
                                        Color(.sRGB, red: 0.9, green: 1.0, blue: 0.9)
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .tracking(3)
                            .shadow(color: Color(.sRGB, red: 0.2, green: 0.8, blue: 0.4).opacity(0.5), radius: 15, x: 0, y: 8)
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
                } else {
                    // Enhanced searching animation
                    VStack(spacing: 35) {
                        ZStack {
                            // Multi-layer pulse rings
                            ForEach(0..<4, id: \.self) { index in
                                Circle()
                                    .stroke(
                                        LinearGradient(
                                            colors: [
                                                Color.white.opacity(0.4 - Double(index) * 0.08),
                                                Color(.sRGB, red: 0.7, green: 0.4, blue: 0.9).opacity(0.3 - Double(index) * 0.06)
                                            ],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ),
                                        lineWidth: 2.5 - CGFloat(index) * 0.3
                                    )
                                    .frame(width: 90 + CGFloat(index * 35), height: 90 + CGFloat(index * 35))
                                    .scaleEffect(pulseAnimation ? 1.2 + CGFloat(index) * 0.1 : 0.8)
                                    .opacity(pulseAnimation ? 0.2 : 0.8 - Double(index) * 0.15)
                                    .animation(
                                        .easeInOut(duration: 2.0)
                                            .repeatForever(autoreverses: true)
                                            .delay(Double(index) * 0.4),
                                        value: pulseAnimation
                                    )
                            }
                            
                            // Central loading indicator with glassmorphism
                            ZStack {
                                Circle()
                                    .fill(.ultraThinMaterial)
                                    .overlay(
                                        Circle()
                                            .stroke(
                                                LinearGradient(
                                                    colors: [
                                                        Color.white.opacity(0.4),
                                                        Color.white.opacity(0.1)
                                                    ],
                                                    startPoint: .topLeading,
                                                    endPoint: .bottomTrailing
                                                ),
                                                lineWidth: 1.5
                                            )
                                    )
                                    .frame(width: 80, height: 80)
                                
                                ProgressView()
                                    .progressViewStyle(
                                        CircularProgressViewStyle(
                                            tint: LinearGradient(
                                                colors: [
                                                    Color.white,
                                                    Color(.sRGB, red: 0.8, green: 0.6, blue: 1.0)
                                                ],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                        )
                                    )
                                    .scaleEffect(2.0)
                            }
                        }
                        
                        // Enhanced searching text with gradient
                        VStack(spacing: 8) {
                            HStack(spacing: 4) {
                                Text("SEARCHING")
                                    .font(.system(size: 28, weight: .black, design: .rounded))
                                    .foregroundStyle(
                                        LinearGradient(
                                            colors: [
                                                Color.white,
                                                Color(.sRGB, red: 0.9, green: 0.9, blue: 1.0)
                                            ],
                                            startPoint: .top,
                                            endPoint: .bottom
                                        )
                                    )
                                    .tracking(2)
                                
                                // Animated dots with individual timing
                                HStack(spacing: 2) {
                                    ForEach(0..<3, id: \.self) { index in
                                        Text(".")
                                            .font(.system(size: 28, weight: .black))
                                            .foregroundStyle(Color.white)
                                            .opacity(dotCount > index ? 1 : 0.25)
                                            .scaleEffect(dotCount > index ? 1.1 : 0.9)
                                            .animation(
                                                .easeInOut(duration: 0.3),
                                                value: dotCount
                                            )
                                    }
                                }
                            }
                            
                            // Subtle status indicator
                            HStack(spacing: 6) {
                                ForEach(0..<5, id: \.self) { index in
                                    Circle()
                                        .fill(Color.white.opacity(0.5))
                                        .frame(width: 3, height: 3)
                                        .scaleEffect(pulseAnimation ? 1.2 : 0.8)
                                        .animation(
                                            .easeInOut(duration: 1.5)
                                                .repeatForever(autoreverses: true)
                                                .delay(Double(index) * 0.1),
                                            value: pulseAnimation
                                        )
                                }
                            }
                            .padding(.top, 8)
                        }
                        .onAppear {
                            Timer.scheduledTimer(withTimeInterval: 0.6, repeats: true) { _ in
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    dotCount = (dotCount + 1) % 4
                                }
                            }
                        }
                    }
>>>>>>> fefefa2 (Initial Commit)
                }
                
                Spacer()
                
<<<<<<< HEAD
                // 스와이프 안내
                if !matchingManager.isMatched {
                    HStack {
                        Image(systemName: "arrow.down")
                            .foregroundColor(.white.opacity(0.6))
                        Text("SWIPE DOWN TO CANCEL")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.6))
                    }
                    .padding(.bottom, 30)
                }
            }
        }
        .gesture(
            DragGesture()
                .onEnded { value in
                    if value.translation.height > 100 && !matchingManager.isMatched {
                        // 아래로 스와이프 - 매칭 취소
                        print("⬇️ 스와이프: 매칭 취소")
                        matchingManager.cancelMatching()
                        isPresented = false
                    }
                }
        )
        .onAppear {
            // 통화에서 돌아온 경우가 아닐 때만 매칭 시작
            if !hasStartedMatching && !isReturningFromCall {
                matchingManager.startMatching()
                hasStartedMatching = true
            }
        }
        .onDisappear {
            // 화면을 떠날 때 매칭 상태 초기화
            if !navigateToVideoCall {
                matchingManager.cancelMatching()
                hasStartedMatching = false
            }
        }
        .onChange(of: navigateToVideoCall) { newValue in
            if !newValue && hasStartedMatching {
                // 영상통화에서 돌아온 경우
                isReturningFromCall = true
                
                // 매칭 상태 초기화
                matchingManager.isMatched = false
                matchingManager.matchedUserId = nil
                
                // 2초 후 새로운 매칭 시작
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    isReturningFromCall = false
                    hasStartedMatching = false
                    
                    // 새로운 매칭 시작
                    matchingManager.startMatching()
                    hasStartedMatching = true
                }
            }
=======
                // Modern cancel button
                if !matchingManager.isMatched {
                    VStack(spacing: 15) {
                        // Subtle down chevron
                        Image(systemName: "chevron.down")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.6),
                                        Color.white.opacity(0.3)
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                        
                        Button {
                            matchingManager.cancelMatching()
                            isPresented = false
                        } label: {
                            Text("CANCEL")
                                .font(.system(size: 15, weight: .bold, design: .rounded))
                                .foregroundStyle(Color.white.opacity(0.9))
                                .tracking(1.8)
                                .padding(.horizontal, 32)
                                .padding(.vertical, 14)
                                .background(
                                    .ultraThinMaterial,
                                    in: Capsule()
                                )
                                .overlay(
                                    Capsule()
                                        .stroke(
                                            LinearGradient(
                                                colors: [
                                                    Color.white.opacity(0.3),
                                                    Color.white.opacity(0.1)
                                                ],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            ),
                                            lineWidth: 1.2
                                        )
                                )
                        }
                        .shadow(color: Color.black.opacity(0.2), radius: 10, x: 0, y: 5)
                    }
                    .padding(.bottom, 50)
                }
            }
        }
        .onAppear {
            startMatchingIfNeeded()
            pulseAnimation = true
>>>>>>> fefefa2 (Initial Commit)
        }
        .fullScreenCover(isPresented: $navigateToVideoCall) {
            VideoCallView()
        }
    }
<<<<<<< HEAD
=======
    
    private func startMatchingIfNeeded() {
        if !matchingManager.isMatching && !matchingManager.isMatched {
            matchingManager.startMatching()
        }
    }
>>>>>>> fefefa2 (Initial Commit)
}
