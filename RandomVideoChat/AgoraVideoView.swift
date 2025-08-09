import SwiftUI
import AgoraRtcKit

struct AgoraVideoView: UIViewRepresentable {
    let isLocal: Bool
    @StateObject private var agoraManager = AgoraManager.shared
    
    func makeUIView(context: Context) -> UIView {
        print("🎥 AgoraVideoView 생성: \(isLocal ? "로컬" : "원격")")
        
        let view = UIView()
        view.backgroundColor = .black
        
        // 초기 뷰 설정
        updateVideoView(view)
        
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        updateVideoView(uiView)
    }
    
    private func updateVideoView(_ containerView: UIView) {
        // 기존 서브뷰 제거
        containerView.subviews.forEach { $0.removeFromSuperview() }
        
        let videoView: UIView?
        
        if isLocal {
            videoView = agoraManager.localVideoView
            print("📹 로컬 비디오 뷰 업데이트")
        } else {
            videoView = agoraManager.remoteVideoView
            print("📹 원격 비디오 뷰 업데이트: \(agoraManager.remoteUserJoined ? "연결됨" : "대기중")")
        }
        
        if let videoView = videoView {
            containerView.addSubview(videoView)
            videoView.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                videoView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
                videoView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
                videoView.topAnchor.constraint(equalTo: containerView.topAnchor),
                videoView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor)
            ])
        } else {
            // 비디오가 없을 때 플레이스홀더 표시
            let placeholderLabel = UILabel()
            placeholderLabel.text = isLocal ? "카메라 준비중..." : "상대방 대기중..."
            placeholderLabel.textColor = .white
            placeholderLabel.textAlignment = .center
            placeholderLabel.translatesAutoresizingMaskIntoConstraints = false
            
            containerView.addSubview(placeholderLabel)
            NSLayoutConstraint.activate([
                placeholderLabel.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
                placeholderLabel.centerYAnchor.constraint(equalTo: containerView.centerYAnchor)
            ])
        }
    }
}
