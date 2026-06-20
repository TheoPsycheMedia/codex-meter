import Foundation

enum StatusItemDisplayMode: String, CaseIterable, Identifiable {
    case percentageOnly
    case percentageWithResetTime
    case primaryAndWeekly
    case lowestWindowOnly
    case iconOnly

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .percentageOnly:
            return "Percent only"
        case .percentageWithResetTime:
            return "Percent + reset time"
        case .primaryAndWeekly:
            return "Primary and weekly"
        case .lowestWindowOnly:
            return "Lowest overall"
        case .iconOnly:
            return "Icon Only"
        }
    }

    var isIconOnly: Bool {
        self == .iconOnly
    }
}

struct StatusItemUsageWindow: Identifiable, Equatable {
    let id: String
    let source: String
    let shortLabel: String
    let menuBarLabel: String
    let menuLabelPrefix: String
    let percent: Int
    let resetAt: Date?
    let resetAfterSeconds: Int
    let isSpark: Bool
    let sortPriority: Int

    var remainingText: String {
        StatusItemFormatter.remainingTimeText(resetAfterSeconds)
    }

    var shortMenuLabel: String {
        menuBarLabel
    }

    var menuLabel: String {
        return "\(menuLabelPrefix): \(percent)% · \(remainingText)"
    }
}

struct StatusItemSnapshot {
    let windows: [StatusItemUsageWindow]
    let mode: StatusItemDisplayMode
    let isLoading: Bool
    let errorMessage: String?
    let lastUpdated: Date?

    init(
        usage: UsageResponse?,
        showSparkUsage: Bool,
        mode: StatusItemDisplayMode,
        isLoading: Bool,
        errorMessage: String?,
        lastUpdated: Date?
    ) {
        self.windows = Self.makeWindows(from: usage, showSparkUsage: showSparkUsage)
        self.mode = mode
        self.isLoading = isLoading
        self.errorMessage = errorMessage
        self.lastUpdated = lastUpdated
    }

    var hasWindowData: Bool {
        !windows.isEmpty
    }

    var isStale: Bool {
        guard let lastUpdated else {
            return false
        }

        return Date().timeIntervalSince(lastUpdated) > 15
    }

    var statusText: String {
        statusText(for: mode)
    }

    func statusText(for mode: StatusItemDisplayMode) -> String {
        guard hasWindowData else {
            if mode.isIconOnly {
                return ""
            }

            if isLoading {
                return "--%"
            }

            if errorMessage != nil {
                return "ERR"
            }

            return "--%"
        }

        switch mode {
        case .percentageOnly:
            return "\(headlineCodexWindow.percent)%"
        case .percentageWithResetTime:
            return "\(headlineCodexWindow.percent)% · \(headlineCodexWindow.remainingText)"
        case .primaryAndWeekly:
            return compactPrimaryAndWeeklyText()
        case .lowestWindowOnly:
            return "\(lowestWindow.shortMenuLabel) \(lowestWindow.percent)%"
        case .iconOnly:
            return ""
        }
    }

    func previewText(for mode: StatusItemDisplayMode) -> String {
        if hasWindowData {
            let text = statusText(for: mode)
            return text.isEmpty ? "Icon only" : text
        }

        switch mode {
        case .percentageOnly:
            return "67%"
        case .percentageWithResetTime:
            return "67% · 2h 14m"
        case .primaryAndWeekly:
            return "5h 83% · Wk 71%"
        case .lowestWindowOnly:
            return "Spark 67%"
        case .iconOnly:
            return "Icon only"
        }
    }

    var tooltipText: String {
        var base = "Codex Meter"

        if hasWindowData {
            if isStale {
                base += " · data may be stale"
            }
        } else if isLoading {
            base += " · loading usage"
        } else if let errorMessage {
            base += " · \(errorMessage)"
        } else {
            base += " · no usage data"
        }

        if let lastUpdated {
            base += " · updated \(Self.timeFormatter.string(from: lastUpdated))"
        }

        return base
    }

    var menuRows: [String] {
        windows.map { $0.menuLabel }
    }

    var menuActionSummary: String {
        guard hasWindowData else {
            return "No usage data yet"
        }

        if windows.count == 1 {
            let window = windows[0]
            return "\(window.shortMenuLabel) \(window.percent)%"
        }

        if mode == .percentageOnly || mode == .percentageWithResetTime {
            return "\(headlineCodexWindow.menuLabelPrefix): \(headlineCodexWindow.percent)%"
        }

        if mode == .primaryAndWeekly {
            return compactPrimaryAndWeeklyText()
        }

        return "Lowest: \(lowestWindow.shortMenuLabel) \(lowestWindow.percent)%"
    }

    private var headlineCodexWindow: StatusItemUsageWindow {
        primaryWindow ?? weeklyWindow ?? lowestWindow
    }

    private var lowestWindow: StatusItemUsageWindow {
        windows.min { lhs, rhs in
            if lhs.percent != rhs.percent {
                return lhs.percent < rhs.percent
            }

            if lhs.resetAfterSeconds != rhs.resetAfterSeconds {
                return lhs.resetAfterSeconds < rhs.resetAfterSeconds
            }

            if let lhsResetAt = lhs.resetAt, let rhsResetAt = rhs.resetAt, lhsResetAt != rhsResetAt {
                return lhsResetAt < rhsResetAt
            }

            if lhs.sortPriority != rhs.sortPriority {
                return lhs.sortPriority < rhs.sortPriority
            }

            return lhs.id < rhs.id
        } ?? windows[0]
    }

    private var primaryWindow: StatusItemUsageWindow? {
        windows.first { $0.shortLabel == "P" && !$0.isSpark }
    }

    private var weeklyWindow: StatusItemUsageWindow? {
        windows.first { $0.shortLabel == "W" && !$0.isSpark }
    }

    private func compactPrimaryAndWeeklyText() -> String {
        let primary = primaryWindow.map { "\($0.menuBarLabel) \($0.percent)%" }
        let weekly = weeklyWindow.map { "\($0.menuBarLabel) \($0.percent)%" }

        switch (primary, weekly) {
        case let (p?, w?):
            return "\(p) · \(w)"
        case let (p?, nil):
            return p
        case let (nil, w?):
            return w
        default:
            return statusTextFallback
        }
    }

    private var statusTextFallback: String {
        "\(lowestWindow.percent)%"
    }

    private static func makeWindows(from usage: UsageResponse?, showSparkUsage: Bool) -> [StatusItemUsageWindow] {
        guard let usage else {
            return []
        }

        var windows: [StatusItemUsageWindow] = []
        var priority = 0

        if let primaryWindow = usage.rateLimit?.primaryWindow {
            windows.append(
                StatusItemUsageWindow(
                    id: "codex-primary",
                    source: "Codex",
                    shortLabel: "P",
                    menuBarLabel: primaryWindow.durationTitle,
                    menuLabelPrefix: "Codex \(primaryWindow.durationTitle)",
                    percent: primaryWindow.remainingPercent,
                    resetAt: primaryWindow.resetAt,
                    resetAfterSeconds: primaryWindow.resetAfterSeconds,
                    isSpark: false,
                    sortPriority: priority
                )
            )

            priority += 1
        }

        if let secondaryWindow = usage.rateLimit?.secondaryWindow {
            windows.append(
                StatusItemUsageWindow(
                    id: "codex-weekly",
                    source: "Codex",
                    shortLabel: "W",
                    menuBarLabel: "Wk",
                    menuLabelPrefix: "Codex weekly",
                    percent: secondaryWindow.remainingPercent,
                    resetAt: secondaryWindow.resetAt,
                    resetAfterSeconds: secondaryWindow.resetAfterSeconds,
                    isSpark: false,
                    sortPriority: priority
                )
            )

            priority += 1
        }

        guard showSparkUsage else {
            return windows
        }

        guard let sparkRateLimit = usage.additionalRateLimits
            .first(where: { $0.meteredFeature == "codex_bengalfox" || $0.displayName == "Codex-Spark" })?
            .rateLimit
        else {
            return windows
        }

        if let primaryWindow = sparkRateLimit.primaryWindow {
            windows.append(
                StatusItemUsageWindow(
                    id: "spark-primary",
                    source: "Spark",
                    shortLabel: "P",
                    menuBarLabel: "Spark",
                    menuLabelPrefix: "Spark \(primaryWindow.durationTitle)",
                    percent: primaryWindow.remainingPercent,
                    resetAt: primaryWindow.resetAt,
                    resetAfterSeconds: primaryWindow.resetAfterSeconds,
                    isSpark: true,
                    sortPriority: priority
                )
            )

            priority += 1
        }

        if let secondaryWindow = sparkRateLimit.secondaryWindow {
            windows.append(
                StatusItemUsageWindow(
                    id: "spark-weekly",
                    source: "Spark",
                    shortLabel: "W",
                    menuBarLabel: "Spark Wk",
                    menuLabelPrefix: "Spark weekly",
                    percent: secondaryWindow.remainingPercent,
                    resetAt: secondaryWindow.resetAt,
                    resetAfterSeconds: secondaryWindow.resetAfterSeconds,
                    isSpark: true,
                    sortPriority: priority
                )
            )
        }

        return windows
    }

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return formatter
    }()
}

enum StatusItemFormatter {
    static func remainingTimeText(_ seconds: Int) -> String {
        if seconds <= 0 {
            return "reset"
        }

        let hourPart = seconds / 3600
        let minutePart = (seconds % 3600) / 60

        if hourPart > 0 && minutePart > 0 {
            return "\(hourPart)h \(minutePart)m"
        }

        if hourPart > 0 {
            return "\(hourPart)h"
        }

        return "\(minutePart)m"
    }
}
