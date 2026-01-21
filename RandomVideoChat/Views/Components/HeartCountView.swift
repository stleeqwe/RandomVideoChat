import SwiftUI

// MARK: - Heart Count View
/// Displays heart count with icon
struct HeartCountView: View {
    let count: Int
    var iconSize: CGFloat = 22
    var fontSize: CGFloat = 22

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "heart.fill")
                .font(.system(size: iconSize))
                .foregroundColor(.red)
            Text("X  \(count)")
                .font(.custom("Carter One", size: fontSize))
                .foregroundColor(.white)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("보유 하트 \(count)개")
    }
}

// MARK: - Heart Animation View
/// Animated heart for sending/receiving hearts
struct HeartAnimationView: View {
    @Binding var showAnimation: Bool

    var body: some View {
        if showAnimation {
            Image(systemName: "heart.fill")
                .font(.system(size: 80))
                .foregroundColor(.red)
                .transition(.scale.combined(with: .opacity))
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        withAnimation {
                            showAnimation = false
                        }
                    }
                }
        }
    }
}

#Preview {
    ZStack {
        Color.black
        VStack(spacing: 20) {
            HeartCountView(count: 5)
            HeartCountView(count: 10, iconSize: 28, fontSize: 28)
        }
    }
}
