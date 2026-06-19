import Foundation
import XCTest
@testable import CodexMeter

final class RunwayPredictionServiceTests: XCTestCase {
    func testLimitedDataForecastIsLimited() throws {
        let service = RunwayPredictionService()

        let observations: [UsageWindowObservation] = [
            makeObservation(
                sampledAt: date("2026-06-18T10:00:00Z"),
                kind: .codexPrimary,
                remaining: 100,
                used: 0,
                resetAt: date("2026-06-18T15:00:00Z")
            )
        ]

        let forecast = service.predict(for: observations, now: date("2026-06-18T10:00:30Z"))

        XCTAssertEqual(forecast.isLimitedData, true)
        XCTAssertEqual(forecast.confidence, .limitedData)
    }

    func testStableHistoryYieldsStableConfidence() throws {
        let fixture = try loadFixture()
        let service = RunwayPredictionService()
        let now = date("2026-06-18T12:30:00Z")
        let observations = fixture.stable

        let forecast = service.predict(for: observations, now: now)

        XCTAssertEqual(forecast.confidence, .stable)
        XCTAssertFalse(forecast.isLimitedData)
        XCTAssertNotNil(forecast.estimatedRemainingAtReset)
        XCTAssertLessThanOrEqual(forecast.estimatedRemainingAtReset ?? 0, 100)
        XCTAssertEqual(forecast.willExhaustBeforeReset, false)
    }

    func testVariableHistoryYieldsVariableConfidence() throws {
        let fixture = try loadFixture()
        let service = RunwayPredictionService()
        let now = date("2026-06-18T12:30:00Z")
        let observations = fixture.variable

        let forecast = service.predict(for: observations, now: now)

        XCTAssertEqual(forecast.confidence, .variable)
        XCTAssertFalse(forecast.isLimitedData)
        XCTAssertNotNil(forecast.estimatedRemainingRangeAtReset)
        if let range = forecast.estimatedRemainingRangeAtReset {
            XCTAssertTrue(range.lowerBound >= 0 && range.upperBound <= 100)
        }
    }

    func testSingleBurstDoesNotDominateVariableRange() throws {
        let service = RunwayPredictionService()
        let observations = [
            makeObservation(
                sampledAt: date("2026-06-18T10:00:00Z"),
                kind: .codexWeekly,
                remaining: 100,
                used: 0,
                resetAt: date("2026-06-19T01:00:00Z")
            ),
            makeObservation(
                sampledAt: date("2026-06-18T11:00:00Z"),
                kind: .codexWeekly,
                remaining: 99,
                used: 1,
                resetAt: date("2026-06-19T01:00:00Z")
            ),
            makeObservation(
                sampledAt: date("2026-06-18T12:00:00Z"),
                kind: .codexWeekly,
                remaining: 98,
                used: 2,
                resetAt: date("2026-06-19T01:00:00Z")
            ),
            makeObservation(
                sampledAt: date("2026-06-18T13:00:00Z"),
                kind: .codexWeekly,
                remaining: 93,
                used: 7,
                resetAt: date("2026-06-19T01:00:00Z")
            ),
            makeObservation(
                sampledAt: date("2026-06-18T14:00:00Z"),
                kind: .codexWeekly,
                remaining: 92,
                used: 8,
                resetAt: date("2026-06-19T01:00:00Z")
            ),
            makeObservation(
                sampledAt: date("2026-06-18T15:00:00Z"),
                kind: .codexWeekly,
                remaining: 91,
                used: 9,
                resetAt: date("2026-06-19T01:00:00Z")
            )
        ]

        let forecast = service.predict(for: observations, now: date("2026-06-18T15:00:00Z"))

        XCTAssertEqual(forecast.confidence, .variable)
        XCTAssertFalse(forecast.willExhaustBeforeReset)
        XCTAssertGreaterThan(forecast.estimatedRemainingAtReset ?? 0, 60)
        if let range = forecast.estimatedRemainingRangeAtReset {
            XCTAssertGreaterThan(range.lowerBound, 60)
        } else {
            XCTFail("Expected a percentile range for variable usage.")
        }
    }

    func testForecastFallsBackToResetAfterSecondsWhenResetDateIsMissing() throws {
        let service = RunwayPredictionService()
        let now = date("2026-06-18T12:00:00Z")
        let observations = [
            makeObservation(
                sampledAt: date("2026-06-18T10:00:00Z"),
                kind: .codexWeekly,
                remaining: 100,
                used: 0,
                resetAt: nil
            ),
            makeObservation(
                sampledAt: date("2026-06-18T11:00:00Z"),
                kind: .codexWeekly,
                remaining: 99,
                used: 1,
                resetAt: nil
            ),
            makeObservation(
                sampledAt: now,
                kind: .codexWeekly,
                remaining: 98,
                used: 2,
                resetAt: nil
            )
        ]

        let forecast = service.predict(for: observations, now: now)

        XCTAssertEqual(forecast.resetAt, now.addingTimeInterval(18_000))
    }

    func testRunawayConsumptionIsFlaggedBeforeReset() throws {
        // A window burning fast enough to exceed 200%/hr must still be flagged as
        // projected-to-exhaust-before-reset. A prior `0..<200 ~= Int(rate)` filter
        // discarded exactly this runaway case from the pace summary.
        let service = RunwayPredictionService()
        let now = date("2026-06-18T10:40:00Z")
        let resetAt = date("2026-06-18T15:00:00Z")
        let observations = [
            makeObservation(sampledAt: date("2026-06-18T10:00:00Z"), kind: .codexPrimary, remaining: 100, used: 0, resetAt: resetAt),
            makeObservation(sampledAt: date("2026-06-18T10:20:00Z"), kind: .codexPrimary, remaining: 60, used: 40, resetAt: resetAt),
            makeObservation(sampledAt: now, kind: .codexPrimary, remaining: 20, used: 80, resetAt: resetAt)
        ]

        let forecast = service.predict(for: observations, now: now)

        XCTAssertFalse(forecast.isLimitedData)
        XCTAssertTrue(forecast.willExhaustBeforeReset)
        let exhaustion = try XCTUnwrap(forecast.projectedExhaustionDate)
        XCTAssertGreaterThanOrEqual(exhaustion, now)
        XCTAssertLessThan(exhaustion, resetAt)
        XCTAssertNotNil(forecast.paceSummary)
    }

    func testPastResetAtProducesFutureForecastReset() throws {
        // If the backend hands back a stale `reset_at` in the past, the forecast
        // must never anchor to a past moment (which would render "run out before
        // reset" against a past timestamp).
        let service = RunwayPredictionService()
        let now = date("2026-06-18T12:00:00Z")
        let staleReset = date("2026-06-18T11:00:00Z")
        let observations = [
            makeObservation(sampledAt: date("2026-06-18T10:00:00Z"), kind: .codexWeekly, remaining: 100, used: 0, resetAt: staleReset),
            makeObservation(sampledAt: date("2026-06-18T11:00:00Z"), kind: .codexWeekly, remaining: 99, used: 1, resetAt: staleReset),
            makeObservation(sampledAt: now, kind: .codexWeekly, remaining: 98, used: 2, resetAt: staleReset)
        ]

        let forecast = service.predict(for: observations, now: now)

        let forecastReset = try XCTUnwrap(forecast.resetAt)
        XCTAssertGreaterThan(forecastReset, now)
        XCTAssertEqual(forecastReset, now.addingTimeInterval(18_000))
    }

    private func loadFixture() throws -> RunwayFixture {
        let bundle = Bundle.module
        guard let fixtureURL = bundle.url(forResource: "RunwayPredictionFixtures", withExtension: "json") else {
            throw NSError(domain: "RunwayPredictionServiceTests", code: 1)
        }

        let fixtureData = try Data(contentsOf: fixtureURL)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(RunwayFixture.self, from: fixtureData)
    }

    private func makeObservation(
        sampledAt: Date,
        kind: UsageWindowKind,
        remaining: Int,
        used: Int,
        resetAt: Date?
    ) -> UsageWindowObservation {
        UsageWindowObservation(
            sampledAt: sampledAt,
            kind: kind,
            remainingPercent: remaining,
            usedPercent: used,
            limitWindowSeconds: 18_000,
            resetAfterSeconds: 18_000,
            resetAt: resetAt
        )
    }

    private func date(_ iso8601: String) -> Date {
        let formatter = ISO8601DateFormatter()
        guard let parsed = formatter.date(from: iso8601) else {
            return Date()
        }
        return parsed
    }
}

private struct RunwayFixture: Decodable {
    let stable: [UsageWindowObservation]
    let variable: [UsageWindowObservation]
}
