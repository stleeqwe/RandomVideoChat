import SwiftUI
import UIKit

// MARK: - VideoCallView
/// Production-grade Video Call View (Refactored)
/// Uses MVVM pattern with extracted components
@available(iOS 15.0, *)
struct VideoCallView: View {
    // MARK: - State
    @StateObject private var viewModel = VideoCallViewModel()
    @StateObject private var agoraManager = AgoraManager.shared
    @StateObject private var networkManager = NetworkManager.shared

    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.presentationMode) var presentationMode

    // MARK: - Body
    var body: some View {
        ZStack {
            // Remote video (fullscreen)
            remoteVideoLayer

            // Gradient overlay
            gradientOverlay

            // Connection status banner
            ConnectionStatusBanner(connectionState: agoraManager.connectionState)

            // Network quality indicator
            NetworkQualityIndicator(networkManager: networkManager)

            // Report/Block buttons
            ReportBlockButtonsView(
                showReportAlert: $viewModel.showReportAlert,
                showBlockAlert: $viewModel.showBlockAlert
            )

            // PIP and controls (right side)
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    CallControlsView(viewModel: viewModel)
                }
            }

            // Timer and end call
            CallTimerView(viewModel: viewModel)
        }
        .onAppear {
            viewModel.onCallEnd = {
                presentationMode.wrappedValue.dismiss()
            }
            viewModel.setupCall()
        }
        .onChange(of: agoraManager.remoteUserJoined) { joined in
            viewModel.handleRemoteUserJoined(joined)
        }
        .onChange(of: agoraManager.isInCall) { inCall in
            viewModel.handleCallStateChange(inCall)
        }
        .onChange(of: agoraManager.connectionState) { state in
            viewModel.handleConnectionStateChange(state)
        }
        .onChange(of: scenePhase) { newPhase in
            viewModel.handleScenePhaseChange(newPhase)
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willTerminateNotification)) { _ in
            viewModel.handleAppTermination()
        }
        .onDisappear {
            viewModel.handleDisappear(isBackground: scenePhase != .active)
        }
        .alert("사용자 신고", isPresented: $viewModel.showReportAlert) {
            reportAlertButtons
        } message: {
            Text("이 사용자를 신고하는 이유를 선택해주세요.")
        }
        .alert("사용자 차단", isPresented: $viewModel.showBlockAlert) {
            blockAlertButtons
        } message: {
            Text("이 사용자를 차단하시겠습니까? 차단된 사용자와는 다시 매칭되지 않습니다.")
        }
        .alert("연결 오류", isPresented: $viewModel.showErrorAlert) {
            Button("확인") {
                viewModel.endCall()
            }
        } message: {
            Text(viewModel.errorMessage)
        }
    }

    // MARK: - View Components

    private var remoteVideoLayer: some View {
        ZStack {
            AgoraVideoView(isLocal: false)
                .environmentObject(agoraManager)
                .ignoresSafeArea()

            // Remote camera off overlay
            if agoraManager.remoteCameraMuted {
                Color.black
                    .ignoresSafeArea()
                    .overlay(
                        VStack(spacing: 16) {
                            Image(systemName: "video.slash.fill")
                                .font(.system(size: 60))
                                .foregroundColor(.white.opacity(0.5))
                            Text("상대방 카메라 꺼짐")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.white.opacity(0.7))
                        }
                    )
            }
        }
    }

    private var gradientOverlay: some View {
        LinearGradient(
            gradient: Gradient(stops: [
                .init(color: Color.black.opacity(0.6), location: 0.0),
                .init(color: Color.black.opacity(0.05), location: 0.25),
                .init(color: Color.clear, location: 0.5),
                .init(color: Color.black.opacity(0.05), location: 0.75),
                .init(color: Color.black.opacity(0.7), location: 1.0)
            ]),
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }

    // MARK: - Alert Buttons

    @ViewBuilder
    private var reportAlertButtons: some View {
        Button("스팸/광고") { viewModel.reportUser(reason: "스팸/광고") }
        Button("부적절한 콘텐츠") { viewModel.reportUser(reason: "부적절한 콘텐츠") }
        Button("욕설/괴롭힘") { viewModel.reportUser(reason: "욕설/괴롭힘") }
        Button("기타") { viewModel.reportUser(reason: "기타") }
        Button("취소", role: .cancel) { }
    }

    @ViewBuilder
    private var blockAlertButtons: some View {
        Button("차단", role: .destructive) { viewModel.blockUser() }
        Button("취소", role: .cancel) { }
    }
}
