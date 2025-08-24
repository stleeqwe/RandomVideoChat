import SwiftUI
import AgoraRtcKit

struct AgoraVideoView: UIViewRepresentable {
    let isLocal: Bool
    @EnvironmentObject var agoraManager: AgoraManager
    
    func makeUIView(context: Context) -> UIView {
        #if DEBUG
        print("🎥 AgoraVideoView 생성: \(isLocal ? "로컬" : "원격")")
        #endif
        
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
        let profileTag = 1001
        let videoView: UIView?
        
        if isLocal {
            videoView = agoraManager.localVideoView
            #if DEBUG
            print("📹 로컬 비디오 뷰 업데이트")
            #endif
        } else {
            videoView = agoraManager.remoteVideoView
            #if DEBUG
            print("📹 원격 비디오 뷰 업데이트: \(agoraManager.remoteUserJoined ? "연결됨" : "대기중")")
            #endif
        }
        
        // 카메라가 꺼져있는지 확인
        let shouldShowProfile = (isLocal && agoraManager.isCameraOff) || 
                               (!isLocal && agoraManager.remoteUserJoined && !agoraManager.remoteVideoEnabled)
        
        if let videoView = videoView, !shouldShowProfile {
            // Hide profile if present
            containerView.viewWithTag(profileTag)?.isHidden = true
            if videoView.superview !== containerView {
                containerView.subviews.forEach { sub in
                    if sub.tag == profileTag { return }
                    sub.removeFromSuperview()
                }
                containerView.addSubview(videoView)
                videoView.translatesAutoresizingMaskIntoConstraints = false
                NSLayoutConstraint.activate([
                    videoView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
                    videoView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
                    videoView.topAnchor.constraint(equalTo: containerView.topAnchor),
                    videoView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor)
                ])
            }
            videoView.isHidden = false
        } else {
            // 비디오가 없거나 카메라가 꺼진 상태일 때 프로필 화면 표시
            let profileView: UIView
            if let existing = containerView.viewWithTag(profileTag) {
                profileView = existing
            } else {
                profileView = UIView()
                profileView.tag = profileTag
                containerView.addSubview(profileView)
                profileView.translatesAutoresizingMaskIntoConstraints = false
                NSLayoutConstraint.activate([
                    profileView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
                    profileView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
                    profileView.topAnchor.constraint(equalTo: containerView.topAnchor),
                    profileView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor)
                ])
                
                // 프로필 아이콘 추가
                let profileIcon = UIImageView()
                let personImage = UIImage(systemName: "person.crop.circle.fill")
                profileIcon.image = personImage
                profileIcon.tintColor = UIColor.white.withAlphaComponent(0.5)
                profileIcon.contentMode = .scaleAspectFit
                profileIcon.translatesAutoresizingMaskIntoConstraints = false
                profileView.addSubview(profileIcon)
                NSLayoutConstraint.activate([
                    profileIcon.centerXAnchor.constraint(equalTo: profileView.centerXAnchor),
                    profileIcon.centerYAnchor.constraint(equalTo: profileView.centerYAnchor),
                    profileIcon.widthAnchor.constraint(equalTo: profileView.widthAnchor, multiplier: 0.3),
                    profileIcon.heightAnchor.constraint(equalTo: profileIcon.widthAnchor)
                ])
            }
            profileView.backgroundColor = .black
            profileView.isHidden = false
        }
    }
}
