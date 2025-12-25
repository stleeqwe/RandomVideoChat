import SwiftUI

@available(iOS 15.0, *)
struct SplashView: View {
    @Binding var showSplash: Bool
    @State private var logoScale: CGFloat = 0.8
    @State private var logoOpacity: Double = 0
    @State private var glowIntensity: Double = 0
    @State private var particleOpacity: Double = 0
    
    var body: some View {
        ZStack {
            // Background gradient
            GradientBackgroundView(style: .splash)

            // 5SEC Logo with Carter One font
            VStack(spacing: -50) {
                Text("5")
                    .font(.custom("Carter One", size: 120))
                    .foregroundColor(.white)
                Text("SEC")
                    .font(.custom("Carter One", size: 32))
                    .foregroundColor(.white)
            }
            .scaleEffect(logoScale)
            .opacity(logoOpacity)
            .offset(y: -30)
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
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                withAnimation(.easeInOut(duration: 0.6)) {
                    logoOpacity = 0
                    logoScale = 1.1
                    showSplash = false
                }
            }
        }
    }
}
