import Foundation

struct DiagnosticsInput {
    let appVersion: String
    let macOSVersion: String
    let generatedAt: Date
    let autoRefreshEnabled: Bool
    let refreshIntervalSeconds: TimeInterval
    let meterStyle: MeterStyle
    let hasUsageData: Bool
    let hasResetCreditData: Bool
    let usageState: EndpointRefreshState
    let resetCreditState: EndpointRefreshState
}

enum DiagnosticsBuilder {
    static func build(_ input: DiagnosticsInput) -> String {
        var lines: [String] = [
            "Codex Meter Diagnostics",
            "Generated: \(isoString(from: input.generatedAt))",
            "App version: \(input.appVersion)",
            "macOS: \(input.macOSVersion)",
            "Auto refresh: \(input.autoRefreshEnabled ? "enabled" : "disabled")",
            "Refresh interval: \(Int(input.refreshIntervalSeconds))s",
            "Meter style: \(input.meterStyle.rawValue)",
            "Has usage data: \(input.hasUsageData)",
            "Has reset-credit data: \(input.hasResetCreditData)"
        ]

        lines.append(contentsOf: endpointLines(for: input.usageState, now: input.generatedAt))
        lines.append(contentsOf: endpointLines(for: input.resetCreditState, now: input.generatedAt))
        lines.append("Privacy: tokens, cookies, auth files, raw endpoint bodies, account IDs, emails, and local private paths are intentionally excluded.")

        return lines.joined(separator: "\n")
    }

    private static func endpointLines(for state: EndpointRefreshState, now: Date) -> [String] {
        var lines: [String] = [
            "",
            "Endpoint: \(state.endpoint.diagnosticName)",
            "Path: \(state.endpoint.path)",
            "State: \(state.phase.rawValue)"
        ]

        if let lastSuccessAt = state.lastSuccessAt {
            lines.append("Last success: \(isoString(from: lastSuccessAt))")
            lines.append("Last success age: \(ageBucket(from: lastSuccessAt, now: now))")
        } else {
            lines.append("Last success: none")
        }

        guard let failure = state.failure else {
            return lines
        }

        lines.append("Failure category: \(failure.category.rawValue)")

        if let statusCode = failure.statusCode {
            lines.append("HTTP status: \(statusCode)")
        }

        if let decoderPath = failure.decoderPath {
            lines.append("Decoder path: \(decoderPath)")
        }

        if !failure.recognizedKeys.isEmpty {
            lines.append("Recognized keys: \(failure.recognizedKeys.joined(separator: ", "))")
        }

        return lines
    }

    private static func ageBucket(from date: Date, now: Date) -> String {
        let age = max(0, now.timeIntervalSince(date))

        switch age {
        case 0..<60:
            return "<1m"
        case 60..<1_800:
            return "\(Int(age / 60))m"
        case 1_800..<3_600:
            return "30m+"
        case 3_600..<86_400:
            return "\(Int(age / 3_600))h"
        default:
            return "\(Int(age / 86_400))d"
        }
    }

    private static func isoString(from date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.string(from: date)
    }
}
