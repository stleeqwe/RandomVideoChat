import SwiftUI

struct PlaceholderImageView: View {
    var size: CGFloat = 80
    var iconName: String = "person.fill"
    var gradientColors: [Color] = [
        Color(.sRGB, red: 0.6, green: 0.3, blue: 0.8),
        Color(.sRGB, red: 0.8, green: 0.4, blue: 0.9)
    ]
    
    var body: some View {
        ZStack {
            // Background gradient circle
            Circle()
                .fill(
                    LinearGradient(
                        colors: gradientColors,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: size, height: size)
            
            // Glassmorphism overlay
            Circle()
                .fill(.ultraThinMaterial.opacity(0.3))
                .frame(width: size, height: size)
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
            
            // Icon with glow effect
            ZStack {
                Image(systemName: iconName)
                    .font(.system(size: size * 0.4, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.4))
                    .blur(radius: 4)
                
                Image(systemName: iconName)
                    .font(.system(size: size * 0.4, weight: .medium))
                    .foregroundStyle(Color.white)
            }
        }
        .shadow(color: gradientColors[0].opacity(0.3), radius: 15, x: 0, y: 8)
    }
}

struct AvatarPlaceholderView: View {
    var size: CGFloat = 100
    var initials: String = "?"
    
    var body: some View {
        ZStack {
            // Animated background
            Circle()
                .fill(
                    LinearGradient(
                        gradient: Gradient(stops: [
                            .init(color: Color(.sRGB, red: 0.3, green: 0.5, blue: 0.9), location: 0.0),
                            .init(color: Color(.sRGB, red: 0.5, green: 0.7, blue: 1.0), location: 0.6),
                            .init(color: Color(.sRGB, red: 0.2, green: 0.4, blue: 0.8), location: 1.0)
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: size, height: size)
            
            // Subtle pattern overlay
            Circle()
                .fill(.ultraThinMaterial.opacity(0.2))
                .frame(width: size, height: size)
                .overlay(
                    Circle()
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.5),
                                    Color.white.opacity(0.1)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 2
                        )
                )
            
            // Initials or default icon
            if initials != "?" {
                Text(initials.uppercased())
                    .font(.system(size: size * 0.35, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.white)
            } else {
                ZStack {
                    Image(systemName: "person.fill")
                        .font(.system(size: size * 0.4, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.4))
                        .blur(radius: 6)
                    
                    Image(systemName: "person.fill")
                        .font(.system(size: size * 0.4, weight: .medium))
                        .foregroundStyle(Color.white)
                }
            }
        }
        .shadow(color: Color(.sRGB, red: 0.3, green: 0.5, blue: 0.9).opacity(0.4), radius: 20, x: 0, y: 10)
    }
}

struct LogoPlaceholderView: View {
    var size: CGFloat = 120
    var appName: String = "5SEC"
    
    var body: some View {
        ZStack {
            // Gradient background with multiple layers
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(.sRGB, red: 0.8, green: 0.3, blue: 1.0).opacity(0.6 - Double(index) * 0.2),
                                Color(.sRGB, red: 0.5, green: 0.6, blue: 1.0).opacity(0.4 - Double(index) * 0.15)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: size + CGFloat(index * 10), height: size + CGFloat(index * 10))
                    .blur(radius: CGFloat(index * 5))
            }
            
            // Main logo container
            Circle()
                .fill(.ultraThinMaterial)
                .frame(width: size, height: size)
                .overlay(
                    Circle()
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.6),
                                    Color.white.opacity(0.1)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 2
                        )
                )
            
            // App name with glow
            ZStack {
                Text(appName)
                    .font(.system(size: size * 0.25, weight: .black, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.4)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .blur(radius: 8)
                
                Text(appName)
                    .font(.system(size: size * 0.25, weight: .black, design: .rounded))
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
            }
        }
        .shadow(color: Color(.sRGB, red: 0.6, green: 0.3, blue: 0.9).opacity(0.4), radius: 25, x: 0, y: 12)
    }
}

#Preview {
    VStack(spacing: 30) {
        PlaceholderImageView()
        AvatarPlaceholderView(initials: "JD")
        LogoPlaceholderView()
    }
    .padding()
    .background(Color.black)
}