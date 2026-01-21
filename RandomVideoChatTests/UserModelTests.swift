//
//  UserModelTests.swift
//  RandomVideoChatTests
//

import XCTest
@testable import RandomVideoChat

final class UserModelTests: XCTestCase {

    // MARK: - Initialization Tests

    func testUserInitialization() {
        let user = User(uid: "test-uid")

        XCTAssertEqual(user.uid, "test-uid")
        XCTAssertNil(user.email)
        XCTAssertNil(user.displayName)
        XCTAssertEqual(user.heartCount, 3)
        XCTAssertTrue(user.blockedUsers.isEmpty)
        XCTAssertNil(user.gender)
        XCTAssertNil(user.preferredGender)
        XCTAssertFalse(user.ageVerified)
        XCTAssertEqual(user.authProvider, "anonymous")
        XCTAssertEqual(user.totalCallCount, 0)
        XCTAssertTrue(user.uniqueHeartGivers.isEmpty)
        XCTAssertEqual(user.preferenceRate, 50.0)
    }

    func testUserInitializationWithEmail() {
        let user = User(uid: "test-uid", email: "test@example.com", displayName: "Test User")

        XCTAssertEqual(user.uid, "test-uid")
        XCTAssertEqual(user.email, "test@example.com")
        XCTAssertEqual(user.displayName, "Test User")
    }

    // MARK: - Terms Agreement Tests

    func testHasAgreedToTermsWhenBothAreNil() {
        let user = User(uid: "test-uid")
        XCTAssertFalse(user.hasAgreedToTerms)
    }

    func testHasAgreedToTermsWhenBothAreSet() {
        var user = User(uid: "test-uid")
        user.termsAgreedAt = Date()
        user.privacyAgreedAt = Date()
        XCTAssertTrue(user.hasAgreedToTerms)
    }

    func testHasAgreedToTermsWhenOnlyTermsIsSet() {
        var user = User(uid: "test-uid")
        user.termsAgreedAt = Date()
        XCTAssertFalse(user.hasAgreedToTerms)
    }

    // MARK: - Age Calculation Tests

    func testAgeCalculationWithNilBirthDate() {
        let user = User(uid: "test-uid")
        XCTAssertNil(user.age)
    }

    func testAgeCalculationWithBirthDate() {
        var user = User(uid: "test-uid")
        let calendar = Calendar.current
        let birthDate = calendar.date(byAdding: .year, value: -25, to: Date())!
        user.birthDate = birthDate

        XCTAssertNotNil(user.age)
        XCTAssertEqual(user.age, 25)
    }

    // MARK: - Dictionary Conversion Tests

    func testDictionaryConversion() {
        var user = User(uid: "test-uid", email: "test@example.com")
        user.gender = .male
        user.preferredGender = .female
        user.heartCount = 5

        let dict = user.dictionary

        XCTAssertEqual(dict["uid"] as? String, "test-uid")
        XCTAssertEqual(dict["email"] as? String, "test@example.com")
        XCTAssertEqual(dict["gender"] as? String, "male")
        XCTAssertEqual(dict["preferredGender"] as? String, "female")
        XCTAssertEqual(dict["heartCount"] as? Int, 5)
    }

    // MARK: - Gender Tests

    func testGenderDisplayNames() {
        XCTAssertEqual(Gender.male.displayName, "남")
        XCTAssertEqual(Gender.female.displayName, "여")
    }

    func testGenderIcons() {
        XCTAssertEqual(Gender.male.icon, "person.fill")
        XCTAssertEqual(Gender.female.icon, "person.fill")
    }

    func testGenderRawValues() {
        XCTAssertEqual(Gender.male.rawValue, "male")
        XCTAssertEqual(Gender.female.rawValue, "female")
    }

    func testGenderAllCases() {
        XCTAssertEqual(Gender.allCases.count, 2)
        XCTAssertTrue(Gender.allCases.contains(.male))
        XCTAssertTrue(Gender.allCases.contains(.female))
    }
}
