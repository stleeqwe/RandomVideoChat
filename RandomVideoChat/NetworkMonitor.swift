import Foundation
import Network
import Combine

// MARK: - NetworkMonitor (Legacy Compatibility Layer)
/// Provides backward compatibility with the old NetworkMonitor interface
/// Delegates all functionality to the new unified NetworkManager
class NetworkMonitor: ObservableObject {

    // MARK: - Singleton
    static let shared = NetworkMonitor()

    // MARK: - Published Properties
    @Published var isConnected = true
    @Published var connectionType: ConnectionType = .unknown
    @Published var networkQuality: NetworkQuality = .good

    // MARK: - Private
    private var cancellables = Set<AnyCancellable>()
    private var syncTimer: Timer?

    // MARK: - Types
    enum ConnectionType: CustomStringConvertible {
        case wifi
        case cellular
        case wiredEthernet
        case unknown

        var description: String {
            switch self {
            case .wifi: return "WiFi"
            case .cellular: return "Cellular"
            case .wiredEthernet: return "Ethernet"
            case .unknown: return "Unknown"
            }
        }

        var recommendedVideoConfig: VideoConfig {
            switch self {
            case .wifi, .wiredEthernet:
                return VideoConfig(resolution: .hd720, frameRate: 30, bitrate: 1200)
            case .cellular:
                return VideoConfig(resolution: .vga480, frameRate: 24, bitrate: 800)
            case .unknown:
                return VideoConfig(resolution: .cif360, frameRate: 15, bitrate: 400)
            }
        }
    }

    enum NetworkQuality: Int, Comparable {
        case excellent = 1
        case good = 2
        case fair = 3
        case poor = 4

        static func < (lhs: NetworkQuality, rhs: NetworkQuality) -> Bool {
            lhs.rawValue < rhs.rawValue
        }
    }

    enum VideoResolution {
        case hd720
        case vga480
        case cif360
        case qvga240
    }

    struct VideoConfig {
        let resolution: VideoResolution
        let frameRate: Int
        let bitrate: Int
    }

    // MARK: - Initialization
    private init() {
        setupSyncWithNetworkManager()
        NetworkManager.shared.startMonitoring()
    }

    deinit {
        syncTimer?.invalidate()
        cancellables.removeAll()
    }

    // MARK: - Public API

    func startMonitoring() {
        NetworkManager.shared.startMonitoring()
    }

    func stopMonitoring() {
        NetworkManager.shared.stopMonitoring()
    }

    func getAdaptiveVideoConfig() -> VideoConfig {
        let quality = NetworkManager.shared.networkQuality
        let preset = VideoQualityPreset.preset(for: quality)

        let resolution: VideoResolution
        switch preset.width {
        case 1280: resolution = .hd720
        case 640: resolution = preset.height >= 480 ? .vga480 : .cif360
        case 480: resolution = .cif360
        default: resolution = .qvga240
        }

        return VideoConfig(
            resolution: resolution,
            frameRate: preset.frameRate,
            bitrate: preset.bitrate
        )
    }

    // MARK: - Private

    private func setupSyncWithNetworkManager() {
        syncTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.syncFromNetworkManager()
        }
    }

    private func syncFromNetworkManager() {
        let manager = NetworkManager.shared

        DispatchQueue.main.async {
            self.isConnected = manager.isConnected

            switch manager.networkType {
            case .wifi: self.connectionType = .wifi
            case .cellular: self.connectionType = .cellular
            case .wired: self.connectionType = .wiredEthernet
            case .unknown: self.connectionType = .unknown
            }

            switch manager.networkQuality {
            case .excellent: self.networkQuality = .excellent
            case .good: self.networkQuality = .good
            case .fair: self.networkQuality = .fair
            case .poor, .bad, .disconnected, .unknown: self.networkQuality = .poor
            }
        }
    }
}

// MARK: - NetworkQualityMonitor (Legacy Compatibility)
/// Legacy compatibility wrapper for NetworkQualityMonitor
class NetworkQualityMonitor: ObservableObject {

    static let shared = NetworkQualityMonitor()

    @Published var currentQuality: NetworkMonitor.NetworkQuality = .good

    private var syncTimer: Timer?

    private init() {
        setupSync()
    }

    deinit {
        syncTimer?.invalidate()
    }

    func update(tx: Any, rx: Any) {
        // Handled by NetworkManager via Agora callbacks
    }

    func update(loss: Int, rtt: Int, bitrate: Int) {
        NetworkManager.shared.updateStatistics(
            txLoss: Double(loss),
            rxLoss: Double(loss),
            rtt: rtt,
            txBitrate: bitrate,
            rxBitrate: bitrate
        )
    }

    private func setupSync() {
        syncTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            guard let self = self else { return }

            DispatchQueue.main.async {
                switch NetworkManager.shared.networkQuality {
                case .excellent: self.currentQuality = .excellent
                case .good: self.currentQuality = .good
                case .fair: self.currentQuality = .fair
                case .poor, .bad, .disconnected, .unknown: self.currentQuality = .poor
                }
            }
        }
    }
}
