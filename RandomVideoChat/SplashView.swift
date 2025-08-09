import SwiftUI

struct SplashView: View {
    @Binding var showSplash: Bool
<<<<<<< HEAD
    
    var body: some View {
        ZStack {
            // 배경색
            Color.black
                .ignoresSafeArea()
            
            // 로고 대신 앱 이름 텍스트 (나중에 로고 이미지로 교체)
            VStack {
                Text("Random")
                    .font(.system(size: 50, weight: .bold))
                    .foregroundColor(.white)
                
                Text("Video Chat")
                    .font(.system(size: 50, weight: .bold))
                    .foregroundColor(.white)
            }
        }
        .onAppear {
            // 2초 후 메인화면으로 전환
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                withAnimation {
=======
    @State private var logoScale: CGFloat = 0.8
    @State private var logoOpacity: Double = 0
    @State private var glowIntensity: Double = 0
    @State private var particleOpacity: Double = 0
    
    var body: some View {
        ZStack {
            // Dynamic gradient background
            LinearGradient(
                gradient: Gradient(stops: [
                    .init(color: Color(.sRGB, red: 0.05, green: 0.05, blue: 0.15), location: 0.0),
                    .init(color: Color(.sRGB, red: 0.1, green: 0.05, blue: 0.2), location: 0.4),
                    .init(color: Color(.sRGB, red: 0.15, green: 0.1, blue: 0.25), location: 0.7),
                    .init(color: Color(.sRGB, red: 0.05, green: 0.05, blue: 0.1), location: 1.0)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            .animation(.easeInOut(duration: 3).repeatForever(autoreverses: true), value: glowIntensity)
            
            // Floating particles
            GeometryReader { geometry in
                ForEach(0..<12, id: \.self) { index in
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.1),
                                    Color(.sRGB, red: 0.7, green: 0.4, blue: 0.9).opacity(0.15)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: CGFloat.random(in: 20...80))
                        .position(
                            x: CGFloat.random(in: 0...geometry.size.width),
                            y: CGFloat.random(in: 0...geometry.size.height)
                        )
                        .blur(radius: CGFloat.random(in: 8...15))
                        .opacity(particleOpacity)
                        .animation(
                            .easeInOut(duration: Double.random(in: 3...6))
                                .repeatForever(autoreverses: true)
                                .delay(Double(index) * 0.3),
                            value: particleOpacity
                        )
                }
            }
            
            // Main logo with modern effects
            VStack(spacing: 0) {
                ZStack {
                    // Glow effect behind "5"
                    Text("5")
                        .font(.system(size: 140, weight: .black, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [
                                    Color(.sRGB, red: 0.8, green: 0.4, blue: 1),
                                    Color(.sRGB, red: 0.6, green: 0.8, blue: 1)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .blur(radius: 20)
                        .opacity(glowIntensity)
                    
                    // Main "5" text
                    Text("5")
                        .font(.system(size: 140, weight: .black, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [
                                    Color.white,
                                    Color(.sRGB, red: 0.9, green: 0.9, blue: 1)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .shadow(color: Color(.sRGB, red: 0.7, green: 0.4, blue: 0.9).opacity(0.5), radius: 20, x: 0, y: 10)
                }
                .scaleEffect(logoScale)
                .opacity(logoOpacity)
                
                Text("SEC")
                    .font(.system(size: 36, weight: .semibold, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.9),
                                Color(.sRGB, red: 0.8, green: 0.8, blue: 1).opacity(0.7)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .tracking(8)
                    .offset(y: -20)
                    .opacity(logoOpacity)
                    .scaleEffect(logoScale * 0.9)
            }
            
            // Subtle pulsing ring
            Circle()
                .stroke(
                    LinearGradient(
                        colors: [
                            Color(.sRGB, red: 0.7, green: 0.4, blue: 0.9).opacity(0.3),
                            Color.clear
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 2
                )
                .frame(width: 300, height: 300)
                .scaleEffect(logoScale)
                .opacity(logoOpacity * 0.6)
        }
        .onAppear {
            withAnimation(.spring(response: 0.8, dampingFraction: 0.6, blendDuration: 0)) {
                logoScale = 1.0
                logoOpacity = 1.0
            }
            
            withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                glowIntensity = 0.8
                particleOpacity = 1.0
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                withAnimation(.easeInOut(duration: 0.6)) {
                    logoOpacity = 0
                    logoScale = 1.1
>>>>>>> fefefa2 (Initial Commit)
                    showSplash = false
                }
            }
        }
    }
}
