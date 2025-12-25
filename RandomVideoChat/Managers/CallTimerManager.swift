import Foundation
import Combine

/// Manages call timer logic including background handling and time synchronization
@MainActor
class CallTimerManager: ObservableObject {
    // MARK: - Published Properties
    @Published var timeRemaining: Int
    @Published var isTimerStarted = false

    // MARK: - Private Properties
    private var timer: Timer?
    private var backgroundStartTime: Date?
    private var backgroundTerminationWorkItem: DispatchWorkItem?
    private var isBackground = false

    // MARK: - Callbacks
    var onTimerExpired: (() -> Void)?
    var onTimeUpdated: ((Int) -> Void)?

    // MARK: - Constants
    private let backgroundTimeoutSeconds: TimeInterval = 60
    private let syncIntervalSeconds: Int = 5

    // MARK: - Initialization
    init(initialTime: Int = 5) {
        self.timeRemaining = initialTime
    }

    // MARK: - Public Methods

    /// Starts or restarts the timer
    func startTimer() {
        stopTimer()
        isTimerStarted = true

        #if DEBUG
        print("⏱ Timer started: \(timeRemaining)s")
        #endif

        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.tick()
            }
        }

        if let timer = timer {
            RunLoop.current.add(timer, forMode: .common)
        }
    }

    /// Stops the timer completely
    func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    /// Adds time to the timer
    /// - Parameter seconds: Number of seconds to add
    func addTime(_ seconds: Int) {
        timeRemaining += seconds
        onTimeUpdated?(timeRemaining)

        #if DEBUG
        print("⏱ Time added: +\(seconds)s, total: \(timeRemaining)s")
        #endif
    }

    /// Syncs time from external source (e.g., Firebase)
    /// - Parameter syncedTime: Time value from external source
    func syncTime(_ syncedTime: Int) {
        if syncedTime > timeRemaining {
            timeRemaining = syncedTime

            #if DEBUG
            print("⏱ Time synced: \(timeRemaining)s")
            #endif

            if isTimerStarted {
                startTimer()
            }
        }
    }

    /// Called when app enters background
    func handleEnterBackground() {
        guard !isBackground else { return }

        isBackground = true
        backgroundStartTime = Date()

        #if DEBUG
        print("📱 Background - pausing timer")
        #endif

        stopTimer()
        backgroundTerminationWorkItem?.cancel()

        let workItem = DispatchWorkItem { [weak self] in
            Task { @MainActor in
                guard let self = self, self.isBackground else { return }

                #if DEBUG
                print("📱 Background \(Int(self.backgroundTimeoutSeconds))s elapsed - triggering expiration")
                #endif

                self.onTimerExpired?()
            }
        }
        backgroundTerminationWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + backgroundTimeoutSeconds, execute: workItem)
    }

    /// Called when app returns to foreground
    /// - Returns: Duration spent in background
    @discardableResult
    func handleEnterForeground() -> TimeInterval {
        guard isBackground else { return 0 }

        let duration = backgroundStartTime.map { Date().timeIntervalSince($0) } ?? 0

        #if DEBUG
        print("📱 Foreground - background duration: \(String(format: "%.1f", duration))s")
        #endif

        isBackground = false
        backgroundStartTime = nil
        backgroundTerminationWorkItem?.cancel()
        backgroundTerminationWorkItem = nil

        if isTimerStarted {
            startTimer()
        }

        return duration
    }

    /// Cleans up all resources
    func cleanup() {
        stopTimer()
        backgroundTerminationWorkItem?.cancel()
        backgroundTerminationWorkItem = nil
        backgroundStartTime = nil
        isBackground = false
        isTimerStarted = false
    }

    // MARK: - Private Methods

    private func tick() {
        guard timeRemaining > 0 else {
            #if DEBUG
            print("⏱ Timer expired - ending call")
            #endif
            stopTimer()
            onTimerExpired?()
            return
        }

        timeRemaining -= 1

        // Sync every N seconds
        if timeRemaining % syncIntervalSeconds == 0 {
            onTimeUpdated?(timeRemaining)
        }
    }
}
