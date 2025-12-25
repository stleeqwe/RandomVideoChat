import SwiftUI

/// Displays connection status banner for reconnecting or failed states
@available(iOS 15.0, *)
struct ConnectionStatusBanner: View {
    let connectionState: AgoraConnectionState

    var body: some View {
        VStack {
            if case .reconnecting = connectionState {
                reconnectingBanner
            } else if case .failed = connectionState {
                failedBanner
            }
            Spacer()
        }
    }

    private var reconnectingBanner: some View {
        HStack(spacing: 8) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .white))
            Text("재연결 중...")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(Color.orange.opacity(0.9))
        .cornerRadius(12)
        .padding(.top, 50)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("연결 상태: 재연결 중")
        .accessibilityAddTraits(.updatesFrequently)
    }

    private var failedBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.white)
            Text("연결 실패")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(Color.red.opacity(0.9))
        .cornerRadius(12)
        .padding(.top, 50)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("연결 상태: 연결 실패")
    }
}
