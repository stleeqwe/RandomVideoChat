import SwiftUI

/// Animated floating particles effect
@available(iOS 15.0, *)
struct FloatingParticlesView: View {
    var style: ParticleStyle = .auth
    @Binding var animationTrigger: Bool

    enum ParticleStyle {
        case auth       // Larger, blurry particles (AuthenticationView)
        case matching   // Smaller, pulsing particles (MatchingView)
    }

    var body: some View {
        GeometryReader { geometry in
            ForEach(0..<particleCount, id: \.self) { index in
                particleView(for: index, in: geometry)
            }
        }
    }

    private var particleCount: Int {
        switch style {
        case .auth: return 20
        case .matching: return 15
        }
    }

    @ViewBuilder
    private func particleView(for index: Int, in geometry: GeometryProxy) -> some View {
        switch style {
        case .auth:
            authParticle(index: index, geometry: geometry)
        case .matching:
            matchingParticle(index: index, geometry: geometry)
        }
    }

    // MARK: - Auth Style Particles

    private func authParticle(index: Int, geometry: GeometryProxy) -> some View {
        let size = CGFloat.random(in: 20...100)
        let opacity = Double.random(in: 0.03...0.08)

        return Circle()
            .fill(
                LinearGradient(
                    colors: [
                        Color(.sRGB, red: 0.7, green: 0.4, blue: 0.9).opacity(opacity),
                        Color.white.opacity(opacity * 0.6)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(width: size, height: size)
            .position(
                x: CGFloat.random(in: -size...geometry.size.width + size),
                y: CGFloat.random(in: -size...geometry.size.height + size)
            )
            .blur(radius: CGFloat.random(in: 15...25))
            .animation(
                .easeInOut(duration: Double.random(in: 4...8))
                    .repeatForever(autoreverses: true)
                    .delay(Double(index) * 0.2),
                value: animationTrigger
            )
    }

    // MARK: - Matching Style Particles

    private func matchingParticle(index: Int, geometry: GeometryProxy) -> some View {
        let size = CGFloat.random(in: 4...12)
        let baseOpacity = Double.random(in: 0.05...0.15)

        return Circle()
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
            .opacity(animationTrigger ? 0.8 : 0.3)
            .scaleEffect(animationTrigger ? 1.4 : 0.6)
            .animation(
                .easeInOut(duration: Double.random(in: 2...4))
                    .repeatForever(autoreverses: true)
                    .delay(Double(index) * 0.2),
                value: animationTrigger
            )
    }
}

/// Convenience initializer for views that don't need external animation control
@available(iOS 15.0, *)
struct FloatingParticlesAutoView: View {
    var style: FloatingParticlesView.ParticleStyle = .auth
    @State private var animationTrigger = false

    var body: some View {
        FloatingParticlesView(style: style, animationTrigger: $animationTrigger)
            .onAppear {
                animationTrigger = true
            }
    }
}

#Preview {
    ZStack {
        GradientBackgroundView(style: .purple)
        FloatingParticlesAutoView(style: .auth)
    }
}
