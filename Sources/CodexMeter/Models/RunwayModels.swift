import Foundation

enum UsageWindowKind: String, Codable, CaseIterable, Identifiable {
    case codexPrimary = "codex-primary"
    case codexWeekly = "codex-weekly"
    case sparkPrimary = "spark-primary"
    case sparkWeekly = "spark-weekly"

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .codexPrimary:
            return "Codex 5h"
        case .codexWeekly:
            return "Codex weekly"
        case .sparkPrimary:
            return "Spark 5h"
        case .sparkWeekly:
            return "Spark weekly"
        }
    }

    var resetLabel: String {
        switch self {
        case .codexPrimary, .sparkPrimary:
            return "5h reset"
        case .codexWeekly, .sparkWeekly:
            return "weekly reset"
        }
    }
}

struct UsageWindowObservation: Codable, Equatable {
    let sampledAt: Date
    let kind: UsageWindowKind
    let remainingPercent: Int
    let usedPercent: Int
    let limitWindowSeconds: Int
    let resetAfterSeconds: Int
    let resetAt: Date?

    init(
        sampledAt: Date,
        kind: UsageWindowKind,
        remainingPercent: Int,
        usedPercent: Int,
        limitWindowSeconds: Int,
        resetAfterSeconds: Int,
        resetAt: Date?
    ) {
        self.sampledAt = sampledAt
        self.kind = kind
        self.remainingPercent = max(0, min(100, remainingPercent))
        self.usedPercent = max(0, min(100, usedPercent))
        self.limitWindowSeconds = max(60, limitWindowSeconds)
        self.resetAfterSeconds = max(60, resetAfterSeconds)
        self.resetAt = resetAt
    }

    init(sampledAt: Date, kind: UsageWindowKind, window: UsageWindow) {
        self.init(
            sampledAt: sampledAt,
            kind: kind,
            remainingPercent: window.remainingPercent,
            usedPercent: window.usedPercent,
            limitWindowSeconds: window.limitWindowSeconds,
            resetAfterSeconds: window.resetAfterSeconds,
            resetAt: window.resetAt
        )
    }
}

struct UsageObservation: Codable, Equatable {
    let id: String
    let sampledAt: Date
    let planType: String?
    let availableResetCredits: Int
    let windows: [UsageWindowObservation]
    let upcomingCreditExpiries: [Date]

    init(
        sampledAt: Date,
        planType: String?,
        availableResetCredits: Int,
        windows: [UsageWindowObservation],
        upcomingCreditExpiries: [Date]
    ) {
        self.id = UUID().uuidString
        self.sampledAt = sampledAt
        self.planType = planType
        self.availableResetCredits = availableResetCredits
        self.windows = windows
        self.upcomingCreditExpiries = upcomingCreditExpiries
    }
}

struct SmartAlertLedger: Codable {
    var thresholdStateByWindow: [String: Int] = [:]
    var exhaustionStateByWindow: [String: Bool] = [:]
    var creditExpirySentByCredit: [String: Date] = [:]
    var resetAvailableSentByWindow: [String: Bool] = [:]
    var lastAvailableResetCreditCount: Int?
}

struct UsageHistoryPayload: Codable {
    var schemaVersion: Int = 1
    var observations: [UsageObservation] = []
    var alertLedger: SmartAlertLedger = .init()
}

enum RunwayConfidence: String, Codable {
    case stable = "Stable"
    case variable = "Variable"
    case limitedData = "Limited data"
}

struct RunwayPaceSummary: Equatable {
    let lastHour: Double?
    let lastDay: Double?
    let currentWindow: Double?
}

struct UsageWindowForecast: Identifiable, Equatable {
    let id: UsageWindowKind
    let kind: UsageWindowKind
    let remainingPercent: Int
    let confidence: RunwayConfidence
    let isLimitedData: Bool
    let estimatedRemainingAtReset: Double?
    let estimatedRemainingRangeAtReset: ClosedRange<Double>?
    let projectedExhaustionDate: Date?
    let resetAt: Date?
    let paceSummary: RunwayPaceSummary

    var willExhaustBeforeReset: Bool {
        guard let resetAt, let projectedExhaustionDate else {
            return false
        }

        return projectedExhaustionDate < resetAt
    }

    static func limited(kind: UsageWindowKind) -> UsageWindowForecast {
        UsageWindowForecast(
            id: kind,
            kind: kind,
            remainingPercent: 0,
            confidence: .limitedData,
            isLimitedData: true,
            estimatedRemainingAtReset: nil,
            estimatedRemainingRangeAtReset: nil,
            projectedExhaustionDate: nil,
            resetAt: nil,
            paceSummary: .init(lastHour: nil, lastDay: nil, currentWindow: nil)
        )
    }
}
