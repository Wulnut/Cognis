//
//  CognisErrorTests.swift
//  CognisCoreTests
//
//  CognisError 单元测试
//

import XCTest
@testable import CognisCore

final class CognisErrorTests: XCTestCase {

    func testConnectionFailedErrorDescription() {
        let error = CognisError.connectionFailed(reason: "Network timeout")
        XCTAssertEqual(error.errorDescription, "Connection failed: Network timeout")
    }

    func testAuthenticationErrorDescription() {
        let error = CognisError.authenticationError(reason: "Invalid password")
        XCTAssertEqual(error.errorDescription, "Authentication failed: Invalid password")
    }

    func testSilentChannelErrorDescription() {
        let error = CognisError.silentChannelError(reason: "Channel closed")
        XCTAssertEqual(error.errorDescription, "Silent channel error: Channel closed")
    }

    func testSessionNotFoundErrorDescription() {
        let uuid = UUID()
        let error = CognisError.sessionNotFound(id: uuid)
        XCTAssertEqual(error.errorDescription, "Session not found: \(uuid)")
    }

    func testRecoverySuggestion() {
        let error = CognisError.connectionTimeout
        XCTAssertNotNil(error.recoverySuggestion)
        XCTAssertTrue(error.recoverySuggestion!.contains("network"))
    }

    func testErrorEquality() {
        let error1 = CognisError.connectionTimeout
        let error2 = CognisError.connectionTimeout
        XCTAssertEqual(error1, error2)

        let error3 = CognisError.connectionRefused
        XCTAssertNotEqual(error1, error3)
    }
}
