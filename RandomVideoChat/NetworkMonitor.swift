import Foundation
import Network
import Combine

class NetworkMonitor: ObservableObject {
    static let shared = NetworkMonitor()
    
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "NetworkMonitor")
    
    @Published var isConnected = true
    @Published var connectionType: ConnectionType = .unknown
    @Published var networkQuality: NetworkQuality = .good
    
    enum ConnectionType {
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
        
        // Recommended video settings per network type
        var recommendedVideoConfig: VideoConfig {
            switch self {
            case .wifi, .wiredEthernet:
                return VideoConfig(
                    resolution: .hd720,
                    frameRate: 30,
                    bitrate: 1200
                )
            case .cellular:
                return VideoConfig(
                    resolution: .vga480,
                    frameRate: 24,
                    bitrate: 800
                )
            case .unknown:
                return VideoConfig(
                    resolution: .cif360,
                    frameRate: 15,
                    bitrate: 400
                )
            }
        }
    }
    
    enum NetworkQuality {
        case excellent  // < 50ms latency, 0% packet loss
        case good      // < 150ms latency, < 1% packet loss
        case fair      // < 300ms latency, < 3% packet loss
        case poor      // > 300ms latency, > 3% packet loss
        
        var color: String {
            switch self {
            case .excellent: return "green"
            case .good: return "yellow"
            case .fair: return "orange"
            case .poor: return "red"
            }
        }
    }
    
    struct VideoConfig {
        enum Resolution {
            case hd720  // 1280x720
            case vga480 // 640x480
            case cif360 // 640x360
            case qvga240 // 320x240
        }
        
        let resolution: Resolution
        let frameRate: Int
        let bitrate: Int  // kbps
    }
    
    private init() {
        startMonitoring()
    }
    
    private func startMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                self?.isConnected = path.status == .satisfied
                self?.updateConnectionType(path)
                self?.estimateNetworkQuality(path)
                let statusDesc = (path.status == .satisfied) ? "Connected" : "Disconnected"
                let connDesc = self?.connectionType.description ?? "Unknown"
                print("📶 Network Status: \(statusDesc)")
                print("📶 Connection Type: \(connDesc)")
            }
        }
        
        monitor.start(queue: queue)
    }
    
    private func updateConnectionType(_ path: NWPath) {
        if path.usesInterfaceType(.wifi) {
            connectionType = .wifi
        } else if path.usesInterfaceType(.cellular) {
            connectionType = .cellular
        } else if path.usesInterfaceType(.wiredEthernet) {
            connectionType = .wiredEthernet
        } else {
            connectionType = .unknown
        }
    }
    
    private func estimateNetworkQuality(_ path: NWPath) {
        // Basic quality estimation based on connection type
        // In production, you'd measure actual latency and packet loss
        if !path.isConstrained && !path.isExpensive {
            if connectionType == .wifi || connectionType == .wiredEthernet {
                networkQuality = .excellent
            } else {
                networkQuality = .good
            }
        } else if path.isExpensive {
            // Cellular network
            networkQuality = .fair
        } else {
            networkQuality = .poor
        }
    }
    
    // Get adaptive video configuration based on current network
    func getAdaptiveVideoConfig() -> VideoConfig {
        if !isConnected {
            // Minimum config for poor connection
            return VideoConfig(
                resolution: .qvga240,
                frameRate: 10,
                bitrate: 200
            )
        }
        
        // Adjust based on network quality
        switch networkQuality {
        case .excellent:
            return connectionType.recommendedVideoConfig
        case .good:
            var config = connectionType.recommendedVideoConfig
            return VideoConfig(
                resolution: config.resolution,
                frameRate: config.frameRate - 5,
                bitrate: Int(Double(config.bitrate) * 0.8)
            )
        case .fair:
            return VideoConfig(
                resolution: .cif360,
                frameRate: 20,
                bitrate: 500
            )
        case .poor:
            return VideoConfig(
                resolution: .qvga240,
                frameRate: 15,
                bitrate: 300
            )
        }
    }
    
    // Check if we should switch to audio-only mode
    func shouldUseAudioOnly() -> Bool {
        return networkQuality == .poor || !isConnected
    }
    
    deinit {
        monitor.cancel()
    }
}
