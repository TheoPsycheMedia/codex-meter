import Foundation
import XCTest
@testable import CodexMeter

final class SessionReadinessAdvisorTests: XCTestCase {
    func testStableComfortableWeeklyForecastIsReadyForSession() throws {
        let usage = try decodeUsage(primaryUsed: 18, weeklyUsed: 30)
        let advisor = SessionReadinessAdvisor()
        let now = date("2026-06-18T12:00:00Z")

        let advice = advisor.advice(
            usage: usage,
            forecasts: [
                makeForecast(
                    kind: .codexWeekly,
                    remaining: 70,
                    confidence: .stable,
                    estimatedRemaining: 54,
                    range: 54...54,
                    projectedExhaustionDate: nil,
                    resetAt: now.addingTimeInterval(86_400)
                )
            ],
            hasRunwayHistory: true,
            showSparkUsage: false,
            now: now
        )

        XCTAssertEqual(advice.level, .ready)
        XCTAssertEqual(advice.headline, L10n.text("sessionReadiness.ready.headline"))
    }

    func testProjectedExhaustionRecommendsSavingHeavyWork() throws {
        let usage = try decodeUsage(primaryUsed: 35, weeklyUsed: 72)
        let advisor = SessionReadinessAdvisor()
        let now = date("2026-06-18T12:00:00Z")
        let resetAt = now.addingTimeInterval(21_600)

        let advice = advisor.advice(
            usage: usage,
            forecasts: [
                makeForecast(
                    kind: .codexWeekly,
                    remaining: 28,
                    confidence: .variable,
                    estimatedRemaining: 0,
                    range: 0...12,
                    projectedExhaustionDate: now.addingTimeInterval(3_600),
                    resetAt: resetAt
                )
            ],
            hasRunwayHistory: true,
            showSparkUsage: false,
            now: now
        )

        XCTAssertEqual(advice.level, .save)
        XCTAssertEqual(advice.headline, L10n.text("sessionReadiness.save.headline"))
    }

    func testFreshResetHeadroomDoesNotRecommendSavingHeavyWork() throws {
        let usage = try decodeUsage(primaryUsed: 1, weeklyUsed: 0)
        let advisor = SessionReadinessAdvisor()
        let now = date("2026-06-18T12:00:00Z")

        let advice = advisor.advice(
            usage: usage,
            forecasts: [
                makeForecast(
                    kind: .codexPrimary,
                    remaining: 99,
                    confidence: .variable,
                    estimatedRemaining: 0,
                    range: 0...18,
                    projectedExhaustionDate: now.addingTimeInterval(17_700),
                    resetAt: now.addingTimeInterval(18_000)
                )
            ],
            hasRunwayHistory: true,
            showSparkUsage: false,
            now: now
        )

        XCTAssertEqual(advice.level, .ready)
        XCTAssertEqual(advice.headline, L10n.text("sessionReadiness.ready.headline"))
    }

    func testProjectedExhaustionAtTwoHoursRecommendsWatchingInsteadOfSaving() throws {
        let usage = try decodeUsage(primaryUsed: 28, weeklyUsed: 34)
        let advisor = SessionReadinessAdvisor()
        let now = date("2026-06-18T12:00:00Z")

        let advice = advisor.advice(
            usage: usage,
            forecasts: [
                makeForecast(
                    kind: .codexPrimary,
                    remaining: 72,
                    confidence: .variable,
                    estimatedRemaining: 0,
                    range: 0...15,
                    projectedExhaustionDate: now.addingTimeInterval(7_200),
                    resetAt: now.addingTimeInterval(18_000)
                )
            ],
            hasRunwayHistory: true,
            showSparkUsage: false,
            now: now
        )

        XCTAssertEqual(advice.level, .watch)
        XCTAssertEqual(advice.headline, L10n.text("sessionReadiness.watch.headline"))
    }

    func testResetBankDowngradesImmediateRiskToWatch() throws {
        let usage = try decodeUsage(primaryUsed: 92, weeklyUsed: 45)
        let advisor = SessionReadinessAdvisor()
        let now = date("2026-06-18T12:00:00Z")

        let advice = advisor.advice(
            usage: usage,
            forecasts: [],
            hasRunwayHistory: false,
            showSparkUsage: false,
            availableResetCount: 3,
            now: now
        )

        XCTAssertEqual(advice.level, .watch)
        XCTAssertEqual(advice.headline, L10n.text("sessionReadiness.watch.headline"))
    }

    func testVariableLowWeeklyEstimateRecommendsWatchingUsage() throws {
        let usage = try decodeUsage(primaryUsed: 20, weeklyUsed: 48)
        let advisor = SessionReadinessAdvisor()
        let now = date("2026-06-18T12:00:00Z")

        let advice = advisor.advice(
            usage: usage,
            forecasts: [
                makeForecast(
                    kind: .codexWeekly,
                    remaining: 52,
                    confidence: .variable,
                    estimatedRemaining: 31,
                    range: 22...48,
                    projectedExhaustionDate: nil,
                    resetAt: now.addingTimeInterval(86_400)
                )
            ],
            hasRunwayHistory: true,
            showSparkUsage: false,
            now: now
        )

        XCTAssertEqual(advice.level, .watch)
        XCTAssertEqual(advice.headline, L10n.text("sessionReadiness.watch.headline"))
    }

    func testMissingHistoryKeepsCoachInLearningMode() throws {
        let usage = try decodeUsage(primaryUsed: 10, weeklyUsed: 20)
        let advisor = SessionReadinessAdvisor()

        let advice = advisor.advice(
            usage: usage,
            forecasts: [],
            hasRunwayHistory: false,
            showSparkUsage: false,
            now: date("2026-06-18T12:00:00Z")
        )

        XCTAssertEqual(advice.level, .learning)
        XCTAssertEqual(advice.headline, L10n.text("sessionReadiness.learning.headline"))
    }

    private func decodeUsage(primaryUsed: Int, weeklyUsed: Int) throws -> UsageResponse {
        let json = """
        {
          "plan_type": "pro",
          "rate_limit": {
            "primary_window": {
              "used_percent": \(primaryUsed),
              "limit_window_seconds": 18000,
              "reset_after_seconds": 7200
            },
            "secondary_window": {
              "used_percent": \(weeklyUsed),
              "limit_window_seconds": 604800,
              "reset_after_seconds": 86400
            }
          }
        }
        """

        let data = try XCTUnwrap(json.data(using: .utf8))
        return try JSONDecoder().decode(UsageResponse.self, from: data)
    }

    private func makeForecast(
        kind: UsageWindowKind,
        remaining: Int,
        confidence: RunwayConfidence,
        estimatedRemaining: Double?,
        range: ClosedRange<Double>?,
        projectedExhaustionDate: Date?,
        resetAt: Date?
    ) -> UsageWindowForecast {
        UsageWindowForecast(
            id: kind,
            kind: kind,
            remainingPercent: remaining,
            confidence: confidence,
            isLimitedData: confidence == .limitedData,
            estimatedRemainingAtReset: estimatedRemaining,
            estimatedRemainingRangeAtReset: range,
            projectedExhaustionDate: projectedExhaustionDate,
            resetAt: resetAt,
            paceSummary: RunwayPaceSummary(lastHour: nil, lastDay: nil, currentWindow: nil)
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
