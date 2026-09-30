import Foundation
import XCTest
@testable import CodexMeter

final class CodexAuthTokenReaderTests: XCTestCase {
    func testReadsAndTrimsTheSelectedAccountAndTokenTogether() throws {
        try withAuth(tokens: ["access_token": " test-token\n", "account_id": " test-account "]) { reader in
            let credentials = try reader.credentials()
            XCTAssertEqual(credentials.accessToken, "test-token")
            XCTAssertEqual(credentials.accountID, "test-account")
        }
    }

    func testMissingOrBlankAccountCannotRequestUnscopedUsage() throws {
        for tokens in [["access_token": "test-token"], ["access_token": "test-token", "account_id": " \n"]] {
            try withAuth(tokens: tokens) { reader in
                XCTAssertThrowsError(try reader.credentials()) { error in
                    XCTAssertEqual(error as? CodexAuthError, .missingAccountID)
                }
            }
        }
    }

    func testBlankTokenIsRejected() throws {
        try withAuth(tokens: ["access_token": " ", "account_id": "test-account"]) { reader in
            XCTAssertThrowsError(try reader.credentials()) { error in
                XCTAssertEqual(error as? CodexAuthError, .missingAccessToken)
            }
        }
    }

    private func withAuth(tokens: [String: String], body: (CodexAuthTokenReader) throws -> Void) throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("codexmeter-test-\(UUID().uuidString).json")
        let data = try JSONSerialization.data(withJSONObject: ["tokens": tokens])
        try data.write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }
        try body(CodexAuthTokenReader(authURL: url))
    }
}
