import SwiftUI

/// Displays network quality status with icon and optional text
@available(iOS 15.0, *)
struct NetworkQualityIndicator: View {
    @ObservedObject var networkManager: NetworkManager

    var body: some View {
        VStack {
            HStack {
                Spacer()

                HStack(spacing: 4) {
                    networkQualityIcon
                    if networkManager.networkQuality == .poor || networkManager.networkQuality == .bad {
                        Text("불안정")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.white)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(networkQualityColor.opacity(0.8))
                .cornerRadius(8)
                .padding(.top, 50)
                .padding(.trailing, 20)
                .accessibilityElement(children: .combine)
                .accessibilityLabel(networkQualityAccessibilityLabel)
            }
            Spacer()
        }
    }

    private var networkQualityAccessibilityLabel: String {
        switch networkManager.networkQuality {
        case .excellent:
            return "네트워크 상태: 매우 좋음"
        case .good:
            return "네트워크 상태: 좋음"
        case .fair:
            return "네트워크 상태: 보통"
        case .poor:
            return "네트워크 상태: 불안정"
        case .bad:
            return "네트워크 상태: 매우 불안정"
        default:
            return "네트워크 상태: 알 수 없음"
        }
    }

    private var networkQualityIcon: some View {
        Image(systemName: networkQualityIconName)
            .font(.system(size: 12, weight: .bold))
            .foregroundColor(.white)
    }

    private var networkQualityIconName: String {
        switch networkManager.networkQuality {
        case .excellent, .good:
            return "wifi"
        case .fair:
            return "wifi.exclamationmark"
        case .poor, .bad:
            return "wifi.slash"
        default:
            return "questionmark.circle"
        }
    }

    private var networkQualityColor: Color {
        switch networkManager.networkQuality {
        case .excellent, .good:
            return .green
        case .fair:
            return .yellow
        case .poor, .bad:
            return .red
        default:
            return .gray
        }
    }
}
