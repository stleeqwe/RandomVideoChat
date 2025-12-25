import SwiftUI

/// Camera, microphone controls and heart count display
@available(iOS 15.0, *)
struct CallControlsView: View {
    @ObservedObject var viewModel: VideoCallViewModel
    @StateObject private var agoraManager = AgoraManager.shared

    var body: some View {
        VStack(spacing: 12) {
            // PIP video
            pipVideo

            // Camera and mic controls
            HStack(spacing: 12) {
                cameraButton
                muteButton
            }

            // Heart count
            heartDisplay
        }
        .padding(.trailing, 20)
        .padding(.bottom, 180)
    }

    private var pipVideo: some View {
        ZStack {
            if viewModel.isCameraOn {
                AgoraVideoView(isLocal: true)
                    .environmentObject(agoraManager)
                    .frame(width: 100, height: 140)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.white.opacity(0.3), lineWidth: 1)
                    )
            } else {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.black)
                    .frame(width: 100, height: 140)
                    .overlay(
                        Image(systemName: "person.crop.circle.fill")
                            .font(.system(size: 40))
                            .foregroundColor(.white.opacity(0.5))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.white.opacity(0.3), lineWidth: 1)
                    )
            }
        }
        .accessibilityLabel(viewModel.isCameraOn ? "내 카메라 프리뷰" : "카메라 꺼짐")
    }

    private var cameraButton: some View {
        Button(action: { viewModel.toggleCamera() }) {
            Image(systemName: viewModel.isCameraOn ? "camera.fill" : "camera")
                .font(.system(size: 28))
                .foregroundColor(.white)
        }
        .accessibilityLabel(viewModel.isCameraOn ? "카메라 끄기" : "카메라 켜기")
        .accessibilityHint("카메라를 토글합니다")
    }

    private var muteButton: some View {
        Button(action: { viewModel.toggleMute() }) {
            ZStack {
                Image(systemName: "mic.fill")
                    .font(.system(size: 28))
                    .foregroundColor(.white)

                if viewModel.isMuted {
                    Rectangle()
                        .frame(width: 35, height: 2)
                        .foregroundColor(.red)
                        .rotationEffect(.degrees(45))
                        .offset(x: 0, y: -2)
                }
            }
        }
        .accessibilityLabel(viewModel.isMuted ? "마이크 켜기" : "마이크 끄기")
        .accessibilityHint("마이크 음소거를 토글합니다")
    }

    private var heartDisplay: some View {
        HStack(spacing: 4) {
            Image(systemName: "heart.fill")
                .font(.system(size: 22))
                .foregroundColor(.red)
            Text("X  \(viewModel.heartCount)")
                .font(.custom("Carter One", size: 22))
                .foregroundColor(.white)
                .scaleEffect(viewModel.showHeartAnimation ? 1.2 : 1.0)
                .animation(.easeInOut(duration: 0.4), value: viewModel.showHeartAnimation)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("보유 하트 \(viewModel.heartCount)개")
    }
}
