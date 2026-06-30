import Foundation

enum SessionReadinessLevel: String, Equatable {
    case ready
    case watch
    case save
    case learning
    case unavailable
}

struct SessionReadinessAdvice: Equatable {
    let level: SessionReadinessLevel
    let title: String
    let headline: String
    let detail: String
    let systemName: String
}

final class SessionReadinessAdvisor {
    private let redProjectedRunwaySeconds: TimeInterval = 3_600
    private let yellowProjectedRunwaySeconds: TimeInterval = 7_200

    func advice(
        usage: UsageResponse?,
        forecasts: [UsageWindowForecast],
        hasRunwayHistory: Bool,
        showSparkUsage: Bool,
        availableResetCount: Int? = nil,
        now: Date = Date()
    ) -> SessionReadinessAdvice {
        let windows = windows(from: usage, showSparkUsage: showSparkUsage)
        guard !windows.isEmpty else {
            return makeAdvice(
                level: .unavailable,
                headlineKey: "sessionReadiness.unavailable.headline",
                detailKey: "sessionReadiness.unavailable.detail",
                systemName: "exclamationmark.triangle.fill"
            )
        }

        let activeKinds = Set(windows.map(\.kind))
        let relevantForecasts = forecasts.filter { activeKinds.contains($0.kind) }
        let lowestWindow = windows.min { lhs, rhs in
            if lhs.remainingPercent != rhs.remainingPercent {
                return lhs.remainingPercent < rhs.remainingPercent
            }
            return lhs.kind.rawValue < rhs.kind.rawValue
        }

        let hasResetBank = (availableResetCount ?? 0) > 0

        if let exhaustingForecast = relevantForecasts.first(where: { isExhaustionInsideSession($0, now: now) }) {
            if hasResetBank {
                return makeAdvice(
                    level: .watch,
                    headlineKey: "sessionReadiness.watch.headline",
                    detail: L10n.text("sessionReadiness.watch.detail", exhaustingForecast.kind.title),
                    systemName: "chart.line.uptrend.xyaxis.circle.fill"
                )
            }

            return makeAdvice(
                level: .save,
                headlineKey: "sessionReadiness.save.headline",
                detail: L10n.text("sessionReadiness.save.detail", exhaustingForecast.kind.title),
                systemName: "bolt.trianglebadge.exclamationmark.fill"
            )
        }

        if let lowestWindow, lowestWindow.remainingPercent <= 10 {
            if hasResetBank {
                return makeAdvice(
                    level: .watch,
                    headlineKey: "sessionReadiness.watch.headline",
                    detail: L10n.text("sessionReadiness.watch.detail", lowestWindow.kind.title),
                    systemName: "chart.line.uptrend.xyaxis.circle.fill"
                )
            }

            return makeAdvice(
                level: .save,
                headlineKey: "sessionReadiness.save.headline",
                detail: L10n.text("sessionReadiness.save.detail", lowestWindow.kind.title),
                systemName: "bolt.trianglebadge.exclamationmark.fill"
            )
        }

        guard hasRunwayHistory, !relevantForecasts.isEmpty else {
            return makeAdvice(
                level: .learning,
                headlineKey: "sessionReadiness.learning.headline",
                detailKey: "sessionReadiness.learning.detail",
                systemName: "brain.head.profile"
            )
        }

        let meaningfulForecasts = relevantForecasts.filter { !$0.isLimitedData }
        guard !meaningfulForecasts.isEmpty else {
            return makeAdvice(
                level: .learning,
                headlineKey: "sessionReadiness.learning.headline",
                detailKey: "sessionReadiness.learning.detail",
                systemName: "brain.head.profile"
            )
        }

        if let projectedSoon = meaningfulForecasts.first(where: { isExhaustionInsideWatchWindow($0, now: now) }) {
            return makeAdvice(
                level: .watch,
                headlineKey: "sessionReadiness.watch.headline",
                detail: L10n.text("sessionReadiness.watch.detail", projectedSoon.kind.title),
                systemName: "chart.line.uptrend.xyaxis.circle.fill"
            )
        }

        if let lowEstimate = meaningfulForecasts.first(where: forecastLooksTight) {
            return makeAdvice(
                level: .watch,
                headlineKey: "sessionReadiness.watch.headline",
                detail: L10n.text("sessionReadiness.watch.detail", lowEstimate.kind.title),
                systemName: "chart.line.uptrend.xyaxis.circle.fill"
            )
        }

        if let lowestWindow, lowestWindow.remainingPercent <= 35 {
            return makeAdvice(
                level: .watch,
                headlineKey: "sessionReadiness.watch.headline",
                detail: L10n.text("sessionReadiness.watch.detail", lowestWindow.kind.title),
                systemName: "chart.line.uptrend.xyaxis.circle.fill"
            )
        }

        if let variableForecast = meaningfulForecasts.first(where: forecastLooksVariableAndRelevant) {
            return makeAdvice(
                level: .watch,
                headlineKey: "sessionReadiness.watch.headline",
                detail: L10n.text("sessionReadiness.watch.detail", variableForecast.kind.title),
                systemName: "chart.line.uptrend.xyaxis.circle.fill"
            )
        }

        return makeAdvice(
            level: .ready,
            headlineKey: "sessionReadiness.ready.headline",
            detailKey: "sessionReadiness.ready.detail",
            systemName: "checkmark.shield.fill"
        )
    }

    private func forecastLooksTight(_ forecast: UsageWindowForecast) -> Bool {
        guard forecast.remainingPercent <= 70 else {
            return false
        }

        if let range = forecast.estimatedRemainingRangeAtReset, range.lowerBound < 25 {
            return true
        }

        if let estimate = forecast.estimatedRemainingAtReset, estimate < 30 {
            return true
        }

        return false
    }

    private func forecastLooksVariableAndRelevant(_ forecast: UsageWindowForecast) -> Bool {
        forecast.confidence == .variable && forecast.remainingPercent <= 70
    }

    private func isExhaustionInsideSession(_ forecast: UsageWindowForecast, now: Date) -> Bool {
        isProjectedExhaustion(forecast, within: redProjectedRunwaySeconds, now: now)
    }

    private func isExhaustionInsideWatchWindow(_ forecast: UsageWindowForecast, now: Date) -> Bool {
        isProjectedExhaustion(forecast, within: yellowProjectedRunwaySeconds, now: now)
    }

    private func isProjectedExhaustion(_ forecast: UsageWindowForecast, within seconds: TimeInterval, now: Date) -> Bool {
        guard forecast.willExhaustBeforeReset,
              let projectedExhaustionDate = forecast.projectedExhaustionDate
        else {
            return false
        }

        return projectedExhaustionDate <= now.addingTimeInterval(seconds)
    }

    private func makeAdvice(
        level: SessionReadinessLevel,
        headlineKey: String,
        detailKey: String,
        systemName: String
    ) -> SessionReadinessAdvice {
        makeAdvice(
            level: level,
            headlineKey: headlineKey,
            detail: L10n.text(detailKey),
            systemName: systemName
        )
    }

    private func makeAdvice(
        level: SessionReadinessLevel,
        headlineKey: String,
        detail: String,
        systemName: String
    ) -> SessionReadinessAdvice {
        SessionReadinessAdvice(
            level: level,
            title: L10n.text("sessionReadiness.title"),
            headline: L10n.text(headlineKey),
            detail: detail,
            systemName: systemName
        )
    }

    private func windows(from usage: UsageResponse?, showSparkUsage: Bool) -> [ReadinessWindow] {
        guard let usage else {
            return []
        }

        var windows: [ReadinessWindow] = []

        if let primaryWindow = usage.rateLimit?.primaryWindow {
            windows.append(ReadinessWindow(kind: .codexPrimary, remainingPercent: primaryWindow.remainingPercent))
        }

        if let secondaryWindow = usage.rateLimit?.secondaryWindow {
            windows.append(ReadinessWindow(kind: .codexWeekly, remainingPercent: secondaryWindow.remainingPercent))
        }

        guard showSparkUsage else {
            return windows
        }

        let sparkLimits = usage.additionalRateLimits.filter {
            $0.meteredFeature == "codex_bengalfox" || $0.displayName == "Codex-Spark"
        }

        for spark in sparkLimits {
            if let primaryWindow = spark.rateLimit.primaryWindow {
                windows.append(ReadinessWindow(kind: .sparkPrimary, remainingPercent: primaryWindow.remainingPercent))
            }

            if let secondaryWindow = spark.rateLimit.secondaryWindow {
                windows.append(ReadinessWindow(kind: .sparkWeekly, remainingPercent: secondaryWindow.remainingPercent))
            }
        }

        return windows
    }
}

private struct ReadinessWindow: Equatable {
    let kind: UsageWindowKind
    let remainingPercent: Int
}
