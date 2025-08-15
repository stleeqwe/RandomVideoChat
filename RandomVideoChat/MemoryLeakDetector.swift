import Foundation
import UIKit
import SwiftUI

#if DEBUG
final class MemoryLeakDetector {
    static let shared = MemoryLeakDetector()
    private var trackingObjects: [WeakObject] = []
    private let queue = DispatchQueue(label: "memory.leak.detector", qos: .utility)
    
    private init() {
        // 주기적으로 메모리 누수 체크
        Timer.scheduledTimer(withTimeInterval: 60.0, repeats: true) { [weak self] _ in
            self?.checkForLeaks()
        }
    }
    
    private struct WeakObject {
        weak var object: AnyObject?
        let className: String
        let createdAt: Date
        let objectId: ObjectIdentifier?
        
        init(object: AnyObject) {
            self.object = object
            self.className = String(describing: type(of: object))
            self.createdAt = Date()
            self.objectId = ObjectIdentifier(object)
        }
    }
    
    static func track(_ object: AnyObject) {
        shared.trackObject(object)
    }
    
    private func trackObject(_ object: AnyObject) {
        queue.async {
            self.trackingObjects.append(WeakObject(object: object))
            
            // 주기적으로 정리
            if self.trackingObjects.count > 200 {
                self.cleanupDeallocatedObjects()
            }
        }
    }
    
    func checkForLeaks() {
        queue.async {
            self.cleanupDeallocatedObjects()
            
            let now = Date()
            var leaks: [String: Int] = [:]
            var totalObjects = 0
            
            for weakObj in self.trackingObjects {
                if let _ = weakObj.object {
                    totalObjects += 1
                    let aliveTime = now.timeIntervalSince(weakObj.createdAt)
                    if aliveTime > 120 {  // 2분 이상 살아있으면 의심
                        leaks[weakObj.className, default: 0] += 1
                    }
                }
            }
            
            DispatchQueue.main.async {
                print("🔍 Memory Tracking: \(totalObjects) objects alive")
                
                if !leaks.isEmpty {
                    print("⚠️ Potential Memory Leaks Detected:")
                    for (className, count) in leaks.sorted(by: { $0.value > $1.value }) {
                        print("   - \(className): \(count) instances (>2min alive)")
                    }
                }
            }
        }
    }
    
    private func cleanupDeallocatedObjects() {
        trackingObjects = trackingObjects.filter { $0.object != nil }
        
        // 로그로 정리된 객체 수 확인
        print("🧹 Cleaned up deallocated objects. Remaining: \(trackingObjects.count)")
    }
    
    // 특정 클래스의 인스턴스 개수 확인
    func getInstanceCount(for className: String) -> Int {
        return trackingObjects.filter { 
            $0.object != nil && $0.className == className 
        }.count
    }
}

// MARK: - Memory Leak Detection Extensions
extension NSObject {
    @objc func trackMemoryLeak() {
        MemoryLeakDetector.track(self)
    }
}

// SwiftUI View를 위한 메모리 추적
struct MemoryTrackingModifier: ViewModifier {
    let viewName: String
    
    func body(content: Content) -> some View {
        content
            .onAppear {
                // View가 나타날 때 추적 시작
                print("👁 \(viewName) appeared - starting memory tracking")
            }
            .onDisappear {
                // View가 사라질 때 정리 확인
                print("👋 \(viewName) disappeared")
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    MemoryLeakDetector.shared.checkForLeaks()
                }
            }
    }
}

extension View {
    func trackMemoryLeaks(viewName: String) -> some View {
        self.modifier(MemoryTrackingModifier(viewName: viewName))
    }
}

#endif