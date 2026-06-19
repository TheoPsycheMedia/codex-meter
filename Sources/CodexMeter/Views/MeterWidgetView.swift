import SwiftUI

struct MeterWidgetView: View {
    @ObservedObject var store: WidgetStore
    let onHide: () -> Void
    let onSnap: () -> Void

    private var tint: WidgetTint {
        WidgetTint.all[store.tintIndex % WidgetTint.all.count]
    }

    private var displayedCredits: [RateLimitResetCredit] {
        Array(store.credits.prefix(2))
    }

    private var codexUsageGauges: [UsageGaugeData] {
        var gauges: [UsageGaugeData] = []

        if let primaryWindow = store.usage?.rateLimit?.primaryWindow {
            gauges.append(
                UsageGaugeData(
                    id: "codex-primary",
                    title: primaryWindow.durationTitle,
                    subtitle: "Codex",
                    percent: primaryWindow.remainingPercent,
                    resetAt: primaryWindow.resetAt
                )
            )
        }

        if let secondaryWindow = store.usage?.rateLimit?.secondaryWindow {
            gauges.append(
                UsageGaugeData(
                    id: "codex-weekly",
                    title: "Weekly",
                    subtitle: "Codex",
                    percent: secondaryWindow.remainingPercent,
                    resetAt: secondaryWindow.resetAt
                )
            )
        }

        return gauges
    }

    private var sparkUsageGauges: [UsageGaugeData] {
        guard store.showSparkUsage else {
            return []
        }

        var gauges: [UsageGaugeData] = []
        let sparkRateLimit = store.usage?.additionalRateLimits
            .first { $0.displayName == "Codex-Spark" || $0.meteredFeature == "codex_bengalfox" }?
            .rateLimit

        let sparkLimit = sparkRateLimit?.primaryWindow
            ?? UsageWindow(
                usedPercent: 0,
                limitWindowSeconds: 18_000,
                resetAfterSeconds: 18_000,
                resetAt: nil
            )

        gauges.append(
            UsageGaugeData(
                id: "codex-spark",
                title: "Spark",
                subtitle: "5h limit",
                percent: sparkLimit.remainingPercent,
                resetAt: sparkLimit.resetAt
            )
        )

        if let sparkWeeklyLimit = sparkRateLimit?.secondaryWindow {
            gauges.append(
                UsageGaugeData(
                    id: "codex-spark-weekly",
                    title: "Spark Weekly",
                    subtitle: "limit",
                    percent: sparkWeeklyLimit.remainingPercent,
                    resetAt: sparkWeeklyLimit.resetAt
                )
            )
        }

        return gauges
    }

    private var usageGauges: [UsageGaugeData] {
        codexUsageGauges + sparkUsageGauges
    }

    var body: some View {
        ZStack {
            AmbientBackdrop(tint: tint)

            VStack(alignment: .leading, spacing: 12) {
                header

                if store.errorMessage != nil {
                    errorCard
                } else {
                    ScrollView {
                        VStack(spacing: 12) {
                            resetBankCard
                            usageCard
                        }
                        .padding(.vertical, 1)
                    }
                    .scrollIndicators(.never)
                }

                footerControls
            }
            .padding(16)
        }
        .frame(minWidth: 390, idealWidth: 440, maxWidth: .infinity, minHeight: 540, idealHeight: 850, maxHeight: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .strokeBorder(.white.opacity(0.22), lineWidth: 1)
        }
        .shadow(color: tint.glow.opacity(0.22), radius: 34, x: 0, y: 18)
        .task {
            guard store.lastUpdated == nil, store.errorMessage == nil else {
                return
            }

            await store.refresh()
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Codex Meter")
                    .font(.system(size: 20, weight: .semibold, design: .rounded))
                    .foregroundStyle(.primary)

                Text("Codex usage and reset credits")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 12)

            IconButton(
                systemName: store.isLoading ? "hourglass" : "arrow.clockwise",
                help: "Refresh credits",
                action: {
                    Task {
                        await store.refresh()
                    }
                }
            )
            IconButton(systemName: "arrow.up.right.square", help: "Reset position and size", action: onSnap)
            IconButton(systemName: "eye.slash", help: "Hide widget", action: onHide)
        }
    }

    private var resetBankCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .bottom, spacing: 14) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Reset Bank")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)

                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(store.availableCount.map(String.init) ?? "-")
                            .font(.system(size: 54, weight: .semibold, design: .rounded))
                            .foregroundStyle(.primary)
                            .monospacedDigit()

                        Text("available")
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 8) {
                    StatusPill(
                        title: store.isLoading ? "Refreshing" : "Live",
                        systemName: store.isLoading ? "arrow.triangle.2.circlepath" : "checkmark.circle.fill",
                        tint: tint.primary
                    )

                    Text(updatedText)
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                }
            }

            resetBankRows
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 190, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(.regularMaterial)
                .overlay(alignment: .topTrailing) {
                    Circle()
                        .fill(tint.primary.opacity(0.6))
                        .frame(width: 96, height: 96)
                        .blur(radius: 30)
                        .offset(x: 22, y: -38)
                }
        }
    }

    @ViewBuilder
    private var resetBankRows: some View {
        if displayedCredits.isEmpty && !store.isLoading {
            Text("No reset credits returned.")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
        } else if displayedCredits.isEmpty {
            HStack(spacing: 10) {
                ProgressView()
                    .controlSize(.small)

                Text("Loading reset bank")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
        } else {
            VStack(spacing: 8) {
                ForEach(Array(displayedCredits.enumerated()), id: \.element.id) { index, credit in
                    ResetBankRow(index: index + 1, credit: credit, tint: tint)
                }
            }
        }
    }

    private var usageCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text("Usage remaining")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)

                Spacer()

                if let planType = store.usage?.planType {
                    Text("\(planType.capitalized) plan")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(.secondary)
                }
            }

            if store.usage != nil {
                usageMeters

                Text(weeklyResetText)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            } else {
                HStack(spacing: 10) {
                    ProgressView()
                        .controlSize(.small)

                    Text("Loading usage windows")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, minHeight: 58, alignment: .leading)
            }

        }
        .padding(14)
            .frame(maxWidth: .infinity, minHeight: usageCardMinHeight, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(.thinMaterial)
        }
    }

    @ViewBuilder
    private var usageMeters: some View {
        VStack(spacing: 10) {
            UsageMeterGroup(
                title: "Codex",
                gauges: codexUsageGauges,
                style: store.meterStyle,
                isHighlighted: false,
                runway: runwayInlineData(for: .codex)
            )

            if !sparkUsageGauges.isEmpty {
                UsageMeterGroup(
                    title: "Codex-Spark",
                    gauges: sparkUsageGauges,
                    style: store.meterStyle,
                    isHighlighted: true,
                    runway: runwayInlineData(for: .spark)
                )
            }
        }
    }

    private var usageCardMinHeight: CGFloat {
        switch store.meterStyle {
        case .circular:
            return !sparkUsageGauges.isEmpty ? 510 : 322
        case .horizontal, .battery:
            return CGFloat(176 + (usageGauges.count * 78) + (sparkUsageGauges.isEmpty ? 38 : 76))
        }
    }

    private func runwayInlineData(for group: RunwayForecastGroup) -> RunwayInlineData {
        let forecast = forecast(for: group)
        let tint = runwayConfidenceTint(for: forecast)

        return RunwayInlineData(
            title: "Weekly runway",
            status: runwayConfidenceTitle(for: forecast),
            icon: runwayConfidenceIcon(for: forecast),
            tint: tint,
            headline: runwayHeadline(for: forecast, group: group),
            detail: runwayDetailText(for: forecast, group: group)
        )
    }

    private func runwayConfidenceIcon(for forecast: UsageWindowForecast?) -> String {
        if forecast == nil || store.hasRunwayHistory == false {
            return "brain.head.profile"
        }

        switch forecast?.confidence {
        case .stable:
            return "checkmark.shield.fill"
        case .variable:
            return "chart.line.uptrend.xyaxis.circle"
        case .limitedData:
            return "hourglass"
        default:
            return "gauge.badge.plus"
        }
    }

    private func runwayConfidenceTitle(for forecast: UsageWindowForecast?) -> String {
        forecast?.confidence.rawValue ?? "Limited data"
    }

    private func runwayConfidenceTint(for forecast: UsageWindowForecast?) -> Color {
        if let forecast, forecast.willExhaustBeforeReset {
            return .red
        }

        if !store.hasRunwayHistory {
            return .secondary
        }

        guard let confidence = forecast?.confidence else {
            return .secondary
        }

        switch confidence {
        case .stable:
            return Color(red: 0.25, green: 0.78, blue: 0.45)
        case .variable:
            return Color(red: 0.96, green: 0.68, blue: 0.22)
        case .limitedData:
            return .secondary
        }
    }

    private func runwayHeadline(for forecast: UsageWindowForecast?, group: RunwayForecastGroup) -> String {
        guard store.hasRunwayHistory, let forecast else {
            return "\(group.label) runway learning"
        }

        if forecast.isLimitedData {
            return "\(group.label) runway learning"
        }

        if forecast.willExhaustBeforeReset {
            return "May run out \(runwayExhaustionText(for: forecast))"
        }

        switch forecast.confidence {
        case .stable:
            return "Likely safe through \(runwayResetLabel(for: forecast))"
        case .variable:
            return "Variable pace toward \(runwayResetLabel(for: forecast))"
        case .limitedData:
            return "\(group.label) runway learning"
        }
    }

    private func runwayDetailText(for forecast: UsageWindowForecast?, group: RunwayForecastGroup) -> String {
        guard let forecast, !forecast.isLimitedData else {
            return "History is local. Need a few refreshes before predictions appear."
        }

        let estimateText = runwayEstimateText(for: forecast)
        let resetText = runwayResetLabel(for: forecast)

        if forecast.willExhaustBeforeReset {
            if let estimateText {
                return "\(forecast.kind.title) · Reset \(resetText) · \(estimateText)"
            }
            return "\(forecast.kind.title) · Reset \(resetText) · observed pace"
        }

        if let estimateText {
            return "\(forecast.kind.title) · \(estimateText) by \(resetText)"
        }

        return "\(forecast.kind.title) · Reset \(resetText) · observed pace"
    }

    private func forecast(for group: RunwayForecastGroup) -> UsageWindowForecast? {
        group.preferredKinds.compactMap { kind in
            store.runwayPredictions.first { $0.kind == kind }
        }.first
    }

    private func runwayExhaustionText(for forecast: UsageWindowForecast) -> String {
        guard let projectedExhaustionDate = forecast.projectedExhaustionDate else {
            return "before reset"
        }

        return Self.runwayDateTimeFormatter.string(from: projectedExhaustionDate)
    }

    private func runwayEstimateText(for forecast: UsageWindowForecast) -> String? {
        if forecast.confidence == .stable, let estimate = forecast.estimatedRemainingAtReset {
            let clamped = max(0, Int(estimate.rounded()))
            return "Est. \(clamped)%"
        }

        if let range = forecast.estimatedRemainingRangeAtReset {
            let lower = max(0, Int(range.lowerBound.rounded()))
            let upper = max(0, Int(range.upperBound.rounded()))
            if lower == upper {
                return "Est. \(lower)%"
            }
            return "Est. \(lower)-\(upper)%"
        }

        if let estimate = forecast.estimatedRemainingAtReset {
            let clamped = max(0, Int(estimate.rounded()))
            return "Est. \(clamped)%"
        }

        return nil
    }

    private func runwayResetLabel(for forecast: UsageWindowForecast) -> String {
        if let resetAt = forecast.resetAt {
            return Self.runwayDateTimeFormatter.string(from: resetAt)
        }

        return forecast.kind.resetLabel
    }

    private var errorCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            StatusPill(title: "Needs attention", systemName: "exclamationmark.triangle.fill", tint: tint.secondary)

            Text(store.errorMessage ?? "Unable to load reset credits.")
                .font(.system(size: 17, weight: .semibold, design: .rounded))
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)

            if let recoveryMessage = store.recoveryMessage {
                Text(recoveryMessage)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Button {
                Task {
                    await store.refresh()
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.clockwise")
                    Text("Try Again")
                }
                .frame(maxWidth: .infinity, minHeight: 42)
            }
            .buttonStyle(WidgetButtonStyle())
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 364, alignment: .topLeading)
        .background {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(.regularMaterial)
        }
    }

    private var footerControls: some View {
        HStack(spacing: 10) {
            Button {
                store.cycleTint()
            } label: {
                HStack(spacing: 8) {
                    ZStack {
                        Circle()
                            .fill(tint.primary)
                            .frame(width: 12, height: 12)
                        Circle()
                            .fill(tint.secondary.opacity(0.8))
                            .frame(width: 7, height: 7)
                            .offset(x: 4, y: -3)
                    }

                    Text(tint.name)
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                }
                .frame(maxWidth: .infinity, minHeight: 32)
            }
            .buttonStyle(WidgetButtonStyle())
            .help("Change color mood")

            Spacer(minLength: 12)
        }
    }

    private var updatedText: String {
        guard let lastUpdated = store.lastUpdated else {
            return "Not updated yet"
        }

        return "Updated \(Self.timeFormatter.string(from: lastUpdated))"
    }

    private var weeklyResetText: String {
        guard let resetAt = store.usage?.rateLimit?.secondaryWindow?.resetAt else {
            return "Weekly reset unavailable"
        }

        return "Codex weekly reset: \(Self.weeklyResetFormatter.string(from: resetAt))"
    }

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return formatter
    }()

    private static let weeklyResetFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, h:mm a"
        return formatter
    }()

    private static let runwayDateTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, h:mm a"
        return formatter
    }()
}

private enum RunwayForecastGroup {
    case codex
    case spark

    var title: String {
        switch self {
        case .codex:
            return "Codex runway"
        case .spark:
            return "Spark runway"
        }
    }

    var label: String {
        switch self {
        case .codex:
            return "Codex"
        case .spark:
            return "Spark"
        }
    }

    var preferredKinds: [UsageWindowKind] {
        switch self {
        case .codex:
            return [.codexWeekly, .codexPrimary]
        case .spark:
            return [.sparkWeekly, .sparkPrimary]
        }
    }
}

private struct ResetBankRow: View {
    let index: Int
    let credit: RateLimitResetCredit
    let tint: WidgetTint

    var body: some View {
        HStack(spacing: 10) {
            Text("\(index)")
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.primary)
                .frame(width: 24, height: 24)
                .background {
                    Circle()
                        .fill(tint.primary.opacity(0.18))
                }

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text("Reset \(index)")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)

                    Text(credit.statusTitle)
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .foregroundStyle(credit.isAvailable ? tint.primary : .secondary)
                }

                HStack(spacing: 10) {
                    Text("Granted \(Self.compactDateFormatter.string(from: credit.grantedAt))")
                    Text("Expires \(Self.compactDateFormatter.string(from: credit.expiresAt))")
                }
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.82)
            }

            Spacer(minLength: 6)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, minHeight: 48, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(.thinMaterial)
        }
    }

    private static let compactDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, h:mm a"
        return formatter
    }()
}

private struct UsageGaugeData: Identifiable {
    let id: String
    let title: String
    let subtitle: String
    let percent: Int
    let resetAt: Date?
}

private struct RunwayInlineData {
    let title: String
    let status: String
    let icon: String
    let tint: Color
    let headline: String
    let detail: String
}

private struct UsageMeterGroup: View {
    let title: String
    let gauges: [UsageGaugeData]
    let style: MeterStyle
    let isHighlighted: Bool
    let runway: RunwayInlineData?

    private var circularMeterColumns: [GridItem] {
        [
            GridItem(.flexible(minimum: 136), spacing: 10),
            GridItem(.flexible(minimum: 136), spacing: 10)
        ]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 7) {
                Image(systemName: isHighlighted ? "sparkles" : "terminal")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(isHighlighted ? Color.mint : Color.secondary)

                Text(title)
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(isHighlighted ? Color.primary : Color.secondary)
                    .textCase(.uppercase)
            }

            switch style {
            case .circular:
                LazyVGrid(columns: circularMeterColumns, spacing: 10) {
                    ForEach(gauges) { gauge in
                        CircularUsageMeter(gauge: gauge)
                    }
                }
            case .horizontal:
                VStack(spacing: 8) {
                    ForEach(gauges) { gauge in
                        HorizontalUsageMeter(gauge: gauge)
                    }
                }
            case .battery:
                VStack(spacing: 8) {
                    ForEach(gauges) { gauge in
                        BatteryUsageMeter(gauge: gauge)
                    }
                }
            }

            if let runway {
                RunwayInlineRow(data: runway)
            }
        }
        .padding(isHighlighted ? 10 : 0)
        .background {
            if isHighlighted {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.mint.opacity(0.08))
                    .overlay {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .strokeBorder(Color.mint.opacity(0.14), lineWidth: 1)
                    }
            }
        }
    }
}

private struct RunwayInlineRow: View {
    let data: RunwayInlineData

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            Image(systemName: data.icon)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(data.tint)
                .frame(width: 22, height: 22)
                .background {
                    Circle()
                        .fill(data.tint.opacity(0.14))
                }

            VStack(alignment: .leading, spacing: 3) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(data.title)
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)

                    Text(data.status)
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundStyle(data.tint)
                }

                Text(data.headline)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(data.tint)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)

                Text(data.detail)
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
            }

            Spacer(minLength: 6)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .frame(maxWidth: .infinity, minHeight: 58, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(.regularMaterial.opacity(0.52))
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(data.tint.opacity(0.18), lineWidth: 1)
                }
        }
    }
}

private struct CircularUsageMeter: View {
    let gauge: UsageGaugeData

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .stroke(.primary.opacity(0.10), lineWidth: 8)

                Circle()
                    .trim(from: 0, to: gauge.ratio)
                    .stroke(
                        gauge.statusTint,
                        style: StrokeStyle(lineWidth: 8, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .shadow(color: gauge.statusTint.opacity(0.34), radius: 8, x: 0, y: 0)

                VStack(spacing: 0) {
                    Text("\(gauge.clampedPercent)")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.primary)

                    Text("%")
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 70, height: 70)

            VStack(spacing: 2) {
                Text(gauge.title)
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)

                Text(gauge.subtitle)
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
            }

            Text(gauge.resetText)
                .font(.system(size: 9, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, minHeight: 128)
        .background {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(.regularMaterial.opacity(0.58))
        }
    }
}

private struct HorizontalUsageMeter: View {
    let gauge: UsageGaugeData

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(gauge.title)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)

                Text(gauge.subtitle)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)

                Spacer(minLength: 8)

                Text("\(gauge.clampedPercent)%")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.primary)
            }

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule(style: .continuous)
                        .fill(.primary.opacity(0.11))

                    Capsule(style: .continuous)
                        .fill(gauge.statusTint)
                        .frame(width: max(10, proxy.size.width * gauge.ratio))
                        .shadow(color: gauge.statusTint.opacity(0.26), radius: 7, x: 0, y: 0)
                }
            }
            .frame(height: 12)

            Text(gauge.resetText)
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.86)
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 70, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(.regularMaterial.opacity(0.58))
        }
    }
}

private struct BatteryUsageMeter: View {
    let gauge: UsageGaugeData

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 7) {
                    Text(gauge.title)
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)

                    Text(gauge.subtitle)
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)
                }

                Text(gauge.resetText)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.86)
            }

            Spacer(minLength: 10)

            BatteryShell(gauge: gauge)
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 70, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(.regularMaterial.opacity(0.58))
        }
    }
}

private struct BatteryShell: View {
    let gauge: UsageGaugeData

    var body: some View {
        HStack(spacing: 7) {
            ZStack {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(.primary.opacity(0.07))
                    .overlay {
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .strokeBorder(.primary.opacity(0.18), lineWidth: 1)
                    }

                GeometryReader { proxy in
                    let fillWidth = max(8, (proxy.size.width - 10) * gauge.ratio)

                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(gauge.statusTint)
                        .frame(width: fillWidth, height: proxy.size.height - 10)
                        .padding(5)
                        .shadow(color: gauge.statusTint.opacity(0.26), radius: 7, x: 0, y: 0)
                }

                Text("\(gauge.clampedPercent)%")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.primary)
            }
            .frame(width: 112, height: 38)

            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(.primary.opacity(0.22))
                .frame(width: 5, height: 18)
        }
        .frame(width: 124, alignment: .trailing)
    }
}

private enum UsageMeterFormatters {
    static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return formatter
    }()
}

private extension UsageGaugeData {
    var clampedPercent: Int {
        max(0, min(100, percent))
    }

    var ratio: CGFloat {
        CGFloat(clampedPercent) / 100
    }

    var resetText: String {
        guard let resetAt else {
            return "5h window"
        }

        return "resets \(UsageMeterFormatters.timeFormatter.string(from: resetAt))"
    }

    var statusTint: Color {
        switch clampedPercent {
        case 90...100:
            return Color(red: 0.25, green: 0.78, blue: 0.45)
        case 20..<90:
            return Color(red: 0.96, green: 0.68, blue: 0.22)
        default:
            return Color(red: 0.96, green: 0.28, blue: 0.24)
        }
    }
}

private struct StatusPill: View {
    let title: String
    let systemName: String
    let tint: Color

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: systemName)
                .font(.system(size: 11, weight: .semibold))

            Text(title)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
        }
        .foregroundStyle(.primary)
        .padding(.horizontal, 9)
        .padding(.vertical, 6)
        .background {
            Capsule(style: .continuous)
                .fill(tint.opacity(0.16))
                .overlay {
                    Capsule(style: .continuous)
                        .strokeBorder(tint.opacity(0.24), lineWidth: 1)
                }
        }
    }
}
