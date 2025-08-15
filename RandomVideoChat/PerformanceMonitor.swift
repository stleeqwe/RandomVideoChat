import Foundation
import os.log

#if canImport(FirebasePerformance)
import FirebasePerformance
#endif

class PerformanceMonitor {
    static let shared = PerformanceMonitor()
    private let logger = Logger(subsystem: "com.5sec.app", category: "Performance")
    
    private init() {}
    
    // MARK: - Query Performance Measurement
    static func measureQuery<T>(_ name: String, block: () async throws -> T) async rethrows -> T {
        #if canImport(FirebasePerformance)
        let trace = Performance.startTrace(name: name)
        #endif
        
        let startTime = CFAbsoluteTimeGetCurrent()
        
        defer {
            let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime
            
            #if canImport(FirebasePerformance)
            trace?.setValue(Int64(timeElapsed * 1000), forMetric: "duration_ms")
            trace?.stop()
            #endif
            
            #if DEBUG
            print("📊 Query '\(name)' took: \(String(format: "%.2f", timeElapsed * 1000))ms")
            #endif
        }
        
        return try await block()
    }
    
    // MARK: - Memory Usage Monitoring
    func getCurrentMemoryUsage() -> Double {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_,
                         task_flavor_t(MACH_TASK_BASIC_INFO),
                         $0,
                         &count)
            }
        }
        
        if kerr == KERN_SUCCESS {
            return Double(info.resident_size) / 1024 / 1024 // MB
        } else {
            return 0
        }
    }
    
    // MARK: - Network Quality Detection
    func getNetworkQuality() -> NetworkQuality {
        // 실제 네트워크 상태를 측정하는 로직
        // 여기서는 간단한 예시
        return .good
    }
    
    // MARK: - Performance Metrics Collection
    struct Metrics {
        var averageMatchingTime: Double = 0
        var videoCallDropRate: Double = 0
        var memoryUsage: Double = 0
        var firebaseQueryTime: Double = 0
        var matchingSuccessRate: Double = 0
    }
    
    private var metrics = Metrics()
    
    func updateMatchingTime(_ time: Double) {
        metrics.averageMatchingTime = (metrics.averageMatchingTime + time) / 2
    }
    
    func updateVideoDropRate(_ rate: Double) {
        metrics.videoCallDropRate = rate
    }
    
    func updateMatchingSuccessRate(_ rate: Double) {
        metrics.matchingSuccessRate = rate
    }
    
    func logCurrentMetrics() {
        metrics.memoryUsage = getCurrentMemoryUsage()
        
        logger.info("""
        📊 Performance Metrics:
        - Avg Matching Time: \(String(format: "%.2f", self.metrics.averageMatchingTime))s
        - Video Drop Rate: \(String(format: "%.1f", self.metrics.videoCallDropRate))%
        - Memory Usage: \(String(format: "%.1f", self.metrics.memoryUsage))MB
        - Matching Success: \(String(format: "%.1f", self.metrics.matchingSuccessRate))%
        """)
        
        #if DEBUG
        print("""
        📊 Performance Metrics:
        - Avg Matching Time: \(String(format: "%.2f", metrics.averageMatchingTime))s
        - Video Drop Rate: \(String(format: "%.1f", metrics.videoCallDropRate))%
        - Memory Usage: \(String(format: "%.1f", metrics.memoryUsage))MB
        - Matching Success: \(String(format: "%.1f", metrics.matchingSuccessRate))%
        """)
        #endif
    }
    
    // MARK: - Automatic Performance Monitoring
    func startPerformanceMonitoring() {
        Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] _ in
            self?.logCurrentMetrics()
        }
    }
}

enum NetworkQuality {
    case excellent
    case good
    case poor
    case unknown
}