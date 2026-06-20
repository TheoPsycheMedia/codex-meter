import Foundation

struct UsageResponse: Decodable, Equatable, Sendable {
    let planType: String?
    let rateLimit: UsageRateLimit?
    let additionalRateLimits: [AdditionalUsageRateLimit]
    let credits: UsageCredits?
    let rateLimitResetCredits: ResetCreditCount?

    enum CodingKeys: String, CodingKey {
        case planType = "plan_type"
        case rateLimit = "rate_limit"
        case additionalRateLimits = "additional_rate_limits"
        case credits
        case rateLimitResetCredits = "rate_limit_reset_credits"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        planType = try container.decodeIfPresent(String.self, forKey: .planType)
        rateLimit = try container.decodeIfPresent(UsageRateLimit.self, forKey: .rateLimit)
        additionalRateLimits = try container.decodeIfPresent([AdditionalUsageRateLimit].self, forKey: .additionalRateLimits) ?? []
        credits = try container.decodeIfPresent(UsageCredits.self, forKey: .credits)
        rateLimitResetCredits = try container.decodeIfPresent(ResetCreditCount.self, forKey: .rateLimitResetCredits)
    }
}

struct ResetCreditCount: Decodable, Equatable, Sendable {
    let availableCount: Int

    enum CodingKeys: String, CodingKey {
        case availableCount = "available_count"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        availableCount = try container.decodeIfPresent(Int.self, forKey: .availableCount) ?? 0
    }
}

struct AdditionalUsageRateLimit: Decodable, Equatable, Identifiable, Sendable {
    let meteredFeature: String
    let rateLimit: UsageRateLimit

    var id: String {
        meteredFeature
    }

    var displayName: String {
        if meteredFeature == "codex_bengalfox" {
            return "Codex-Spark"
        }

        return meteredFeature
            .replacingOccurrences(of: "codex_", with: "")
            .split(separator: "_")
            .map { $0.prefix(1).uppercased() + $0.dropFirst() }
            .joined(separator: " ")
    }

    enum CodingKeys: String, CodingKey {
        case meteredFeature = "metered_feature"
        case rateLimit = "rate_limit"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        meteredFeature = try container.decodeIfPresent(String.self, forKey: .meteredFeature) ?? "unknown_meter"
        rateLimit = try container.decodeIfPresent(UsageRateLimit.self, forKey: .rateLimit) ?? UsageRateLimit()
    }
}

struct UsageRateLimit: Decodable, Equatable, Sendable {
    let allowed: Bool
    let limitReached: Bool
    let primaryWindow: UsageWindow?
    let secondaryWindow: UsageWindow?

    enum CodingKeys: String, CodingKey {
        case allowed
        case limitReached = "limit_reached"
        case primaryWindow = "primary_window"
        case secondaryWindow = "secondary_window"
    }

    init(
        allowed: Bool = true,
        limitReached: Bool = false,
        primaryWindow: UsageWindow? = nil,
        secondaryWindow: UsageWindow? = nil
    ) {
        self.allowed = allowed
        self.limitReached = limitReached
        self.primaryWindow = primaryWindow
        self.secondaryWindow = secondaryWindow
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        allowed = try container.decodeIfPresent(Bool.self, forKey: .allowed) ?? true
        limitReached = try container.decodeIfPresent(Bool.self, forKey: .limitReached) ?? false
        primaryWindow = try container.decodeIfPresent(UsageWindow.self, forKey: .primaryWindow)
        secondaryWindow = try container.decodeIfPresent(UsageWindow.self, forKey: .secondaryWindow)
    }
}

struct UsageWindow: Decodable, Equatable, Sendable {
    let usedPercent: Int
    let limitWindowSeconds: Int
    let resetAfterSeconds: Int
    let resetAt: Date?

    var remainingPercent: Int {
        max(0, min(100, 100 - usedPercent))
    }

    var durationTitle: String {
        if limitWindowSeconds >= 604_800 {
            return "Weekly"
        }

        if limitWindowSeconds >= 86_400 {
            let days = limitWindowSeconds / 86_400
            return "\(days)d"
        }

        let hours = max(1, limitWindowSeconds / 3_600)
        return "\(hours)h"
    }

    enum CodingKeys: String, CodingKey {
        case usedPercent = "used_percent"
        case limitWindowSeconds = "limit_window_seconds"
        case resetAfterSeconds = "reset_after_seconds"
        case resetAt = "reset_at"
    }

    init(usedPercent: Int, limitWindowSeconds: Int, resetAfterSeconds: Int, resetAt: Date?) {
        self.usedPercent = usedPercent
        self.limitWindowSeconds = limitWindowSeconds
        self.resetAfterSeconds = resetAfterSeconds
        self.resetAt = resetAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        usedPercent = try container.decodeIfPresent(Int.self, forKey: .usedPercent) ?? 0
        limitWindowSeconds = try container.decodeIfPresent(Int.self, forKey: .limitWindowSeconds) ?? 0
        resetAfterSeconds = try container.decodeIfPresent(Int.self, forKey: .resetAfterSeconds) ?? 0

        if let timestamp = try? container.decodeIfPresent(Double.self, forKey: .resetAt) {
            resetAt = Date(timeIntervalSince1970: timestamp)
        } else if let timestamp = try? container.decodeIfPresent(String.self, forKey: .resetAt) {
            resetAt = Self.isoDate(from: timestamp)
        } else {
            resetAt = nil
        }
    }

    private static func isoDate(from value: String) -> Date? {
        let fractionalFormatter = ISO8601DateFormatter()
        fractionalFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        if let date = fractionalFormatter.date(from: value) {
            return date
        }

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: value)
    }
}

struct UsageCredits: Decodable, Equatable, Sendable {
    let hasCredits: Bool
    let unlimited: Bool
    let overageLimitReached: Bool
    let balance: String?

    enum CodingKeys: String, CodingKey {
        case hasCredits = "has_credits"
        case unlimited
        case overageLimitReached = "overage_limit_reached"
        case balance
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        hasCredits = try container.decodeIfPresent(Bool.self, forKey: .hasCredits) ?? false
        unlimited = try container.decodeIfPresent(Bool.self, forKey: .unlimited) ?? false
        overageLimitReached = try container.decodeIfPresent(Bool.self, forKey: .overageLimitReached) ?? false
        balance = try container.decodeIfPresent(String.self, forKey: .balance)
    }
}
