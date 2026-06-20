import XCTest
@testable import CodexMeter

final class DiagnosticsBuilderTests: XCTestCase {
    func testDiagnosticsIncludeMetadataAndExcludeSensitiveValues() {
        var usageState = EndpointRefreshState.idle(.usage)
        usageState.recordSuccess(at: Date(timeIntervalSince1970: 1_893_456_000))

        var resetState = EndpointRefreshState.idle(.resetCredits)
        resetState.recordFailure(
            EndpointFailure(
                endpoint: .resetCredits,
                category: .schemaMismatch,
                statusCode: 200,
                decoderPath: "credits.0.expires_at",
                recognizedKeys: ["available_count", "credits", "new_top_level_key"],
                message: "Could not decode reset-credit response.",
                recoverySuggestion: "Copy diagnostics."
            ),
            hasPriorData: true
        )

        let diagnostics = DiagnosticsBuilder.build(
            DiagnosticsInput(
                appVersion: "0.1.0-test",
                macOSVersion: "macOS test",
                generatedAt: Date(timeIntervalSince1970: 1_893_459_600),
                autoRefreshEnabled: true,
                refreshIntervalSeconds: 60,
                meterStyle: .circular,
                hasUsageData: true,
                hasResetCreditData: true,
                usageState: usageState,
                resetCreditState: resetState
            )
        )

        XCTAssertTrue(diagnostics.contains("App version: 0.1.0-test"))
        XCTAssertTrue(diagnostics.contains("Path: /backend-api/wham/rate-limit-reset-credits"))
        XCTAssertTrue(diagnostics.contains("Failure category: schemaMismatch"))
        XCTAssertTrue(diagnostics.contains("HTTP status: 200"))
        XCTAssertTrue(diagnostics.contains("Decoder path: credits.0.expires_at"))
        XCTAssertTrue(diagnostics.contains("Recognized keys: available_count, credits, new_top_level_key"))
        XCTAssertTrue(diagnostics.contains("Privacy: tokens, cookies, auth files"))

        XCTAssertFalse(diagnostics.contains("Bearer "))
        XCTAssertFalse(diagnostics.contains("access_token"))
        XCTAssertFalse(diagnostics.contains("sk-"))
        XCTAssertFalse(diagnostics.contains("raw_json"))
    }
}
