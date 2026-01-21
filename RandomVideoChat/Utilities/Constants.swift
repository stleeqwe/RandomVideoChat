import Foundation

enum Constants {
    // MARK: - Timing
    enum Timing {
        static let backgroundTerminationDelay: TimeInterval = 30
        static let matchingTimeout: TimeInterval = 120  // 2 minutes
        static let callInitialDuration: Int = 5
        static let heartExtensionDuration: Int = 60
        static let animationDuration: TimeInterval = 0.4
        static let presenceTimeout: TimeInterval = 15   // Grace period for reconnection
        static let queueCleanupDelay: TimeInterval = 3
        static let joinTimeout: TimeInterval = 30
        static let engineIdleTimeout: TimeInterval = 300  // 5 minutes
        static let networkSwitchCooldown: TimeInterval = 10.0
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
        static let maxRecentMatches: Int = 5
    }

    // MARK: - Video
    enum Video {
        static let defaultWidth: Int = 640
        static let defaultHeight: Int = 480
        static let defaultFrameRate: Int = 24
        static let defaultBitrate: Int = 800
    }

    // MARK: - UI
    enum UI {
        static let cornerRadius: CGFloat = 12
        static let buttonPadding: CGFloat = 20
        static let iconSize: CGFloat = 28
        static let swipeThreshold: CGFloat = 50
        static let swipeAnimationOffset: CGFloat = 15
        static let filterButtonSize: CGFloat = 50
        static let pipSize: CGFloat = 120
    }

    // MARK: - Animation
    enum Animation {
        static let standardDuration: TimeInterval = 0.3
        static let springDamping: CGFloat = 0.8
        static let swipeHintDelay: Double = 0.2
    }

    // MARK: - Keys
    enum Keys {
        static let hasLaunchedBefore = "hasLaunchedBefore"
        static let currentChannelName = "currentChannelName"
        static let currentMatchId = "currentMatchId"
        static let isCameraOn = "isCameraOn"
    }

    // MARK: - Firebase Paths
    enum FirebasePaths {
        static let users = "users"
        static let matchingQueue = "matching_queue"
        static let matches = "matches"
        static let presence = "presence"
        static let notifications = "notifications"
        static let userPresence = "user_presence"
    }
}