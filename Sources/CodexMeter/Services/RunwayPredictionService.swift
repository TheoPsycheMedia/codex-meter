import Foundation

final class RunwayPredictionService {
    func predictions(
        from observations: [UsageWindowObservation],
        now: Date = Date()
    ) -> [UsageWindowForecast] {
        let grouped = Dictionary(grouping: observations) { $0.kind }

        return UsageWindowKind.allCases.compactMap { kind in
            guard let byKind = grouped[kind] else {
                return nil
            }
            return predict(for: byKind, now: now)
        }
    }

    func predict(for observations: [UsageWindowObservation], now: Date) -> UsageWindowForecast {
        let sorted = observations
            .filter { 0...100 ~= $0.remainingPercent }
            .sorted { $0.sampledAt < $1.sampledAt }

        guard let latest = sorted.last else {
            return .limited(kind: .codexPrimary)
        }

        guard sorted.count >= 2 else {
            return .limited(kind: latest.kind)
        }

        let rates = consumptionRates(for: sorted)
        guard rates.count >= 2 else {
            return UsageWindowForecast(
                id: latest.kind,
                kind: latest.kind,
                remainingPercent: latest.remainingPercent,
                confidence: .limitedData,
                isLimitedData: true,
                estimatedRemainingAtReset: nil,
                estimatedRemainingRangeAtReset: nil,
                projectedExhaustionDate: nil,
                resetAt: latest.resetAt,
                paceSummary: paceSummary(from: rates, now: now)
            )
        }

        let confidence = confidence(from: rates, at: now)
        let secondsToReset = secondsToReset(for: latest, now: now)
        // Always derive the displayed reset from the sanitized seconds-to-reset so
        // a stale/past `resetAt` from the backend can never produce a forecast (or
        // "run out before reset" comparison) anchored to a moment in the past.
        let forecastResetAt = now.addingTimeInterval(secondsToReset)
        let paceEstimate = blendedPaceEstimate(from: rates, confidence: confidence, now: now)
        let estimate = estimateRange(
            remainingPercent: latest.remainingPercent,
            paceEstimate: paceEstimate,
            secondsToReset: secondsToReset,
            confidence: confidence
        )

        return UsageWindowForecast(
            id: latest.kind,
            kind: latest.kind,
            remainingPercent: latest.remainingPercent,
            confidence: confidence,
            isLimitedData: false,
            estimatedRemainingAtReset: estimate.estimatedRemaining,
            estimatedRemainingRangeAtReset: estimate.range,
            projectedExhaustionDate: estimateExhaustion(
                remaining: latest.remainingPercent,
                rate: paceEstimate.exhaustionRate,
                now: now
            ),
            resetAt: forecastResetAt,
            paceSummary: paceSummary(from: rates, now: now)
        )
    }

    private func consumptionRates(for observations: [UsageWindowObservation]) -> [WindowRate] {
        guard observations.count >= 2 else { return [] }

        var rates: [WindowRate] = []
        var segment = 0
        var previous = observations[0]

        for current in observations.dropFirst() {
            let deltaSeconds = current.sampledAt.timeIntervalSince(previous.sampledAt)
            guard deltaSeconds > 30 else {
                continue
            }

            let deltaUsed = current.usedPercent - previous.usedPercent
            if isResetEvent(previous: previous, current: current, deltaUsed: deltaUsed) {
                previous = current
                segment += 1
                continue
            }

            let hours = max(1.0 / 3_600.0, deltaSeconds / 3_600)
            let rate = max(0, Double(deltaUsed) / hours)
            if rate.isFinite {
                rates.append(WindowRate(sampleDate: current.sampledAt, ratePerHour: rate, segment: segment))
            }
            previous = current
        }

        return rates
    }

    private func confidence(from rates: [WindowRate], at now: Date) -> RunwayConfidence {
        guard rates.count >= 4 else {
            return .limitedData
        }

        let recent = rates.filter { now.timeIntervalSince($0.sampleDate) <= 86_400 }
        guard recent.count >= 3 else {
            return .limitedData
        }

        guard currentWindowRates(from: rates).count >= 2 else {
            return .limitedData
        }

        if let latestSample = rates.last?.sampleDate, now.timeIntervalSince(latestSample) > 21_600 {
            return .limitedData
        }

        let ratesByHour = recent.map(\.ratePerHour).filter { $0 >= 0 }
        guard !ratesByHour.isEmpty else {
            return .limitedData
        }

        let mean = ratesByHour.reduce(0, +) / Double(ratesByHour.count)
        let variance = ratesByHour.reduce(0) { acc, rate in
            let delta = rate - mean
            return acc + (delta * delta)
        } / Double(ratesByHour.count)

        let coefficientOfVariation = variance == 0 ? 0 : (sqrt(variance) / max(0.0001, mean))
        let recentThreeHourRate = averageRate(
            from: rates.filter { now.timeIntervalSince($0.sampleDate) <= 10_800 }
        )
        let dayRate = averageRate(from: recent)

        let acceleration = zipRateChange(numerator: recentThreeHourRate, denominator: dayRate)
        return coefficientOfVariation <= 0.30 && acceleration <= 0.65 ? .stable : .variable
    }

    private func paceSummary(from rates: [WindowRate], now: Date) -> RunwayPaceSummary {
        let lastHour = summaryRate(rates.filter { now.timeIntervalSince($0.sampleDate) <= 3_600 })
        let lastDay = summaryRate(rates.filter { now.timeIntervalSince($0.sampleDate) <= 86_400 })
        let currentWindow = summaryRate(currentWindowRates(from: rates))

        return RunwayPaceSummary(
            lastHour: lastHour,
            lastDay: lastDay,
            currentWindow: currentWindow
        )
    }

    private func currentWindowRates(from rates: [WindowRate]) -> [WindowRate] {
        guard let currentSegment = rates.last?.segment else {
            return []
        }

        return rates.filter { $0.segment == currentSegment }
    }

    private func secondsToReset(for observation: UsageWindowObservation, now: Date) -> TimeInterval {
        if let resetAt = observation.resetAt, resetAt > now {
            return max(60, resetAt.timeIntervalSince(now))
        }

        return Double(max(60, observation.resetAfterSeconds))
    }

    private func averageRate(from rates: [WindowRate]) -> Double? {
        guard !rates.isEmpty else { return nil }
        let values = rates.map { max(0, $0.ratePerHour) }
        return values.reduce(0, +) / Double(values.count)
    }

    private func summaryRate(_ rates: [WindowRate]) -> Double? {
        // Keep every finite, non-negative pace. A previous `0..<200 ~= Int($0)`
        // filter both trapped on non-finite Doubles and silently discarded any
        // window burning >=200%/hr — i.e. exactly the runaway-consumption case
        // this forecast exists to warn about.
        let values = rates.map(\.ratePerHour).filter { $0.isFinite && $0 >= 0 }
        guard !values.isEmpty else {
            return nil
        }

        return values.reduce(0, +) / Double(values.count)
    }

    private func blendedPaceEstimate(
        from rates: [WindowRate],
        confidence: RunwayConfidence,
        now: Date
    ) -> PaceEstimate {
        let recentRates = rates.filter { now.timeIntervalSince($0.sampleDate) <= 10_800 }
        let dayRates = rates.filter { now.timeIntervalSince($0.sampleDate) <= 86_400 }
        let currentRates = currentWindowRates(from: rates)

        let components = [
            weightedComponent(from: recentRates, weight: 0.45),
            weightedComponent(from: currentRates, weight: 0.30),
            weightedComponent(from: dayRates, weight: 0.20),
            weightedComponent(from: rates, weight: 0.05)
        ].compactMap { $0 }

        let expectedRate = weightedRate(from: components)
            ?? averageRate(from: rates)
            ?? 0

        let sortedRates = rates.map { max(0, $0.ratePerHour) }.sorted()
        let lowerPercentileRate = percentile(sortedRates, at: 0.25) ?? expectedRate
        let upperPercentileRate = percentile(sortedRates, at: 0.75) ?? expectedRate

        let optimisticRate = min(lowerPercentileRate, expectedRate)
        let cautiousRate = max(upperPercentileRate, expectedRate)
        let exhaustionRate = confidence == .stable ? expectedRate : cautiousRate

        return PaceEstimate(
            expectedRate: expectedRate,
            optimisticRate: optimisticRate,
            cautiousRate: cautiousRate,
            exhaustionRate: exhaustionRate
        )
    }

    private func estimateRange(
        remainingPercent: Int,
        paceEstimate: PaceEstimate,
        secondsToReset: TimeInterval,
        confidence: RunwayConfidence
    ) -> (estimatedRemaining: Double?, range: ClosedRange<Double>?) {
        guard secondsToReset > 0 else {
            return (Double(remainingPercent), nil)
        }

        let hoursToReset = secondsToReset / 3_600
        let expectedRemaining = clampedRemaining(
            Double(remainingPercent) - paceEstimate.expectedRate * hoursToReset
        )

        guard paceEstimate.expectedRate > 0 || paceEstimate.cautiousRate > 0 else {
            return (Double(remainingPercent), 0...Double(remainingPercent))
        }

        if confidence == .stable {
            return (expectedRemaining, expectedRemaining...expectedRemaining)
        }

        let lowerRemaining = clampedRemaining(
            Double(remainingPercent) - paceEstimate.cautiousRate * hoursToReset
        )
        let upperRemaining = clampedRemaining(
            Double(remainingPercent) - paceEstimate.optimisticRate * hoursToReset
        )

        let low = min(lowerRemaining, expectedRemaining, upperRemaining)
        let high = max(lowerRemaining, expectedRemaining, upperRemaining)
        if abs(high - low) < 1 {
            return (expectedRemaining, expectedRemaining...expectedRemaining)
        }

        return (expectedRemaining, low...high)
    }

    private func weightedComponent(from rates: [WindowRate], weight: Double) -> RateComponent? {
        guard let rate = averageRate(from: rates) else {
            return nil
        }

        return RateComponent(rate: rate, weight: weight)
    }

    private func weightedRate(from components: [RateComponent]) -> Double? {
        let totalWeight = components.map(\.weight).reduce(0, +)
        guard totalWeight > 0 else {
            return nil
        }

        return components.reduce(0) { partial, component in
            partial + (component.rate * component.weight)
        } / totalWeight
    }

    private func percentile(_ sortedValues: [Double], at percentile: Double) -> Double? {
        guard !sortedValues.isEmpty else {
            return nil
        }

        guard sortedValues.count > 1 else {
            return sortedValues[0]
        }

        let clampedPercentile = max(0, min(1, percentile))
        let position = clampedPercentile * Double(sortedValues.count - 1)
        let lowerIndex = Int(floor(position))
        let upperIndex = Int(ceil(position))

        if lowerIndex == upperIndex {
            return sortedValues[lowerIndex]
        }

        let weight = position - Double(lowerIndex)
        return sortedValues[lowerIndex] + ((sortedValues[upperIndex] - sortedValues[lowerIndex]) * weight)
    }

    private func zipRateChange(numerator: Double?, denominator: Double?) -> Double {
        guard let numerator, let denominator else {
            return 0
        }

        guard denominator > 0 else {
            return numerator > 0 ? 1 : 0
        }

        return abs(numerator - denominator) / denominator
    }

    private func clampedRemaining(_ value: Double) -> Double {
        max(0, min(100, value))
    }

    private func estimateExhaustion(remaining: Int, rate: Double, now: Date) -> Date? {
        guard rate > 0 else {
            return nil
        }

        let hoursToZero = Double(remaining) / rate
        return now.addingTimeInterval(hoursToZero * 3_600)
    }

    private func isResetEvent(
        previous: UsageWindowObservation,
        current: UsageWindowObservation,
        deltaUsed: Int
    ) -> Bool {
        if deltaUsed < -5 {
            return true
        }

        if let prevResetAt = previous.resetAt,
           let currentResetAt = current.resetAt,
           prevResetAt != currentResetAt {
            return true
        }

        return false
    }
}

private struct WindowRate {
    let sampleDate: Date
    let ratePerHour: Double
    let segment: Int
}

private struct PaceEstimate {
    let expectedRate: Double
    let optimisticRate: Double
    let cautiousRate: Double
    let exhaustionRate: Double
}

private struct RateComponent {
    let rate: Double
    let weight: Double
}
