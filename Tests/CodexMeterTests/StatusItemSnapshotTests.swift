import XCTest
@testable import CodexMeter

final class StatusItemSnapshotTests: XCTestCase {
    func testDoesNotInventSparkWindowsWhenPayloadHasNoSparkLimit() throws {
        let usage = try decodeUsage(
            """
            {
              "rate_limit": {
                "primary_window": {
                  "used_percent": 20,
                  "limit_window_seconds": 18000,
                  "reset_after_seconds": 900
                }
              },
              "additional_rate_limits": []
            }
            """
        )

        let snapshot = StatusItemSnapshot(
            usage: usage,
            showSparkUsage: true,
            mode: .lowestWindowOnly,
            isLoading: false,
            errorMessage: nil,
            lastUpdated: Date(),
            staleAfterSeconds: 90
        )

        XCTAssertEqual(snapshot.windows.count, 1)
        XCTAssertFalse(snapshot.windows.contains { $0.isSpark })
        XCTAssertEqual(snapshot.statusText, "5h 80%")
    }

    func testStaleThresholdRespectsConfiguredRefreshCadence() throws {
        let usage = try decodeUsage(
            """
            {
              "rate_limit": {
                "primary_window": {
                  "used_percent": 20,
                  "limit_window_seconds": 18000,
                  "reset_after_seconds": 900
                }
              }
            }
            """
        )

        let freshSnapshot = StatusItemSnapshot(
            usage: usage,
            showSparkUsage: false,
            mode: .percentageOnly,
            isLoading: false,
            errorMessage: nil,
            lastUpdated: Date().addingTimeInterval(-30),
            staleAfterSeconds: 90
        )
        let staleSnapshot = StatusItemSnapshot(
            usage: usage,
            showSparkUsage: false,
            mode: .percentageOnly,
            isLoading: false,
            errorMessage: nil,
            lastUpdated: Date().addingTimeInterval(-120),
            staleAfterSeconds: 90
        )

        XCTAssertFalse(freshSnapshot.isStale)
        XCTAssertTrue(staleSnapshot.isStale)
    }

    private func decodeUsage(_ json: String) throws -> UsageResponse {
        let data = try XCTUnwrap(json.data(using: .utf8))
        return try JSONDecoder().decode(UsageResponse.self, from: data)
    }
}
