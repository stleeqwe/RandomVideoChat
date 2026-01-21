//
//  ErrorsTests.swift
//  RandomVideoChatTests
//

import XCTest
@testable import RandomVideoChat

final class ErrorsTests: XCTestCase {

    // MARK: - AuthError Tests

    func testAuthErrorUserMessages() {
        XCTAssertFalse(AuthError.noUserReturned.userMessage.isEmpty)
        XCTAssertFalse(AuthError.noAuthenticatedUser.userMessage.isEmpty)
        XCTAssertFalse(AuthError.requiresReAuthentication.userMessage.isEmpty)
        XCTAssertFalse(AuthError.invalidCredentials.userMessage.isEmpty)
        XCTAssertFalse(AuthError.appleSignInFailed(reason: "test").userMessage.isEmpty)
    }

    func testAuthErrorLogMessages() {
        XCTAssertFalse(AuthError.noUserReturned.logMessage.isEmpty)
        XCTAssertFalse(AuthError.noAuthenticatedUser.logMessage.isEmpty)

        let underlyingError = NSError(domain: "test", code: 1, userInfo: nil)
        let signInError = AuthError.signInFailed(underlying: underlyingError)
        XCTAssertTrue(signInError.logMessage.contains("Sign in failed"))
    }

    // MARK: - NetworkError Tests

    func testNetworkErrorUserMessages() {
        XCTAssertFalse(NetworkError.noConnection.userMessage.isEmpty)
        XCTAssertFalse(NetworkError.timeout.userMessage.isEmpty)
        XCTAssertFalse(NetworkError.serverError(statusCode: 500).userMessage.isEmpty)
        XCTAssertFalse(NetworkError.invalidResponse.userMessage.isEmpty)
    }

    func testNetworkErrorLogMessages() {
        XCTAssertTrue(NetworkError.serverError(statusCode: 500).logMessage.contains("500"))
        XCTAssertTrue(NetworkError.noConnection.logMessage.contains("No connection"))
    }

    // MARK: - MatchingError Tests

    func testMatchingErrorEquality() {
        XCTAssertEqual(MatchingError.timeout, MatchingError.timeout)
        XCTAssertEqual(MatchingError.cancelled, MatchingError.cancelled)
        XCTAssertEqual(MatchingError.notAuthenticated, MatchingError.notAuthenticated)
        XCTAssertNotEqual(MatchingError.timeout, MatchingError.cancelled)
    }

    func testMatchingErrorUserMessages() {
        XCTAssertFalse(MatchingError.alreadyMatching.userMessage.isEmpty)
        XCTAssertFalse(MatchingError.matchingFailed.userMessage.isEmpty)
        XCTAssertFalse(MatchingError.opponentDisconnected.userMessage.isEmpty)
        XCTAssertFalse(MatchingError.timeout.userMessage.isEmpty)
        XCTAssertFalse(MatchingError.cancelled.userMessage.isEmpty)
    }

    // MARK: - StoreError Tests

    func testStoreErrorUserMessages() {
        XCTAssertFalse(StoreError.productNotFound.userMessage.isEmpty)
        XCTAssertFalse(StoreError.purchaseCancelled.userMessage.isEmpty)
        XCTAssertFalse(StoreError.notAuthorized.userMessage.isEmpty)
        XCTAssertFalse(StoreError.networkError.userMessage.isEmpty)
    }

    // MARK: - DataError Tests

    func testDataErrorUserMessages() {
        let underlyingError = NSError(domain: "test", code: 1, userInfo: nil)

        XCTAssertFalse(DataError.saveFailed(underlying: underlyingError).userMessage.isEmpty)
        XCTAssertFalse(DataError.loadFailed(underlying: underlyingError).userMessage.isEmpty)
        XCTAssertFalse(DataError.invalidData.userMessage.isEmpty)
        XCTAssertFalse(DataError.notFound.userMessage.isEmpty)
    }

    func testDataErrorLogMessages() {
        let underlyingError = NSError(domain: "test", code: 1, userInfo: nil)

        XCTAssertTrue(DataError.saveFailed(underlying: underlyingError).logMessage.contains("Save failed"))
        XCTAssertTrue(DataError.loadFailed(underlying: underlyingError).logMessage.contains("Load failed"))
    }

    // MARK: - ErrorHandler Tests

    func testErrorHandlerSharedInstance() {
        let handler1 = ErrorHandler.shared
        let handler2 = ErrorHandler.shared
        XCTAssertTrue(handler1 === handler2)
    }

    func testErrorHandlerUserMessageForAppError() {
        let authError = AuthError.noAuthenticatedUser
        let message = ErrorHandler.shared.userMessage(for: authError)
        XCTAssertEqual(message, authError.userMessage)
    }

    func testErrorHandlerUserMessageForGenericError() {
        let genericError = NSError(domain: "generic", code: 999, userInfo: nil)
        let message = ErrorHandler.shared.userMessage(for: genericError)
        XCTAssertFalse(message.isEmpty)
    }

    func testErrorHandlerHandle() {
        let error = MatchingError.timeout
        let message = ErrorHandler.shared.handle(error, context: "Test")
        XCTAssertEqual(message, error.userMessage)
    }
}
