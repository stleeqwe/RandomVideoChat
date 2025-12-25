import SwiftUI

/// Timer display and add time button
@available(iOS 15.0, *)
struct CallTimerView: View {
    @ObservedObject var viewModel: VideoCallViewModel

    var body: some View {
        VStack {
            Spacer()

            ZStack {
                // Timer display (left)
                HStack {
                    timerDisplay
                    Spacer()
                }

                // Add time button (center)
                addTimeButton

                // End call button (right)
                HStack {
                    Spacer()
                    endCallButton
                }
            }
            .padding(.bottom, 50)
        }
    }

    private var timerDisplay: some View {
        Text("\(viewModel.timeRemaining)")
            .font(.custom("Carter One", size: 36))
            .foregroundColor(viewModel.timeRemaining <= 10 ? .red : .white)
            .monospacedDigit()
            .padding(.leading, 20)
            .padding(.bottom, 130)
            .accessibilityLabel("남은 시간 \(viewModel.timeRemaining)초")
            .accessibilityAddTraits(.updatesFrequently)
    }

    private var addTimeButton: some View {
        Button(action: { viewModel.addTime() }) {
            VStack(spacing: 4) {
                Image("plus.square")
                    .resizable()
                    .frame(width: 40, height: 40)
                    .foregroundColor(.white)
                Text("60s")
                    .font(.custom("Carter One", size: 16))
                    .foregroundColor(.white)
            }
        }
        .disabled(viewModel.heartCount <= 0)
        .opacity(viewModel.heartCount <= 0 ? 0.5 : 1.0)
        .accessibilityLabel("60초 추가")
        .accessibilityHint(viewModel.heartCount <= 0 ? "하트가 부족합니다" : "하트 1개를 사용하여 통화 시간을 60초 연장합니다")
    }

    private var endCallButton: some View {
        Button(action: { viewModel.endCall() }) {
            Circle()
                .fill(Color.red)
                .frame(width: 50, height: 50)
                .overlay(
                    Image(systemName: "phone.down.fill")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(.white)
                )
        }
        .accessibilityLabel("통화 종료")
        .accessibilityHint("현재 통화를 종료합니다")
        .padding(.trailing, 40)
        .padding(.bottom, 15)
    }
}
