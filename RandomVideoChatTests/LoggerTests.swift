//
//  LoggerTests.swift
//  RandomVideoChatTests
//

import XCTest
@testable import RandomVideoChat

final class LoggerTests: XCTestCase {

    // MARK: - Log Level Tests

    func testLogLevelComparison() {
        XCTAssertTrue(LogLevel.debug < LogLevel.info)
        XCTAssertTrue(LogLevel.info < LogLevel.warning)
        XCTAssertTrue(LogLevel.warning < LogLevel.error)
    }

    func testLogLevelPrefix() {
        XCTAssertFalse(LogLevel.debug.prefix.isEmpty)
        XCTAssertFalse(LogLevel.info.prefix.isEmpty)
        XCTAssertFalse(LogLevel.warning.prefix.isEmpty)
        XCTAssertFalse(LogLevel.error.prefix.isEmpty)
    }

    func testLogLevelLabel() {
        XCTAssertEqual(LogLevel.debug.label, "DEBUG")
        XCTAssertEqual(LogLevel.info.label, "INFO")
        XCTAssertEqual(LogLevel.warning.label, "WARNING")
        XCTAssertEqual(LogLevel.error.label, "ERROR")
    }

    // MARK: - Log Category Tests

    func testLogCategoryRawValues() {
        XCTAssertEqual(LogCategory.auth.rawValue, "Auth")
        XCTAssertEqual(LogCategory.user.rawValue, "User")
        XCTAssertEqual(LogCategory.matching.rawValue, "Matching")
        XCTAssertEqual(LogCategory.agora.rawValue, "Agora")
        XCTAssertEqual(LogCategory.network.rawValue, "Network")
        XCTAssertEqual(LogCategory.permission.rawValue, "Permission")
        XCTAssertEqual(LogCategory.general.rawValue, "General")
    }

    // MARK: - Logger Singleton Tests

    func testLoggerSharedInstance() {
        let logger1 = Logger.shared
        let logger2 = Logger.shared
        XCTAssertTrue(logger1 === logger2)
    }

    // MARK: - Logger Method Tests (Smoke tests - just verify they don't crash)

    func testLoggerDebugDoesNotCrash() {
        Logger.shared.debug("Test debug message", category: .general)
    }

    func testLoggerInfoDoesNotCrash() {
        Logger.shared.info("Test info message", category: .user)
    }

    func testLoggerWarningDoesNotCrash() {
        Logger.shared.warning("Test warning message", category: .network)
    }

    func testLoggerErrorDoesNotCrash() {
        Logger.shared.error("Test error message", category: .auth)
    }

    func testLoggerErrorWithErrorObject() {
        let testError = NSError(domain: "TestDomain", code: 123, userInfo: nil)
        Logger.shared.error(testError, context: "Test context", category: .data)
    }

    // MARK: - Global Function Tests

    func testGlobalLogFunctionsDoNotCrash() {
        logDebug("Global debug", category: .general)
        logInfo("Global info", category: .user)
        logWarning("Global warning", category: .network)
        logError("Global error", category: .auth)

        let testError = NSError(domain: "TestDomain", code: 456, userInfo: nil)
        logError(testError, context: "Global context", category: .data)
    }
}
