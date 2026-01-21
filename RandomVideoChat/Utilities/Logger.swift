import Foundation

// MARK: - Log Level
enum LogLevel: Int, Comparable {
    case debug = 0
    case info = 1
    case warning = 2
    case error = 3

    var prefix: String {
        switch self {
        case .debug: return "🔍"
        case .info: return "ℹ️"
        case .warning: return "⚠️"
        case .error: return "❌"
        }
    }

    var label: String {
        switch self {
        case .debug: return "DEBUG"
        case .info: return "INFO"
        case .warning: return "WARNING"
        case .error: return "ERROR"
        }
    }

    static func < (lhs: LogLevel, rhs: LogLevel) -> Bool {
        return lhs.rawValue < rhs.rawValue
    }
}

// MARK: - Log Category
enum LogCategory: String {
    case auth = "Auth"
    case user = "User"
    case matching = "Matching"
    case agora = "Agora"
    case network = "Network"
    case camera = "Camera"
    case store = "Store"
    case permission = "Permission"
    case general = "General"
    case ui = "UI"
    case data = "Data"
}

// MARK: - AppLogger
final class AppLogger {
    static let shared = AppLogger()

    #if DEBUG
    private var minimumLevel: LogLevel = .debug
    #else
    private var minimumLevel: LogLevel = .error
    #endif

    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter
    }()

    private init() {}

    // MARK: - Configuration

    func setMinimumLevel(_ level: LogLevel) {
        minimumLevel = level
    }

    // MARK: - Logging Methods

    func debug(_ message: String, category: LogCategory = .general, file: String = #file, function: String = #function, line: Int = #line) {
        log(level: .debug, message: message, category: category, file: file, function: function, line: line)
    }

    func info(_ message: String, category: LogCategory = .general, file: String = #file, function: String = #function, line: Int = #line) {
        log(level: .info, message: message, category: category, file: file, function: function, line: line)
    }

    func warning(_ message: String, category: LogCategory = .general, file: String = #file, function: String = #function, line: Int = #line) {
        log(level: .warning, message: message, category: category, file: file, function: function, line: line)
    }

    func error(_ message: String, category: LogCategory = .general, file: String = #file, function: String = #function, line: Int = #line) {
        log(level: .error, message: message, category: category, file: file, function: function, line: line)
    }

    func error(_ error: Error, context: String = "", category: LogCategory = .general, file: String = #file, function: String = #function, line: Int = #line) {
        let message = context.isEmpty ? error.localizedDescription : "\(context): \(error.localizedDescription)"
        log(level: .error, message: message, category: category, file: file, function: function, line: line)
    }

    // MARK: - Private

    private func log(level: LogLevel, message: String, category: LogCategory, file: String, function: String, line: Int) {
        guard level >= minimumLevel else { return }

        #if DEBUG
        let timestamp = dateFormatter.string(from: Date())
        let fileName = (file as NSString).lastPathComponent
        let logMessage = "\(level.prefix) [\(timestamp)] [\(category.rawValue)] \(message)"

        if level >= .warning {
            print("\(logMessage) (\(fileName):\(line))")
        } else {
            print(logMessage)
        }
        #endif
    }
}

// MARK: - Convenience Global Functions
func logDebug(_ message: String, category: LogCategory = .general, file: String = #file, function: String = #function, line: Int = #line) {
    AppLogger.shared.debug(message, category: category, file: file, function: function, line: line)
}

func logInfo(_ message: String, category: LogCategory = .general, file: String = #file, function: String = #function, line: Int = #line) {
    AppLogger.shared.info(message, category: category, file: file, function: function, line: line)
}

func logWarning(_ message: String, category: LogCategory = .general, file: String = #file, function: String = #function, line: Int = #line) {
    AppLogger.shared.warning(message, category: category, file: file, function: function, line: line)
}

func logError(_ message: String, category: LogCategory = .general, file: String = #file, function: String = #function, line: Int = #line) {
    AppLogger.shared.error(message, category: category, file: file, function: function, line: line)
}

func logError(_ error: Error, context: String = "", category: LogCategory = .general, file: String = #file, function: String = #function, line: Int = #line) {
    AppLogger.shared.error(error, context: context, category: category, file: file, function: function, line: line)
}
