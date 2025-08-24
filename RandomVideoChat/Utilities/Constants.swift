import Foundation

enum Constants {
    // MARK: - Timing
    enum Timing {
        static let backgroundTerminationDelay: TimeInterval = 30
        static let matchingTimeout: TimeInterval = 30
        static let callInitialDuration: Int = 5
        static let heartExtensionDuration: Int = 60
        static let animationDuration: TimeInterval = 0.4
    }
    
    // MARK: - Hearts
    enum Hearts {
        static let defaultCount: Int = 3
        static let pricePerHeart: Int = 3000
        static let dailyRewardCount: Int = 1
    }
    
    // MARK: - Matching
    enum Matching {
        static let maxRetries: Int = 3
        static let retryDelay: TimeInterval = 2
        static let preferenceThreshold: Double = 70.0
    }
    
    // MARK: - UI
    enum UI {
        static let cornerRadius: CGFloat = 12
        static let buttonPadding: CGFloat = 20
        static let iconSize: CGFloat = 28
    }
    
    // MARK: - Keys
    enum Keys {
        static let hasLaunchedBefore = "hasLaunchedBefore"
        static let currentChannelName = "currentChannelName"
        static let currentMatchId = "currentMatchId"
    }
}