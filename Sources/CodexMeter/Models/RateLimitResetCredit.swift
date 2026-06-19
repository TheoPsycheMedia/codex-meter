import Foundation

struct RateLimitResetResponse: Decodable, Equatable, Sendable {
    let availableCount: Int
    let credits: [RateLimitResetCredit]

    enum CodingKeys: String, CodingKey {
        case availableCount = "available_count"
        case credits
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        credits = try container.decodeIfPresent([RateLimitResetCredit].self, forKey: .credits) ?? []
        availableCount = try container.decodeIfPresent(Int.self, forKey: .availableCount)
            ?? credits.filter(\.isAvailable).count
    }
}

struct RateLimitResetCredit: Decodable, Equatable, Identifiable, Sendable {
    let id: String
    let resetType: String
    let status: String
    let grantedAt: Date
    let expiresAt: Date
    let redeemedAt: Date?

    var isAvailable: Bool {
        status == "available" && redeemedAt == nil
    }

    var statusTitle: String {
        if isAvailable {
            return "Available"
        }

        return status
            .split(separator: "_")
            .map { $0.prefix(1).uppercased() + $0.dropFirst() }
            .joined(separator: " ")
    }

    enum CodingKeys: String, CodingKey {
        case id
        case resetType = "reset_type"
        case status
        case grantedAt = "granted_at"
        case expiresAt = "expires_at"
        case redeemedAt = "redeemed_at"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        resetType = try container.decodeIfPresent(String.self, forKey: .resetType) ?? "rate_limit_reset"
        status = try container.decodeIfPresent(String.self, forKey: .status) ?? "unknown"
        grantedAt = try container.decode(Date.self, forKey: .grantedAt)
        expiresAt = try container.decode(Date.self, forKey: .expiresAt)
        redeemedAt = try container.decodeIfPresent(Date.self, forKey: .redeemedAt)
    }
}

enum CreditDateDecoder {
    static func decode(_ decoder: Decoder) throws -> Date {
        let container = try decoder.singleValueContainer()
        let value = try container.decode(String.self)

        let fractionalFormatter = ISO8601DateFormatter()
        fractionalFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        if let date = fractionalFormatter.date(from: value) {
            return date
        }

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]

        if let date = formatter.date(from: value) {
            return date
        }

        throw DecodingError.dataCorruptedError(
            in: container,
            debugDescription: "Invalid ISO8601 date: \(value)"
        )
    }
}
