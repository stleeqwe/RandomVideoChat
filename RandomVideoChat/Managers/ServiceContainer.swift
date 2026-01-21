import Foundation

// MARK: - Service Container Protocol
protocol ServiceContainerProtocol {
    var userRepository: UserRepositoryProtocol { get }
    var matchingRepository: MatchingRepositoryProtocol { get }
    var permissionManager: PermissionManagerProtocol { get }
}

// MARK: - Service Container Implementation
final class ServiceContainer: ServiceContainerProtocol {
    static let shared = ServiceContainer()

    // MARK: - Repositories
    lazy var userRepository: UserRepositoryProtocol = UserRepository.shared
    lazy var matchingRepository: MatchingRepositoryProtocol = MatchingRepository.shared

    // MARK: - Managers
    lazy var permissionManager: PermissionManagerProtocol = PermissionManager.shared

    private init() {
        logInfo("ServiceContainer initialized", category: .general)
    }
}

// MARK: - Mock Service Container for Testing
#if DEBUG
final class MockServiceContainer: ServiceContainerProtocol {
    var userRepository: UserRepositoryProtocol
    var matchingRepository: MatchingRepositoryProtocol
    var permissionManager: PermissionManagerProtocol

    init(
        userRepository: UserRepositoryProtocol? = nil,
        matchingRepository: MatchingRepositoryProtocol? = nil,
        permissionManager: PermissionManagerProtocol? = nil
    ) {
        self.userRepository = userRepository ?? UserRepository.shared
        self.matchingRepository = matchingRepository ?? MatchingRepository.shared
        self.permissionManager = permissionManager ?? PermissionManager.shared
    }
}
#endif

// MARK: - Service Locator (Global Access)
enum Services {
    private static var container: ServiceContainerProtocol = ServiceContainer.shared

    static var userRepository: UserRepositoryProtocol {
        container.userRepository
    }

    static var matchingRepository: MatchingRepositoryProtocol {
        container.matchingRepository
    }

    static var permissionManager: PermissionManagerProtocol {
        container.permissionManager
    }

    #if DEBUG
    static func setContainer(_ newContainer: ServiceContainerProtocol) {
        container = newContainer
    }

    static func reset() {
        container = ServiceContainer.shared
    }
    #endif
}
