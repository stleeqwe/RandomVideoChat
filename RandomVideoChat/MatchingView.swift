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
                        Timer.scheduledTimer(withTimeInterval: 0.6, repeats: true) { _ in
                            withAnimation(.easeInOut(duration: 0.2)) {
                                dotCount = (dotCount + 1) % 4
                            }
                        }
                    }
                }
                
                Spacer()
                
                // 인터랙티브 하향 스와이프 인디케이터
                if !matchingManager.isMatched {
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
                        // Enhanced floating animation (downward)
                        withAnimation(
                            .easeInOut(duration: 2.0)
                                .repeatForever(autoreverses: true)
                        ) {
                            swipeOffset = 15  // Positive value for downward movement
                        }
                        
                        // Pulsing hint animation
                        withAnimation(
                            .easeInOut(duration: 3.0)
                                .repeatForever(autoreverses: true)
                        ) {
                            showSwipeHint.toggle()
                        }
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
        .fullScreenCover(isPresented: $navigateToVideoCall) {
            VideoCallView()
        }
    }
    
    private func startMatchingIfNeeded() {
        if !matchingManager.isMatching && !matchingManager.isMatched {
            matchingManager.startMatching()
        }
    }
}