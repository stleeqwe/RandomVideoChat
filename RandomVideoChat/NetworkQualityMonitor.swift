import Foundation
import AgoraRtcKit

// Real-world network quality monitor based on Agora stats
final class NetworkQualityMonitor {
    static let shared = NetworkQualityMonitor()

    // Thresholds (tunable/testing)
    struct Thresholds {
        static let lossFair: Int = 5       // %
        static let lossPoor: Int = 10      // %
        static let rttFair: Int = 200      // ms
        static let rttPoor: Int = 400      // ms
    }

    private(set) var lastTxQuality: AgoraNetworkQuality = .unknown
    private(set) var lastRxQuality: AgoraNetworkQuality = .unknown
    private(set) var lastPacketLossRate: Int = 0        // %
    private(set) var lastRtt: Int = 0                   // ms
    private(set) var lastBitrate: Int = 0               // kbps

    private(set) var currentQuality: NetworkMonitor.NetworkQuality = .good

    private init() {}

    // Update from Agora's high-level networkQuality callback
    func update(tx: AgoraNetworkQuality, rx: AgoraNetworkQuality) {
        lastTxQuality = tx
        lastRxQuality = rx
        // Do not classify solely on Agora ratings; wait for stats too if available.
        // Still perform a provisional classification using rx.
        let mapped = mapAgora(rx)
        setQualityIfChanged(mapped)
    }

    // Update from Agora's remote video stats
    func update(loss: Int, rtt: Int, bitrate: Int) {
        lastPacketLossRate = loss
        lastRtt = rtt
        lastBitrate = bitrate

        let q = classify(loss: loss, rtt: rtt)
        setQualityIfChanged(q)
    }

    private func setQualityIfChanged(_ newQuality: NetworkMonitor.NetworkQuality) {
        if newQuality != currentQuality {
            currentQuality = newQuality
            print("📶 NetworkQualityMonitor -> \(currentQuality)")
        }
    }

    private func mapAgora(_ q: AgoraNetworkQuality) -> NetworkMonitor.NetworkQuality {
        switch q {
        case .excellent: return .excellent
        case .good: return .good
        case .poor: return .fair
        case .bad, .veryBad, .down: return .poor
        default: return .good
        }
    }

    // Threshold-based classification
    func classify(loss: Int, rtt: Int) -> NetworkMonitor.NetworkQuality {
        if loss >= Thresholds.lossPoor || rtt >= Thresholds.rttPoor { return .poor }
        if loss >= Thresholds.lossFair || rtt >= Thresholds.rttFair { return .fair }
        return .good
    }
}

