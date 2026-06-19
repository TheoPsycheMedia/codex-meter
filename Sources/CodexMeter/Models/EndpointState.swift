import Foundation

enum WidgetEndpoint: String, CaseIterable, Sendable {
    case usage
    case resetCredits

    var title: String {
        switch self {
        case .usage:
            return "Usage"
        case .resetCredits:
            return "Reset Bank"
        }
    }

    var diagnosticName: String {
        switch self {
        case .usage:
            return "usage"
        case .resetCredits:
            return "reset_credits"
        }
    }

    var path: String {
        switch self {
        case .usage:
            return "/backend-api/wham/usage"
        case .resetCredits:
            return "/backend-api/wham/rate-limit-reset-credits"
        }
    }
}

enum EndpointFailureCategory: String, Sendable {
    case missingAuth
    case expiredSession
    case httpFailure
    case networkFailure
    case invalidResponse
    case malformedPayload
    case schemaMismatch
    case unknown
}

struct EndpointFailure: Error, Equatable, Sendable {
    let endpoint: WidgetEndpoint
    let category: EndpointFailureCategory
    let statusCode: Int?
    let decoderPath: String?
    let recognizedKeys: [String]
    let message: String
    let recoverySuggestion: String?

    init(
        endpoint: WidgetEndpoint,
        category: EndpointFailureCategory,
        statusCode: Int? = nil,
        decoderPath: String? = nil,
        recognizedKeys: [String] = [],
        message: String,
        recoverySuggestion: String? = nil
    ) {
        self.endpoint = endpoint
        self.category = category
        self.statusCode = statusCode
        self.decoderPath = decoderPath
        self.recognizedKeys = recognizedKeys
        self.message = message
        self.recoverySuggestion = recoverySuggestion
    }

    var statusTitle: String {
        switch category {
        case .missingAuth:
            return "Codex sign-in not found"
        case .expiredSession:
            return "Session expired"
        case .schemaMismatch, .malformedPayload:
            return "Data format changed"
        case .httpFailure:
            return "\(endpoint.title) failed"
        case .networkFailure:
            return "\(endpoint.title) unavailable"
        case .invalidResponse, .unknown:
            return "\(endpoint.title) needs attention"
        }
    }

    var detailText: String {
        switch category {
        case .missingAuth:
            return "Sign in to Codex on this Mac, then refresh."
        case .expiredSession:
            return "Sign in to Codex again, then refresh."
        case .schemaMismatch, .malformedPayload:
            return "Current \(endpointDiagnosticLabel) response could not be interpreted."
        case .httpFailure:
            return "Current \(endpointDiagnosticLabel) response could not be loaded."
        case .networkFailure:
            return "Current \(endpointDiagnosticLabel) response could not be reached."
        case .invalidResponse:
            return "Current \(endpointDiagnosticLabel) response was not valid HTTP."
        case .unknown:
            return message
        }
    }

    private var endpointDiagnosticLabel: String {
        switch endpoint {
        case .usage:
            return "usage"
        case .resetCredits:
            return "reset-credit"
        }
    }
}

enum EndpointRefreshPhase: String, Sendable {
    case idle
    case refreshing
    case live
    case stale
    case unavailable
}

enum EndpointStatusTone: Sendable {
    case neutral
    case progress
    case live
    case warning
    case error
}

struct EndpointRefreshState: Equatable, Sendable {
    let endpoint: WidgetEndpoint
    var phase: EndpointRefreshPhase
    var lastSuccessAt: Date?
    var failure: EndpointFailure?
    var refreshStartedAt: Date?
    var hasPriorData: Bool

    static func idle(_ endpoint: WidgetEndpoint) -> EndpointRefreshState {
        EndpointRefreshState(
            endpoint: endpoint,
            phase: .idle,
            lastSuccessAt: nil,
            failure: nil,
            refreshStartedAt: nil,
            hasPriorData: false
        )
    }

    mutating func beginRefresh(at date: Date, hasPriorData: Bool) {
        phase = .refreshing
        refreshStartedAt = date
        self.hasPriorData = hasPriorData
    }

    mutating func recordSuccess(at date: Date, hasPriorData: Bool = true) {
        phase = .live
        lastSuccessAt = date
        failure = nil
        refreshStartedAt = nil
        self.hasPriorData = hasPriorData
    }

    mutating func recordFailure(_ failure: EndpointFailure, hasPriorData: Bool) {
        phase = hasPriorData ? .stale : .unavailable
        self.failure = failure
        refreshStartedAt = nil
        self.hasPriorData = hasPriorData
    }

    var isRefreshing: Bool {
        phase == .refreshing
    }

    var isLive: Bool {
        phase == .live
    }

    var isStale: Bool {
        phase == .stale
    }

    var isUnavailable: Bool {
        phase == .unavailable
    }

    var tone: EndpointStatusTone {
        switch phase {
        case .idle:
            return .neutral
        case .refreshing:
            return .progress
        case .live:
            return .live
        case .stale:
            return .warning
        case .unavailable:
            return failure?.category == .missingAuth ? .warning : .error
        }
    }

    var systemName: String {
        switch phase {
        case .idle:
            return "clock"
        case .refreshing:
            return "arrow.triangle.2.circlepath"
        case .live:
            return "checkmark.circle.fill"
        case .stale:
            return "clock.badge.exclamationmark"
        case .unavailable:
            return failure?.category == .missingAuth ? "person.crop.circle.badge.exclamationmark" : "exclamationmark.triangle.fill"
        }
    }

    var title: String {
        switch phase {
        case .idle:
            return "Not updated"
        case .refreshing:
            return hasPriorData ? "Refreshing" : "Loading"
        case .live:
            return "Live"
        case .stale:
            if failure?.category == .expiredSession {
                return "Session expired"
            }

            if failure?.category == .schemaMismatch || failure?.category == .malformedPayload {
                return "Schema changed"
            }

            switch endpoint {
            case .usage:
                return "Usage stale"
            case .resetCredits:
                return "Reset Bank stale"
            }
        case .unavailable:
            return failure?.statusTitle ?? "\(endpoint.title) unavailable"
        }
    }

    func timestampText(now: Date, timeFormatter: DateFormatter, relativeFormatter: RelativeDateTimeFormatter) -> String {
        if isRefreshing, !hasPriorData {
            return "Loading latest data"
        }

        guard let lastSuccessAt else {
            return "Not updated yet"
        }

        if phase == .live {
            return "Updated \(timeFormatter.string(from: lastSuccessAt))"
        }

        let relative = relativeAge(from: lastSuccessAt, now: now, formatter: relativeFormatter)
        return "Data from \(relative)"
    }

    func relativeDataAge(now: Date, formatter: RelativeDateTimeFormatter) -> String? {
        guard let lastSuccessAt else {
            return nil
        }

        return "Data from \(relativeAge(from: lastSuccessAt, now: now, formatter: formatter))"
    }

    private func relativeAge(from date: Date, now: Date, formatter: RelativeDateTimeFormatter) -> String {
        if date > now {
            return "just now"
        }

        return formatter.localizedString(for: date, relativeTo: now)
    }
}

struct WidgetSnapshot: Equatable, Sendable {
    var usage: UsageResponse?
    var availableCount: Int?
    var credits: [RateLimitResetCredit]
    var capturedAt: Date?

    static let empty = WidgetSnapshot(
        usage: nil,
        availableCount: nil,
        credits: [],
        capturedAt: nil
    )
}
