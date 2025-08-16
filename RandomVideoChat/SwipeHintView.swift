import SwiftUI

struct SwipeHintView: View {
    @State private var offset: CGFloat = 0
    @State private var isHighlighted: Bool = true
    @State private var timer: Timer?

    var body: some View {
        VStack(spacing: 16) {
            VStack(spacing: 6) {
                ForEach(0..<3, id: \.self) { index in
                    Image(systemName: "chevron.down")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(.white)
                        .opacity(isHighlighted ? 1.0 : 0.3)
                        .scaleEffect(isHighlighted ? 1.0 : 0.7)
                        .animation(
                            .easeInOut(duration: 0.6)
                                .repeatForever(autoreverses: true)
                                .delay(Double(index) * 0.2),
                            value: isHighlighted
                        )
                }
            }
            .offset(y: offset)

            Text("HOME")
                .font(.custom("Carter One", size: 20))
                .foregroundColor(.white)
        }
        .padding(.bottom, 70)
        .onAppear { 
            #if DEBUG
            print("🎭 SwipeHintView appeared - starting animation")
            #endif
            startAnimation() 
        }
        .onDisappear { 
            #if DEBUG
            print("🎭 SwipeHintView disappeared - stopping animation")
            #endif
            stopAnimation() 
        }
    }

    private func startAnimation() {
        // 기존 타이머 정리
        timer?.invalidate()
        
        // 초기값 설정
        offset = 0
        isHighlighted = true

        #if DEBUG
        print("🎭 SwipeHintView - 애니메이션 시작 (초기값 설정 완료)")
        #endif

        // 위아래 움직임 반복
        withAnimation(
            .easeInOut(duration: 2.0)
                .repeatForever(autoreverses: true)
        ) {
            offset = 15
        }

        // 즉시 첫 번째 깜빡임 시작
        withAnimation(.easeInOut(duration: 1.5)) {
            isHighlighted.toggle()
        }

        // 색상/크기 토글 반복 (3초 후부터 주기적으로)
        timer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { _ in
            withAnimation(.easeInOut(duration: 1.5)) {
                isHighlighted.toggle()
            }
        }
    }

    private func stopAnimation() {
        timer?.invalidate()
        timer = nil
        
        #if DEBUG
        print("🎭 SwipeHintView - 애니메이션 정지 및 타이머 정리 완료")
        #endif
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        SwipeHintView()
    }
}