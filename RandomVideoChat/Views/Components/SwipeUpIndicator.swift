import SwiftUI

// MARK: - Swipe Up Indicator
/// Animated indicator prompting user to swipe up
struct SwipeUpIndicator: View {
    @State private var swipeOffset: CGFloat = 0
    @State private var showSwipeHint = true

    let text: String
    let onSwipeUp: () -> Void

    init(text: String = "SWIPE UP & START", onSwipeUp: @escaping () -> Void) {
        self.text = text
        self.onSwipeUp = onSwipeUp
    }

    var body: some View {
        VStack(spacing: 16) {
            chevronStack
                .offset(y: swipeOffset)
                .accessibilityHidden(true)

            Text(text)
                .font(.custom("Carter One", size: 20))
                .foregroundColor(.white)
        }
        .padding(.bottom, 70)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("위로 스와이프하여 매칭 시작")
        .accessibilityHint("화면을 위로 스와이프하면 랜덤 매칭이 시작됩니다")
        .accessibilityAddTraits(.startsMediaSession)
        .onAppear {
            startAnimations()
        }
        .gesture(swipeGesture)
    }

    private var chevronStack: some View {
        VStack(spacing: 6) {
            ForEach(0..<3, id: \.self) { index in
                Image(systemName: "chevron.up")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.white)
                    .opacity(showSwipeHint ? 1.0 : 0.3)
                    .scaleEffect(showSwipeHint ? 1.0 : 0.7)
                    .animation(
                        .easeInOut(duration: 0.6)
                            .repeatForever(autoreverses: true)
                            .delay(Double(index) * Constants.Animation.swipeHintDelay),
                        value: showSwipeHint
                    )
            }
        }
    }

    private var swipeGesture: some Gesture {
        DragGesture()
            .onEnded { value in
                if value.translation.height < -Constants.UI.swipeThreshold {
                    onSwipeUp()
                }
            }
    }

    private func startAnimations() {
        withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
            swipeOffset = -Constants.UI.swipeAnimationOffset
        }
        withAnimation(.easeInOut(duration: 3.0).repeatForever(autoreverses: true)) {
            showSwipeHint.toggle()
        }
    }
}

#Preview {
    ZStack {
        Color.black
        SwipeUpIndicator {
            print("Swiped up!")
        }
    }
}
