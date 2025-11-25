import Foundation
import Network
import Combine

// MARK: - Network Quality Level
enum NetworkQuality: Int, Comparable, CustomStringConvertible {
    case unknown = 0
    case excellent = 1
    case good = 2
    case fair = 3
    case poor = 4
    case bad = 5
    case disconnected = 6

    static func < (lhs: NetworkQuality, rhs: NetworkQuality) -> Bool {
        return lhs.rawValue < rhs.rawValue
    }

    var description: String {
        switch self {
        case .unknown: return "Unknown"
        case .excellent: return "Excellent"
        case .good: return "Good"
        case .fair: return "Fair"
        case .poor: return "Poor"
        case .bad: return "Bad"
        case .disconnected: return "Disconnected"
        }
    }

    var emoji: String {
        switch self {
        case .unknown: return "❓"
        case .excellent: return "📶"
        case .good: return "📶"
        case .fair: return "📶"
        case .poor: return "📉"
        case .bad: return "⚠️"
        case .disconnected: return "❌"
        }
    }
}

// MARK: - Network Type
enum NetworkType: String {
    case wifi = "WiFi"
    case cellular = "Cellular"
    case wired = "Wired"
    case unknown = "Unknown"
}

// MARK: - Video Quality Preset
struct VideoQualityPreset {
    let width: Int
    let height: Int
    let frameRate: Int
    let bitrate: Int          // Kbps
    let minBitrate: Int       // Kbps
    let orientationMode: Int  // 0: adaptive, 1: fixed landscape, 2: fixed portrait

    static let excellent = VideoQualityPreset(
        width: 1280, height: 720, frameRate: 30,
        bitrate: 1500, minBitrate: 800, orientationMode: 0
    )

    static let good = VideoQualityPreset(
        width: 960, height: 540, frameRate: 24,
        bitrate: 1000, minBitrate: 500, orientationMode: 0
    )

    static let fair = VideoQualityPreset(
        width: 640, height: 480, frameRate: 20,
        bitrate: 600, minBitrate: 300, orientationMode: 0
    )

    static let poor = VideoQualityPreset(
        width: 480, height: 360, frameRate: 15,
        bitrate: 400, minBitrate: 200, orientationMode: 0
    )

    static let bad = VideoQualityPreset(
        width: 320, height: 240, frameRate: 10,
        bitrate: 200, minBitrate: 100, orientationMode: 0
    )

    static func preset(for quality: NetworkQuality) -> VideoQualityPreset {
        switch quality {
        case .excellent:
            return .excellent
        case .good:
            return .good
        case .fair:
            return .fair
        case .poor:
            return .poor
        case .bad, .disconnected, .unknown:
            return .bad
        }
    }
}

// MARK: - Network Statistics
struct NetworkStatistics {
    var packetLossRate: Double = 0      // 0-100%
    var roundTripTime: Int = 0          // milliseconds
    var jitter: Int = 0                 // milliseconds
    var availableBandwidth: Int = 0     // Kbps
    var txPacketLossRate: Double = 0    // Transmit packet loss
    var rxPacketLossRate: Double = 0    // Receive packet loss
    var lastUpdated: Date = Date()

    var isStale: Bool {
        return Date().timeIntervalSince(lastUpdated) > 10
    }
}

// MARK: - Network Manager
/// Unified Network Manager for monitoring and quality adaptation
/// Combines system network monitoring with Agora RTC statistics
final class NetworkManager: ObservableObject {

    // MARK: - Singleton
    static let shared = NetworkManager()

    // MARK: - Configuration
    private struct Config {
        // Quality thresholds
        static let excellentMaxLoss: Double = 1.0
        static let excellentMaxRTT: Int = 50
        static let goodMaxLoss: Double = 3.0
        static let goodMaxRTT: Int = 100
        static let fairMaxLoss: Double = 8.0
        static let fairMaxRTT: Int = 200
        static let poorMaxLoss: Double = 15.0
        static let poorMaxRTT: Int = 400

        // Update intervals
        static let systemCheckInterval: TimeInterval = 5.0
        static let qualityStabilityWindow: Int = 3  // Number of readings to average

        // Hysteresis to prevent rapid quality changes
        static let qualityUpgradeThreshold: Int = 3   // Consecutive good readings to upgrade
        static let qualityDowngradeThreshold: Int = 2 // Consecutive bad readings to downgrade
    }

    // MARK: - Published Properties
    @Published private(set) var isConnected: Bool = true
    @Published private(set) var networkType: NetworkType = .unknown
    @Published private(set) var networkQuality: NetworkQuality = .unknown
    @Published private(set) var currentPreset: VideoQualityPreset = .good
    @Published private(set) var statistics: NetworkStatistics = NetworkStatistics()

    // Quality change callback
    var onQualityChanged: ((NetworkQuality, VideoQualityPreset) -> Void)?

    // MARK: - Private Properties
    private let monitor = NWPathMonitor()
    private let monitorQueue = DispatchQueue(label: "com.randomvideochat.networkmonitor", qos: .utility)

    private var qualityHistory: [NetworkQuality] = []
    private var consecutiveUpgradeReadings: Int = 0
    private var consecutiveDowngradeReadings: Int = 0
    private var lastQualityChange: Date = Date()

    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization
    private init() {
        setupSystemMonitor()
        #if DEBUG
        print("📡 NetworkManager initialized")
        #endif
    }

    deinit {
        stopMonitoring()
    }

    // MARK: - Public API

    /// Start network monitoring
    func startMonitoring() {
        monitor.start(queue: monitorQueue)
        #if DEBUG
        print("📡 Network monitoring started")
        #endif
    }

    /// Stop network monitoring
    func stopMonitoring() {
        monitor.cancel()
        #if DEBUG
        print("📡 Network monitoring stopped")
        #endif
    }

    /// Update statistics from Agora RTC callbacks
    func updateStatistics(
        txLoss: Double,
        rxLoss: Double,
        rtt: Int,
        txBitrate: Int = 0,
        rxBitrate: Int = 0
    ) {
        let avgLoss = (txLoss + rxLoss) / 2.0

        statistics.packetLossRate = avgLoss
        statistics.txPacketLossRate = txLoss
        statistics.rxPacketLossRate = rxLoss
        statistics.roundTripTime = rtt
        statistics.availableBandwidth = max(txBitrate, rxBitrate)
        statistics.lastUpdated = Date()

        // Calculate quality from statistics
        let measuredQuality = calculateQuality(loss: avgLoss, rtt: rtt)
        updateQualityWithHysteresis(measuredQuality)
    }

    /// Update quality from Agora's quality indicator
    func updateFromAgoraQuality(_ agoraQuality: Int) {
        // Agora quality: 1=excellent, 2=good, 3=poor, 4=bad, 5=vbad, 6=down, 0=unknown
        let quality: NetworkQuality
        switch agoraQuality {
        case 1: quality = .excellent
        case 2: quality = .good
        case 3: quality = .fair
        case 4: quality = .poor
        case 5: quality = .bad
        case 6: quality = .disconnected
        default: quality = .unknown
        }

        updateQualityWithHysteresis(quality)
    }

    /// Force a specific quality (for testing or manual override)
    func forceQuality(_ quality: NetworkQuality) {
        applyQualityChange(quality)
    }

    /// Get recommended video preset for current network
    func getRecommendedPreset() -> VideoQualityPreset {
        return currentPreset
    }

    /// Check if network is suitable for video call
    func isSuitableForVideoCall() -> Bool {
        return isConnected && networkQuality.rawValue <= NetworkQuality.poor.rawValue
    }

    // MARK: - Private Methods

    private func setupSystemMonitor() {
        monitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                self?.handlePathUpdate(path)
            }
        }
    }

    private func handlePathUpdate(_ path: NWPath) {
        // Update connection status
        let wasConnected = isConnected
        isConnected = path.status == .satisfied

        // Update network type
        networkType = detectNetworkType(path)

        #if DEBUG
        print("📡 Network path update: \(networkType.rawValue), connected: \(isConnected)")
        #endif

        // If connection state changed
        if wasConnected != isConnected {
            if isConnected {
                // Connection restored - start with fair quality until we get real measurements
                applyQualityChange(.fair)
            } else {
                applyQualityChange(.disconnected)
            }
        }

        // Initial quality estimate based on network type (only if no real stats)
        if statistics.isStale {
            let estimatedQuality = estimateQualityFromNetworkType()
            updateQualityWithHysteresis(estimatedQuality)
        }
    }

    private func detectNetworkType(_ path: NWPath) -> NetworkType {
        if path.usesInterfaceType(.wifi) {
            return .wifi
        } else if path.usesInterfaceType(.cellular) {
            return .cellular
        } else if path.usesInterfaceType(.wiredEthernet) {
            return .wired
        }
        return .unknown
    }

    private func estimateQualityFromNetworkType() -> NetworkQuality {
        guard isConnected else { return .disconnected }

        switch networkType {
        case .wifi, .wired:
            return .good  // Conservative estimate
        case .cellular:
            return .fair  // Cellular can be variable
        case .unknown:
            return .fair
        }
    }

    private func calculateQuality(loss: Double, rtt: Int) -> NetworkQuality {
        // Use both loss and RTT to determine quality
        if loss <= Config.excellentMaxLoss && rtt <= Config.excellentMaxRTT {
            return .excellent
        } else if loss <= Config.goodMaxLoss && rtt <= Config.goodMaxRTT {
            return .good
        } else if loss <= Config.fairMaxLoss && rtt <= Config.fairMaxRTT {
            return .fair
        } else if loss <= Config.poorMaxLoss && rtt <= Config.poorMaxRTT {
            return .poor
        } else {
            return .bad
        }
    }

    private func updateQualityWithHysteresis(_ measuredQuality: NetworkQuality) {
        // Add to history for smoothing
        qualityHistory.append(measuredQuality)
        if qualityHistory.count > Config.qualityStabilityWindow {
            qualityHistory.removeFirst()
        }

        // Don't change quality too frequently
        let timeSinceLastChange = Date().timeIntervalSince(lastQualityChange)
        guard timeSinceLastChange > 2.0 else { return }

        let currentRaw = networkQuality.rawValue
        let measuredRaw = measuredQuality.rawValue

        // Check if upgrade is warranted
        if measuredRaw < currentRaw {
            // Quality is better
            consecutiveUpgradeReadings += 1
            consecutiveDowngradeReadings = 0

            if consecutiveUpgradeReadings >= Config.qualityUpgradeThreshold {
                applyQualityChange(measuredQuality)
                consecutiveUpgradeReadings = 0
            }
        } else if measuredRaw > currentRaw {
            // Quality is worse
            consecutiveDowngradeReadings += 1
            consecutiveUpgradeReadings = 0

            if consecutiveDowngradeReadings >= Config.qualityDowngradeThreshold {
                applyQualityChange(measuredQuality)
                consecutiveDowngradeReadings = 0
            }
        } else {
            // Quality is same - reset counters
            consecutiveUpgradeReadings = 0
            consecutiveDowngradeReadings = 0
        }
    }

    private func applyQualityChange(_ newQuality: NetworkQuality) {
        guard newQuality != networkQuality else { return }

        let oldQuality = networkQuality
        networkQuality = newQuality
        currentPreset = VideoQualityPreset.preset(for: newQuality)
        lastQualityChange = Date()

        #if DEBUG
        print("📡 Network quality changed: \(oldQuality.description) → \(newQuality.description)")
        print("   Preset: \(currentPreset.width)x\(currentPreset.height)@\(currentPreset.frameRate)fps, \(currentPreset.bitrate)kbps")
        #endif

        // Notify listeners
        DispatchQueue.main.async {
            self.onQualityChanged?(newQuality, self.currentPreset)
        }
    }
}

// MARK: - Convenience Extensions
extension NetworkManager {

    /// Human-readable status string
    var statusDescription: String {
        if !isConnected {
            return "Disconnected"
        }
        return "\(networkType.rawValue) - \(networkQuality.description)"
    }

    /// Whether video should be disabled due to poor network
    var shouldDisableVideo: Bool {
        return networkQuality == .bad || networkQuality == .disconnected
    }

    /// Whether to show reconnecting indicator
    var isReconnecting: Bool {
        return networkQuality == .disconnected && isConnected == false
    }
}
