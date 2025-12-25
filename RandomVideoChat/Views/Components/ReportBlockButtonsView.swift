import SwiftUI

/// Report and block buttons overlay
@available(iOS 15.0, *)
struct ReportBlockButtonsView: View {
    @Binding var showReportAlert: Bool
    @Binding var showBlockAlert: Bool

    var body: some View {
        VStack {
            HStack {
                VStack(spacing: 12) {
                    reportButton
                    blockButton
                }
                .padding(.leading, 20)
                .padding(.top, 45)

                Spacer()
            }

            Spacer()
        }
    }

    private var reportButton: some View {
        Button(action: { showReportAlert = true }) {
            Circle()
                .fill(Color.orange.opacity(0.4))
                .frame(width: 40, height: 40)
                .overlay(
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                )
        }
        .accessibilityLabel("신고하기")
        .accessibilityHint("상대방을 신고합니다")
    }

    private var blockButton: some View {
        Button(action: { showBlockAlert = true }) {
            Circle()
                .fill(Color.red.opacity(0.4))
                .frame(width: 40, height: 40)
                .overlay(
                    Image(systemName: "nosign")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                )
        }
        .accessibilityLabel("차단하기")
        .accessibilityHint("상대방을 차단하고 다시 매칭되지 않도록 합니다")
    }
}
