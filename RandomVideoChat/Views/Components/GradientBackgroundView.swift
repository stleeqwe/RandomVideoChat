import SwiftUI

/// Reusable gradient background with multiple style options
@available(iOS 15.0, *)
struct GradientBackgroundView: View {
    var style: GradientStyle = .purple

    enum GradientStyle {
        case purple      // AuthenticationView style
        case matching    // MatchingView style (more vibrant purple)
        case dark        // Darker variant
        case splash      // SplashView style
    }

    var body: some View {
        ZStack {
            mainGradient
            accentGradients
        }
        .ignoresSafeArea()
    }

    // MARK: - Main Gradient

    private var mainGradient: some View {
        LinearGradient(
            gradient: Gradient(stops: gradientStops),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var gradientStops: [Gradient.Stop] {
        switch style {
        case .purple:
            return [
                .init(color: Color(.sRGB, red: 0.02, green: 0.02, blue: 0.08), location: 0.0),
                .init(color: Color(.sRGB, red: 0.08, green: 0.03, blue: 0.15), location: 0.3),
                .init(color: Color(.sRGB, red: 0.15, green: 0.05, blue: 0.25), location: 0.6),
                .init(color: Color(.sRGB, red: 0.05, green: 0.02, blue: 0.12), location: 1.0)
            ]
        case .matching:
            return [
                .init(color: Color(.sRGB, red: 0.05, green: 0.02, blue: 0.15), location: 0.0),
                .init(color: Color(.sRGB, red: 0.12, green: 0.06, blue: 0.25), location: 0.3),
                .init(color: Color(.sRGB, red: 0.20, green: 0.10, blue: 0.35), location: 0.7),
                .init(color: Color(.sRGB, red: 0.08, green: 0.03, blue: 0.18), location: 1.0)
            ]
        case .dark:
            return [
                .init(color: Color(.sRGB, red: 0.02, green: 0.02, blue: 0.05), location: 0.0),
                .init(color: Color(.sRGB, red: 0.05, green: 0.02, blue: 0.10), location: 0.5),
                .init(color: Color(.sRGB, red: 0.03, green: 0.01, blue: 0.08), location: 1.0)
            ]
        case .splash:
            return [
                .init(color: Color(.sRGB, red: 0.03, green: 0.01, blue: 0.08), location: 0.0),
                .init(color: Color(.sRGB, red: 0.06, green: 0.03, blue: 0.12), location: 0.4),
                .init(color: Color(.sRGB, red: 0.08, green: 0.04, blue: 0.15), location: 0.8),
                .init(color: Color(.sRGB, red: 0.04, green: 0.02, blue: 0.09), location: 1.0)
            ]
        }
    }

    // MARK: - Accent Gradients

    @ViewBuilder
    private var accentGradients: some View {
        switch style {
        case .purple:
            RadialGradient(
                gradient: Gradient(colors: [
                    Color(.sRGB, red: 0.3, green: 0.1, blue: 0.4).opacity(0.3),
                    Color.clear
                ]),
                center: .topTrailing,
                startRadius: 50,
                endRadius: 400
            )

        case .matching:
            ZStack {
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

        case .dark:
            RadialGradient(
                gradient: Gradient(colors: [
                    Color(.sRGB, red: 0.2, green: 0.1, blue: 0.3).opacity(0.2),
                    Color.clear
                ]),
                center: .center,
                startRadius: 100,
                endRadius: 500
            )

        case .splash:
            RadialGradient(
                gradient: Gradient(colors: [
                    Color(.sRGB, red: 0.2, green: 0.1, blue: 0.3).opacity(0.3),
                    Color.clear
                ]),
                center: .center,
                startRadius: 100,
                endRadius: 500
            )
        }
    }
}

#Preview {
    VStack {
        GradientBackgroundView(style: .purple)
    }
}
