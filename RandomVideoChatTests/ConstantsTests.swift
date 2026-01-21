//
//  ConstantsTests.swift
//  RandomVideoChatTests
//

import XCTest
@testable import RandomVideoChat

final class ConstantsTests: XCTestCase {

    // MARK: - Timing Constants Tests

    func testTimingConstants() {
        XCTAssertEqual(Constants.Timing.callInitialDuration, 5)
        XCTAssertEqual(Constants.Timing.heartExtensionDuration, 60)
        XCTAssertEqual(Constants.Timing.matchingTimeout, 120)
        XCTAssertEqual(Constants.Timing.presenceTimeout, 15)
        XCTAssertEqual(Constants.Timing.joinTimeout, 30)
    }

    // MARK: - Hearts Constants Tests

    func testHeartsConstants() {
        XCTAssertEqual(Constants.Hearts.defaultCount, 3)
        XCTAssertEqual(Constants.Hearts.dailyRewardCount, 1)
        XCTAssertGreaterThan(Constants.Hearts.pricePerHeart, 0)
    }

    // MARK: - Matching Constants Tests

    func testMatchingConstants() {
        XCTAssertEqual(Constants.Matching.maxRetries, 3)
        XCTAssertGreaterThan(Constants.Matching.retryDelay, 0)
        XCTAssertEqual(Constants.Matching.maxRecentMatches, 5)
    }

    // MARK: - Video Constants Tests

    func testVideoConstants() {
        XCTAssertEqual(Constants.Video.defaultWidth, 640)
        XCTAssertEqual(Constants.Video.defaultHeight, 480)
        XCTAssertEqual(Constants.Video.defaultFrameRate, 24)
        XCTAssertGreaterThan(Constants.Video.defaultBitrate, 0)
    }

    // MARK: - UI Constants Tests

    func testUIConstants() {
        XCTAssertGreaterThan(Constants.UI.cornerRadius, 0)
        XCTAssertGreaterThan(Constants.UI.buttonPadding, 0)
        XCTAssertGreaterThan(Constants.UI.iconSize, 0)
        XCTAssertEqual(Constants.UI.swipeThreshold, 50)
    }

    // MARK: - Animation Constants Tests

    func testAnimationConstants() {
        XCTAssertGreaterThan(Constants.Animation.standardDuration, 0)
        XCTAssertLessThanOrEqual(Constants.Animation.springDamping, 1.0)
    }

    // MARK: - Keys Constants Tests

    func testKeysConstants() {
        XCTAssertFalse(Constants.Keys.hasLaunchedBefore.isEmpty)
        XCTAssertFalse(Constants.Keys.currentChannelName.isEmpty)
        XCTAssertFalse(Constants.Keys.currentMatchId.isEmpty)
        XCTAssertFalse(Constants.Keys.isCameraOn.isEmpty)
    }

    // MARK: - Firebase Paths Tests

    func testFirebasePathsConstants() {
        XCTAssertEqual(Constants.FirebasePaths.users, "users")
        XCTAssertEqual(Constants.FirebasePaths.matchingQueue, "matching_queue")
        XCTAssertEqual(Constants.FirebasePaths.matches, "matches")
        XCTAssertEqual(Constants.FirebasePaths.presence, "presence")
        XCTAssertEqual(Constants.FirebasePaths.notifications, "notifications")
    }
}
