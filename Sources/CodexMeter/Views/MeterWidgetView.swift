import SwiftUI

struct MeterWidgetView: View {
    @ObservedObject var store: WidgetStore
    let onHide: () -> Void
    let onSnap: () -> Void

    private var tint: WidgetTint {
        WidgetTint.all[store.tintIndex % WidgetTint.all.count]
    }

    private var displayedCredits: [RateLimitResetCredit] {
        store.credits
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
                    title: L10n.text("usageWindow.weekly.title"),
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
        guard let sparkRateLimit = store.usage?.additionalRateLimits
            .first(where: { $0.displayName == "Codex-Spark" || $0.meteredFeature == "codex_bengalfox" })?
            .rateLimit else {
            return []
        }

        if let sparkLimit = sparkRateLimit.primaryWindow {
            gauges.append(
                UsageGaugeData(
                    id: "codex-spark",
                    title: "Spark",
                    subtitle: L10n.text("usageWindow.fiveHourLimit.subtitle"),
                    percent: sparkLimit.remainingPercent,
                    resetAt: sparkLimit.resetAt
                )
            )
        }

        if let sparkWeeklyLimit = sparkRateLimit.secondaryWindow {
            gauges.append(
                UsageGaugeData(
                    id: "codex-spark-weekly",
                    title: L10n.text("usageWindow.sparkWeekly.displayTitle"),
                    subtitle: L10n.text("usageWindow.limit.subtitle"),
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

                if store.shouldShowUnavailableState {
                    unavailableStateCard
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
            guard !store.hasVisibleData, !store.isLoading else {
                return
            }

            await store.refresh()
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(L10n.text("app.name"))
                    .font(.system(size: 20, weight: .semibold, design: .rounded))
                    .foregroundStyle(.primary)

                Text(L10n.text("widget.subtitle"))
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 12)

            IconButton(
                systemName: store.isLoading ? "hourglass" : "arrow.clockwise",
                help: L10n.text("help.refreshCredits"),
                action: {
                    Task {
                        await store.refresh()
                    }
                }
            )
            IconButton(systemName: "arrow.up.right.square", help: L10n.text("help.resetPositionAndSize"), action: onSnap)
            IconButton(systemName: "eye.slash", help: L10n.text("help.hideWidget"), action: onHide)
        }
    }

    private var resetBankCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .bottom, spacing: 14) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(L10n.text("endpoint.resetCredits.title"))
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)

                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(store.availableCount.map(String.init) ?? "-")
                            .font(.system(size: 54, weight: .semibold, design: .rounded))
                            .foregroundStyle(.primary)
                            .monospacedDigit()

                        Text(L10n.text("resetBank.available"))
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 8) {
                    StatusPill(
                        title: store.resetCreditRefreshState.title,
                        systemName: store.resetCreditRefreshState.systemName,
                        tint: statusTint(for: store.resetCreditRefreshState)
                    )

                    Text(timestampText(for: store.resetCreditRefreshState))
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                }
            }

            if shouldShowIssue(for: store.resetCreditRefreshState) {
                endpointIssueRow(for: store.resetCreditRefreshState)
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
        if displayedCredits.isEmpty && store.resetCreditRefreshState.isUnavailable {
            Text(L10n.text("resetBank.dataUnavailable"))
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
        } else if displayedCredits.isEmpty && !store.isLoading {
            Text(L10n.text("resetBank.empty"))
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
        } else if displayedCredits.isEmpty {
            HStack(spacing: 10) {
                ProgressView()
                    .controlSize(.small)

                Text(L10n.text("resetBank.loading"))
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
        } else {
            LazyVStack(spacing: 8) {
                ForEach(Array(displayedCredits.enumerated()), id: \.element.id) { index, credit in
                    ResetBankRow(index: index + 1, credit: credit, tint: tint)
                }
            }
        }
    }

    private var usageCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(L10n.text("usage.remaining.title"))
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)

                Spacer()

                if let planType = store.usage?.planType {
                    Text(L10n.text("usage.plan", planType.capitalized))
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(.secondary)
                }

                StatusPill(
                    title: store.usageRefreshState.title,
                    systemName: store.usageRefreshState.systemName,
                    tint: statusTint(for: store.usageRefreshState)
                )
            }

            if store.usage != nil {
                Text(usageFreshnessText)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(store.usageRefreshState.isStale ? statusTint(for: store.usageRefreshState) : .secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
                    .accessibilityLabel(usageAccessibilityText)

                if shouldShowIssue(for: store.usageRefreshState) {
                    endpointIssueRow(for: store.usageRefreshState)
                }

                sessionReadinessRow

                usageMeters

                Text(weeklyResetText)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            } else if store.usageRefreshState.isUnavailable {
                unavailableEndpointContent(for: store.usageRefreshState)
            } else {
                HStack(spacing: 10) {
                    ProgressView()
                        .controlSize(.small)

                    Text(L10n.text("usage.loadingWindows"))
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

    private var sessionReadinessRow: some View {
        SessionReadinessRow(advice: store.sessionReadinessAdvice)
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
        let readinessHeight: CGFloat = 74
        switch store.meterStyle {
        case .circular:
            return (!sparkUsageGauges.isEmpty ? 510 : 322) + readinessHeight
        case .horizontal, .battery:
            return CGFloat(176 + (usageGauges.count * 78) + (sparkUsageGauges.isEmpty ? 38 : 76)) + readinessHeight
        }
    }

    private func runwayInlineData(for group: RunwayForecastGroup) -> RunwayInlineData {
        let forecast = forecast(for: group)
        let tint = runwayConfidenceTint(for: forecast)

        return RunwayInlineData(
            title: L10n.text("runway.inline.title"),
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
        forecast?.confidence.title ?? L10n.text("runway.confidence.limitedData")
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
            return L10n.text("runway.headline.learning", group.label)
        }

        if forecast.isLimitedData {
            return L10n.text("runway.headline.learning", group.label)
        }

        if forecast.willExhaustBeforeReset {
            return L10n.text("runway.headline.mayRunOut", runwayExhaustionText(for: forecast))
        }

        switch forecast.confidence {
        case .stable:
            return L10n.text("runway.headline.safeThrough", runwayResetLabel(for: forecast))
        case .variable:
            return L10n.text("runway.headline.variableToward", runwayResetLabel(for: forecast))
        case .limitedData:
            return L10n.text("runway.headline.learning", group.label)
        }
    }

    private func runwayDetailText(for forecast: UsageWindowForecast?, group: RunwayForecastGroup) -> String {
        guard let forecast, !forecast.isLimitedData else {
            return L10n.text("runway.detail.learning")
        }

        let estimateText = runwayEstimateText(for: forecast)
        let resetText = runwayResetLabel(for: forecast)

        if forecast.willExhaustBeforeReset {
            if let estimateText {
                return L10n.text("runway.detail.resetWithEstimate", forecast.kind.title, resetText, estimateText)
            }
            return L10n.text("runway.detail.resetObservedPace", forecast.kind.title, resetText)
        }

        if let estimateText {
            return L10n.text("runway.detail.estimateByReset", forecast.kind.title, estimateText, resetText)
        }

        return L10n.text("runway.detail.resetObservedPace", forecast.kind.title, resetText)
    }

    private func forecast(for group: RunwayForecastGroup) -> UsageWindowForecast? {
        group.preferredKinds.compactMap { kind in
            store.runwayPredictions.first { $0.kind == kind }
        }.first
    }

    private func runwayExhaustionText(for forecast: UsageWindowForecast) -> String {
        guard let projectedExhaustionDate = forecast.projectedExhaustionDate else {
            return L10n.text("runway.exhaustion.beforeReset")
        }

        // The projection is a linear extrapolation from observed pace, so we never
        // imply minute-level precision. Stable forecasts get hour granularity;
        // variable forecasts collapse to the day. The "~" marks it as an estimate.
        switch forecast.confidence {
        case .stable:
            return "~\(Self.runwayHourFormatter.string(from: projectedExhaustionDate))"
        case .variable, .limitedData:
            return "~\(Self.runwayDayFormatter.string(from: projectedExhaustionDate))"
        }
    }

    private func runwayEstimateText(for forecast: UsageWindowForecast) -> String? {
        if forecast.confidence == .stable, let estimate = forecast.estimatedRemainingAtReset {
            let clamped = max(0, Int(estimate.rounded()))
            return L10n.text("runway.estimate.single", clamped)
        }

        if let range = forecast.estimatedRemainingRangeAtReset {
            let lower = max(0, Int(range.lowerBound.rounded()))
            let upper = max(0, Int(range.upperBound.rounded()))
            if lower == upper {
                return L10n.text("runway.estimate.single", lower)
            }
            return L10n.text("runway.estimate.range", lower, upper)
        }

        if let estimate = forecast.estimatedRemainingAtReset {
            let clamped = max(0, Int(estimate.rounded()))
            return L10n.text("runway.estimate.single", clamped)
        }

        return nil
    }

    private func runwayResetLabel(for forecast: UsageWindowForecast) -> String {
        if let resetAt = forecast.resetAt {
            return Self.runwayDateTimeFormatter.string(from: resetAt)
        }

        return forecast.kind.resetLabel
    }

    private var unavailableStateCard: some View {
        let failure = store.primaryFailure

        return VStack(alignment: .leading, spacing: 10) {
            StatusPill(
                title: failure?.statusTitle ?? L10n.text("failure.status.genericNeedsAttention"),
                systemName: noDataStateSystemName(for: failure),
                tint: noDataStateTint(for: failure)
            )

            Text(failure?.statusTitle ?? L10n.text("widget.unavailable.title"))
                .font(.system(size: 17, weight: .semibold, design: .rounded))
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)

            Text(failure?.detailText ?? L10n.text("widget.unavailable.detail"))
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if let recoverySuggestion = failure?.recoverySuggestion {
                Text(recoverySuggestion)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
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
                    Text(L10n.text("action.tryAgain"))
                }
                .frame(maxWidth: .infinity, minHeight: 42)
            }
            .buttonStyle(WidgetButtonStyle())

            diagnosticsButton
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
            .help(L10n.text("help.changeColorMood"))

            Spacer(minLength: 12)
        }
    }

    private var diagnosticsButton: some View {
        Button {
            store.copyDiagnostics()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "doc.on.doc")
                Text(store.diagnosticsCopyMessage ?? L10n.text("action.copyDiagnostics"))
            }
            .font(.system(size: 12, weight: .semibold, design: .rounded))
            .frame(maxWidth: .infinity, minHeight: 34)
        }
        .buttonStyle(WidgetButtonStyle())
        .help(L10n.text("help.copyDiagnostics"))
    }

    private func endpointIssueRow(for state: EndpointRefreshState) -> some View {
        EndpointIssueRow(
            message: issueMessage(for: state),
            tint: statusTint(for: state),
            copyMessage: store.diagnosticsCopyMessage,
            onCopyDiagnostics: {
                store.copyDiagnostics()
            }
        )
    }

    private func unavailableEndpointContent(for state: EndpointRefreshState) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(state.failure?.detailText ?? L10n.text("endpoint.dataUnavailable", state.endpoint.title))
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if let recoverySuggestion = state.failure?.recoverySuggestion {
                Text(recoverySuggestion)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            endpointIssueRow(for: state)
        }
        .frame(maxWidth: .infinity, minHeight: 58, alignment: .leading)
    }

    private func shouldShowIssue(for state: EndpointRefreshState) -> Bool {
        state.failure != nil && (state.isStale || state.isUnavailable)
    }

    private func issueMessage(for state: EndpointRefreshState) -> String {
        guard let failure = state.failure else {
            return ""
        }

        if state.isStale {
            return L10n.text("endpoint.issue.showingLastKnownGood", failure.detailText)
        }

        return failure.detailText
    }

    private func timestampText(for state: EndpointRefreshState) -> String {
        state.timestampText(
            now: Date(),
            timeFormatter: Self.timeFormatter,
            relativeFormatter: Self.relativeFormatter
        )
    }

    private var usageFreshnessText: String {
        let percentText = usageRemainingPercent.map { L10n.text("usage.percentRemaining", $0) } ?? L10n.text("usage.dataAvailable")
        return L10n.text("usage.freshness", percentText, timestampText(for: store.usageRefreshState))
    }

    private var usageAccessibilityText: String {
        let percentText = usageRemainingPercent.map { L10n.text("usage.accessibility.percentRemaining", $0) } ?? L10n.text("usage.dataAvailable")
        return L10n.text("usage.accessibility.summary", percentText, store.usageRefreshState.title.lowercased(), timestampText(for: store.usageRefreshState).lowercased())
    }

    private var usageRemainingPercent: Int? {
        codexUsageGauges.first?.clampedPercent
    }

    private func statusTint(for state: EndpointRefreshState) -> Color {
        switch state.tone {
        case .neutral:
            return .secondary
        case .progress:
            return tint.primary
        case .live:
            return tint.primary
        case .warning:
            return Color(red: 0.96, green: 0.68, blue: 0.22)
        case .error:
            return Color(red: 0.96, green: 0.28, blue: 0.24)
        }
    }

    private func noDataStateSystemName(for failure: EndpointFailure?) -> String {
        switch failure?.category {
        case .missingAuth:
            return "person.crop.circle.badge.exclamationmark"
        case .expiredSession:
            return "lock.trianglebadge.exclamationmark"
        case .schemaMismatch, .malformedPayload:
            return "curlybraces.square"
        default:
            return "exclamationmark.triangle.fill"
        }
    }

    private func noDataStateTint(for failure: EndpointFailure?) -> Color {
        switch failure?.category {
        case .missingAuth:
            return Color(red: 0.96, green: 0.68, blue: 0.22)
        default:
            return tint.secondary
        }
    }

    private var weeklyResetText: String {
        guard let resetAt = store.usage?.rateLimit?.secondaryWindow?.resetAt else {
            return L10n.text("usage.weeklyResetUnavailable")
        }

        return L10n.text("usage.weeklyReset", Self.weeklyResetFormatter.string(from: resetAt))
    }

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return formatter
    }()

    private static let relativeFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter
    }()

    private static let weeklyResetFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate("MMM d h:mm a")
        return formatter
    }()

    private static let runwayDateTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate("MMM d h:mm a")
        return formatter
    }()

    private static let runwayHourFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate("MMM d h a")
        return formatter
    }()

    private static let runwayDayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate("MMM d")
        return formatter
    }()
}

private enum RunwayForecastGroup {
    case codex
    case spark

    var title: String {
        switch self {
        case .codex:
            return L10n.text("runway.group.codexTitle")
        case .spark:
            return L10n.text("runway.group.sparkTitle")
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
                    Text(L10n.text("resetBank.row.title", index))
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)

                    Text(credit.statusTitle)
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .foregroundStyle(credit.isAvailable ? tint.primary : .secondary)
                }

                HStack(spacing: 10) {
                    Text(L10n.text("resetBank.row.granted", Self.compactDateFormatter.string(from: credit.grantedAt)))
                    Text(L10n.text("resetBank.row.expires", Self.compactDateFormatter.string(from: credit.expiresAt)))
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
        formatter.setLocalizedDateFormatFromTemplate("MMM d h:mm a")
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

private struct SessionReadinessRow: View {
    let advice: SessionReadinessAdvice

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            Image(systemName: advice.systemName)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(advice.readinessTint)
                .frame(width: 24, height: 24)
                .background {
                    Circle()
                        .fill(advice.readinessTint.opacity(0.14))
                }

            VStack(alignment: .leading, spacing: 3) {
                Text(advice.title)
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)

                Text(advice.headline)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(advice.readinessTint)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)

                Text(advice.detail)
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.82)
            }

            Spacer(minLength: 6)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .frame(maxWidth: .infinity, minHeight: 66, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(.regularMaterial.opacity(0.52))
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(advice.readinessTint.opacity(0.18), lineWidth: 1)
                }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(advice.title), \(advice.headline), \(advice.detail)")
    }
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
            return L10n.text("usageMeter.reset.fiveHourWindow")
        }

        return L10n.text("usageMeter.reset.resetsAt", UsageMeterFormatters.timeFormatter.string(from: resetAt))
    }

    var statusTint: Color {
        // Health by remaining capacity: green while there's a comfortable
        // balance, amber as it gets low, red near depletion. The green band is
        // deliberately wide — a meter that turns amber at 89% remaining reads as
        // a warning when the user is actually fine.
        switch clampedPercent {
        case 50...100:
            return Color(red: 0.25, green: 0.78, blue: 0.45)
        case 20..<50:
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

private struct EndpointIssueRow: View {
    let message: String
    let tint: Color
    let copyMessage: String?
    let onCopyDiagnostics: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .center, spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(tint)

                Text(message)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.84)

                Spacer(minLength: 8)

                Button(action: onCopyDiagnostics) {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 11, weight: .semibold))
                        .frame(width: 26, height: 26)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.primary)
                .background {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(tint.opacity(0.12))
                        .overlay {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .strokeBorder(tint.opacity(0.20), lineWidth: 1)
                        }
                }
                .help(copyMessage ?? L10n.text("action.copyDiagnostics"))
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 7)
            .background {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(tint.opacity(0.09))
                    .overlay {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .strokeBorder(tint.opacity(0.15), lineWidth: 1)
                    }
            }

            if let copyMessage {
                Text(copyMessage)
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundStyle(tint)
                    .padding(.leading, 2)
            }
        }
    }
}
