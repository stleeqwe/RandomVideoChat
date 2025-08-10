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
            // Subtle purple gradient background
            ZStack {
                LinearGradient(
                    gradient: Gradient(stops: [
                        .init(color: Color(.sRGB, red: 0.03, green: 0.01, blue: 0.08), location: 0.0),
                        .init(color: Color(.sRGB, red: 0.06, green: 0.03, blue: 0.12), location: 0.4),
                        .init(color: Color(.sRGB, red: 0.08, green: 0.04, blue: 0.15), location: 0.8),
                        .init(color: Color(.sRGB, red: 0.04, green: 0.02, blue: 0.09), location: 1.0)
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                
                // Very subtle radial accent
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
            .ignoresSafeArea()
            
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
        }
        .onAppear {
            // 🔍 설치된 폰트 확인 (디버깅용)
            #if DEBUG
            print("📋 === FONT DEBUG INFO ===")
            
            // 다양한 Carter One 폰트 이름 시도
            let possibleNames = ["CarterOne-Regular", "Carter One", "CarterOne", "Carter-One", "carter-one"]
            
            for name in possibleNames {
                if let font = UIFont(name: name, size: 16) {
                    print("✅ FOUND: '\(name)' → actual name: '\(font.fontName)'")
                } else {
                    print("❌ NOT FOUND: '\(name)'")
                }
            }
            
            print("📋 All Available Fonts:")
            for family in UIFont.familyNames.sorted() {
                let fonts = UIFont.fontNames(forFamilyName: family)
                if !fonts.isEmpty {
                    print("Family: \(family)")
                    for font in fonts {
                        print("  - \(font)")
                        // Carter가 포함된 폰트 찾기
                        if font.lowercased().contains("carter") {
                            print("    🎯 CARTER FONT FOUND: \(font)")
                        }
                    }
                }
            }
            print("📋 === END FONT DEBUG ===")
            #endif
            
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
                    showSplash = false
                }
            }
        }
    }
}
