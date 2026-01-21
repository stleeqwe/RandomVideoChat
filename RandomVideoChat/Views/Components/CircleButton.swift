import SwiftUI

// MARK: - Circle Button Style
/// Reusable circle button with consistent styling
struct CircleButton: View {
    let systemName: String
    let size: CGFloat
    let backgroundColor: Color
    let foregroundColor: Color
    let action: () -> Void

    init(
        systemName: String,
        size: CGFloat = 50,
        backgroundColor: Color = Color.black.opacity(0.5),
        foregroundColor: Color = .white,
        action: @escaping () -> Void
    ) {
        self.systemName = systemName
        self.size = size
        self.backgroundColor = backgroundColor
        self.foregroundColor = foregroundColor
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(backgroundColor)
                    .frame(width: size, height: size)

                Image(systemName: systemName)
                    .font(.system(size: size * 0.44))
                    .foregroundColor(foregroundColor)
            }
        }
    }
}

// MARK: - Toggle Circle Button
/// Circle button with toggle state
struct ToggleCircleButton: View {
    let activeIcon: String
    let inactiveIcon: String
    let isActive: Bool
    let size: CGFloat
    let activeColor: Color
    let inactiveColor: Color
    let action: () -> Void

    init(
        activeIcon: String,
        inactiveIcon: String,
        isActive: Bool,
        size: CGFloat = 50,
        activeColor: Color = .white,
        inactiveColor: Color = .white,
        action: @escaping () -> Void
    ) {
        self.activeIcon = activeIcon
        self.inactiveIcon = inactiveIcon
        self.isActive = isActive
        self.size = size
        self.activeColor = activeColor
        self.inactiveColor = inactiveColor
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(Color.black.opacity(0.5))
                    .frame(width: size, height: size)

                Image(systemName: isActive ? activeIcon : inactiveIcon)
                    .font(.system(size: size * 0.44))
                    .foregroundColor(isActive ? activeColor : inactiveColor)
            }
        }
    }
}

#Preview {
    ZStack {
        Color.gray
        VStack(spacing: 20) {
            CircleButton(systemName: "gearshape") {
                print("Settings tapped")
            }

            ToggleCircleButton(
                activeIcon: "camera.fill",
                inactiveIcon: "camera",
                isActive: true
            ) {
                print("Camera toggled")
            }

            ToggleCircleButton(
                activeIcon: "mic.fill",
                inactiveIcon: "mic.slash.fill",
                isActive: false,
                activeColor: .white,
                inactiveColor: .red
            ) {
                print("Mic toggled")
            }
        }
    }
}
