import Combine
import Foundation

@MainActor
final class WidgetStore: ObservableObject {
    @Published var tintIndex: Int {
        didSet { save() }
    }

    @Published var autoRefreshEnabled: Bool {
        didSet { save() }
    }

    @Published var refreshIntervalSeconds: TimeInterval {
        didSet { save() }
    }

    @Published var showSparkUsage: Bool {
        didSet { save() }
    }

    @Published var meterStyle: MeterStyle {
        didSet { save() }
    }

    @Published var smartAlertsEnabled: Bool {
        didSet { save() }
    }

    @Published var alertThresholdsEnabled: Bool {
        didSet { save() }
    }

    @Published var alert20PercentEnabled: Bool {
        didSet { save() }
    }

    @Published var alert10PercentEnabled: Bool {
        didSet { save() }
    }

    @Published var alert5PercentEnabled: Bool {
        didSet { save() }
    }

    @Published var alertProjectedRunoutEnabled: Bool {
        didSet { save() }
    }

    @Published var alertCreditsExpiringEnabled: Bool {
        didSet { save() }
    }

    @Published var alertResetAvailableEnabled: Bool {
        didSet { save() }
    }

    @Published private(set) var availableCount: Int?
    @Published private(set) var credits: [RateLimitResetCredit] = []
    @Published private(set) var usage: UsageResponse?
    @Published private(set) var runwayPredictions: [UsageWindowForecast] = []
    @Published private(set) var notificationAuthStatus: NotificationAuthorizationStatus = .notDetermined
    @Published private(set) var isLoading = false
    @Published private(set) var lastUpdated: Date?
    @Published private(set) var errorMessage: String?
    @Published private(set) var recoveryMessage: String?
    @Published private(set) var hasRunwayHistory = false

    private let defaults: UserDefaults
    private let authReader: CodexAuthTokenReader
    private let client: RateLimitResetClient
    private let usageClient: UsageClient
    private let historyStore: UsageHistoryStore
    private let predictionService: RunwayPredictionService
    private let notificationService: SmartNotificationService

    init(
        defaults: UserDefaults = .standard,
        authReader: CodexAuthTokenReader = CodexAuthTokenReader(),
        client: RateLimitResetClient = RateLimitResetClient(),
        usageClient: UsageClient = UsageClient(),
        historyStore: UsageHistoryStore = UsageHistoryStore(),
        predictionService: RunwayPredictionService = RunwayPredictionService(),
        notificationService: SmartNotificationService = SmartNotificationService()
    ) {
        self.defaults = defaults
        self.authReader = authReader
        self.client = client
        self.usageClient = usageClient
        self.historyStore = historyStore
        self.predictionService = predictionService
        self.notificationService = notificationService

        self.tintIndex = defaults.object(forKey: DefaultsKey.tintIndex) as? Int ?? 0
        self.autoRefreshEnabled = defaults.object(forKey: DefaultsKey.autoRefreshEnabled) as? Bool ?? true
        self.refreshIntervalSeconds = defaults.object(forKey: DefaultsKey.refreshIntervalSeconds) as? TimeInterval ?? 60
        self.showSparkUsage = defaults.object(forKey: DefaultsKey.showSparkUsage) as? Bool ?? true
        self.meterStyle = defaults
            .string(forKey: DefaultsKey.meterStyle)
            .flatMap(MeterStyle.init(rawValue:)) ?? .circular
        self.smartAlertsEnabled = defaults.object(forKey: DefaultsKey.smartAlertsEnabled) as? Bool ?? false
        self.alertThresholdsEnabled = defaults.object(forKey: DefaultsKey.alertThresholdsEnabled) as? Bool ?? true
        self.alert20PercentEnabled = defaults.object(forKey: DefaultsKey.alert20PercentEnabled) as? Bool ?? true
        self.alert10PercentEnabled = defaults.object(forKey: DefaultsKey.alert10PercentEnabled) as? Bool ?? true
        self.alert5PercentEnabled = defaults.object(forKey: DefaultsKey.alert5PercentEnabled) as? Bool ?? true
        self.alertProjectedRunoutEnabled = defaults.object(forKey: DefaultsKey.alertProjectedRunoutEnabled) as? Bool ?? true
        self.alertCreditsExpiringEnabled = defaults.object(forKey: DefaultsKey.alertCreditsExpiringEnabled) as? Bool ?? true
        self.alertResetAvailableEnabled = defaults.object(forKey: DefaultsKey.alertResetAvailableEnabled) as? Bool ?? true

        hasRunwayHistory = !historyStore.allObservations().isEmpty
        Task {
            await refreshNotificationStatus()
        }
    }

    var canSendTestNotification: Bool {
        return notificationAuthStatus == .authorized || notificationAuthStatus == .provisional || notificationAuthStatus == .ephemeral
    }

    func cycleTint() {
        tintIndex = (tintIndex + 1) % WidgetTint.all.count
    }

    func requestNotificationPermission() async {
        guard await notificationService.requestPermission() else {
            await refreshNotificationStatus()
            return
        }
        await refreshNotificationStatus()
    }

    func sendTestNotification() async {
        guard canSendNotifications else {
            return
        }

        await notificationService.sendNotification(
            title: "Codex Meter test alert",
            body: "Local smart alert pipeline is working.",
            identifier: "cm-test-\(UUID().uuidString)"
        )
    }

    func refresh() async {
        guard !isLoading else {
            return
        }

        isLoading = true
        errorMessage = nil
        recoveryMessage = nil

        do {
            let token = try authReader.accessToken()
            async let usageResponse = usageClient.fetchUsage(accessToken: token)
            async let creditResponse = client.fetchCredits(accessToken: token)

            let (usageResult, creditResult) = try await (usageResponse, creditResponse)
            usage = usageResult
            availableCount = usageResult.rateLimitResetCredits?.availableCount ?? creditResult.availableCount
            credits = creditResult.credits.sorted { $0.expiresAt < $1.expiresAt }
            lastUpdated = Date()

            let previousObservation = historyStore.latestObservation()
            let observation = buildUsageObservation(from: usageResult, availableResetCount: availableCount ?? 0, at: lastUpdated ?? Date(), credits: credits)
            historyStore.append(observation)
            hasRunwayHistory = true

            runwayPredictions = predictionService.predictions(
                from: historyStore.allObservations().flatMap(\.windows),
                now: lastUpdated ?? Date()
            )

            await evaluateAndSendSmartAlerts(
                previousObservation: previousObservation,
                currentObservation: observation,
                now: lastUpdated ?? Date()
            )
        } catch {
            errorMessage = error.localizedDescription
            recoveryMessage = (error as? LocalizedError)?.recoverySuggestion
        }

        isLoading = false
    }

    func refreshIfStale(maxAge: TimeInterval = 15) async {
        if let lastUpdated, Date().timeIntervalSince(lastUpdated) < maxAge {
            return
        }

        await refresh()
    }

    func save() {
        defaults.set(tintIndex, forKey: DefaultsKey.tintIndex)
        defaults.set(autoRefreshEnabled, forKey: DefaultsKey.autoRefreshEnabled)
        defaults.set(refreshIntervalSeconds, forKey: DefaultsKey.refreshIntervalSeconds)
        defaults.set(showSparkUsage, forKey: DefaultsKey.showSparkUsage)
        defaults.set(meterStyle.rawValue, forKey: DefaultsKey.meterStyle)
        defaults.set(smartAlertsEnabled, forKey: DefaultsKey.smartAlertsEnabled)
        defaults.set(alertThresholdsEnabled, forKey: DefaultsKey.alertThresholdsEnabled)
        defaults.set(alert20PercentEnabled, forKey: DefaultsKey.alert20PercentEnabled)
        defaults.set(alert10PercentEnabled, forKey: DefaultsKey.alert10PercentEnabled)
        defaults.set(alert5PercentEnabled, forKey: DefaultsKey.alert5PercentEnabled)
        defaults.set(alertProjectedRunoutEnabled, forKey: DefaultsKey.alertProjectedRunoutEnabled)
        defaults.set(alertCreditsExpiringEnabled, forKey: DefaultsKey.alertCreditsExpiringEnabled)
        defaults.set(alertResetAvailableEnabled, forKey: DefaultsKey.alertResetAvailableEnabled)
    }

    func alertPreferences() -> SmartAlertPreferences {
        SmartAlertPreferences(
            enabled: smartAlertsEnabled,
            capacityThresholdsEnabled: alertThresholdsEnabled,
            threshold20Percent: alert20PercentEnabled,
            threshold10Percent: alert10PercentEnabled,
            threshold5Percent: alert5PercentEnabled,
            projectedRunoutEnabled: alertProjectedRunoutEnabled,
            creditsExpireSoonEnabled: alertCreditsExpiringEnabled,
            resetCreditReturnedEnabled: alertResetAvailableEnabled
        )
    }

    private func buildUsageObservation(
        from usage: UsageResponse,
        availableResetCount: Int,
        at timestamp: Date,
        credits: [RateLimitResetCredit]
    ) -> UsageObservation {
        var observations: [UsageWindowObservation] = []

        if let primary = usage.rateLimit?.primaryWindow {
            observations.append(
                UsageWindowObservation(
                    sampledAt: timestamp,
                    kind: .codexPrimary,
                    remainingPercent: primary.remainingPercent,
                    usedPercent: primary.usedPercent,
                    limitWindowSeconds: primary.limitWindowSeconds,
                    resetAfterSeconds: primary.resetAfterSeconds,
                    resetAt: primary.resetAt
                )
            )
        }

        if let weekly = usage.rateLimit?.secondaryWindow {
            observations.append(
                UsageWindowObservation(
                    sampledAt: timestamp,
                    kind: .codexWeekly,
                    remainingPercent: weekly.remainingPercent,
                    usedPercent: weekly.usedPercent,
                    limitWindowSeconds: weekly.limitWindowSeconds,
                    resetAfterSeconds: weekly.resetAfterSeconds,
                    resetAt: weekly.resetAt
                )
            )
        }

        let sparkRateLimits = usage.additionalRateLimits.filter {
            $0.meteredFeature == "codex_bengalfox" || $0.displayName == "Codex-Spark"
        }

        for spark in sparkRateLimits {
            if let primary = spark.rateLimit.primaryWindow {
                observations.append(
                    UsageWindowObservation(
                        sampledAt: timestamp,
                        kind: .sparkPrimary,
                        remainingPercent: primary.remainingPercent,
                        usedPercent: primary.usedPercent,
                        limitWindowSeconds: primary.limitWindowSeconds,
                        resetAfterSeconds: primary.resetAfterSeconds,
                        resetAt: primary.resetAt
                    )
                )
            }

            if let weekly = spark.rateLimit.secondaryWindow {
                observations.append(
                    UsageWindowObservation(
                        sampledAt: timestamp,
                        kind: .sparkWeekly,
                        remainingPercent: weekly.remainingPercent,
                        usedPercent: weekly.usedPercent,
                        limitWindowSeconds: weekly.limitWindowSeconds,
                        resetAfterSeconds: weekly.resetAfterSeconds,
                        resetAt: weekly.resetAt
                    )
                )
            }
        }

        let expiries = credits
            .filter { $0.isAvailable }
            .map(\.expiresAt)

        return UsageObservation(
            sampledAt: timestamp,
            planType: usage.planType,
            availableResetCredits: availableResetCount,
            windows: observations,
            upcomingCreditExpiries: expiries
        )
    }

    private var canSendNotifications: Bool {
        guard smartAlertsEnabled else {
            return false
        }
        let status = notificationAuthStatus
        return status == .authorized || status == .provisional || status == .ephemeral
    }

    private func refreshNotificationStatus() async {
        notificationAuthStatus = await notificationService.currentAuthorizationStatus()
    }

    private func evaluateAndSendSmartAlerts(
        previousObservation: UsageObservation?,
        currentObservation: UsageObservation,
        now: Date
    ) async {
        guard canSendNotifications else {
            return
        }

        let preferences = alertPreferences()
        guard preferences.enabled else {
            return
        }

        let forecasts = runwayPredictions
        let currentWindows = Dictionary(uniqueKeysWithValues: currentObservation.windows.map { ($0.kind, $0) })
        var updatedLedger = historyStore.payload.alertLedger
        var didMutateLedger = false

        if preferences.capacityThresholdsEnabled {
            didMutateLedger = await evaluateThresholds(
                forecasts: forecasts,
                windows: currentWindows,
                now: now,
                updatedLedger: &updatedLedger
            ) || didMutateLedger
        }

        if preferences.projectedRunoutEnabled {
            didMutateLedger = await evaluateProjectedRunout(
                forecasts: forecasts,
                windows: currentWindows,
                now: now,
                updatedLedger: &updatedLedger
            ) || didMutateLedger
        }

        if preferences.creditsExpireSoonEnabled {
            didMutateLedger = await evaluateCreditExpiry(
                credits: credits,
                now: now,
                updatedLedger: &updatedLedger
            ) || didMutateLedger
        }

        if preferences.resetCreditReturnedEnabled {
            didMutateLedger = await evaluateCreditReturn(
                previousObservation: previousObservation,
                currentObservation: currentObservation,
                updatedLedger: &updatedLedger
            ) || didMutateLedger
        }

        if didMutateLedger {
            historyStore.updateLedger { ledger in
                ledger = updatedLedger
            }
        }
    }

    private func windowCycleKey(for observation: UsageWindowObservation, now: Date) -> String {
        if let resetAt = observation.resetAt {
            let minute = Int(resetAt.timeIntervalSince1970 / 60)
            return "\(observation.kind.rawValue)|\(minute)"
        }

        let windowSeconds = TimeInterval(max(60, observation.resetAfterSeconds))
        let bucket = now.timeIntervalSince1970 - (now.timeIntervalSince1970.truncatingRemainder(dividingBy: windowSeconds))
        return "\(observation.kind.rawValue)|\(Int(bucket / 60))"
    }

    private func evaluateThresholds(
        forecasts: [UsageWindowForecast],
        windows: [UsageWindowKind: UsageWindowObservation],
        now: Date,
        updatedLedger: inout SmartAlertLedger
    ) async -> Bool {
        let enabledThresholds = alertPreferences().enabledPercentages().sorted()
        guard !enabledThresholds.isEmpty else {
            return false
        }

        var shouldPersist = false

        for forecast in forecasts {
            guard let observation = windows[forecast.kind] else {
                continue
            }

            let cycleKey = "\(windowCycleKey(for: observation, now: now))"
            let stateKey = "threshold:\(cycleKey)"
            let alreadyNotified = updatedLedger.thresholdStateByWindow[stateKey] ?? 101

            for threshold in enabledThresholds.reversed() {
                if forecast.remainingPercent <= threshold && threshold < alreadyNotified {
                    let title = "Codex capacity below \(threshold)%"
                    await sendSafeNotification(
                        title: title,
                        body: "\(forecast.kind.title) appears below its remaining threshold. Based on observed usage pace.",
                        identifier: "cm-threshold-\(cycleKey)-\(threshold)"
                    )
                    updatedLedger.thresholdStateByWindow[stateKey] = threshold
                    shouldPersist = true
                    break
                }
            }
        }

        return shouldPersist
    }

    private func evaluateProjectedRunout(
        forecasts: [UsageWindowForecast],
        windows: [UsageWindowKind: UsageWindowObservation],
        now: Date,
        updatedLedger: inout SmartAlertLedger
    ) async -> Bool {
        var shouldPersist = false

        for forecast in forecasts {
            guard forecast.willExhaustBeforeReset else {
                continue
            }

            guard let cycleWindow = windows[forecast.kind],
                  let resetAt = forecast.resetAt else {
                continue
            }

            let cycleKey = windowCycleKey(for: cycleWindow, now: now)
            let stateKey = "runout:\(forecast.kind.rawValue)|\(cycleKey)"
            guard updatedLedger.exhaustionStateByWindow[stateKey] != true else {
                continue
            }

            if forecast.projectedExhaustionDate != nil {
                let formatter = Self.notificationTimeFormatter
                let resetText = formatter.string(from: resetAt)
                await sendSafeNotification(
                    title: "Projected to run out before reset",
                    body: "\(forecast.kind.title) is likely to deplete before \(resetText). Based on observed usage pace.",
                    identifier: "cm-runout-\(stateKey)"
                )
                updatedLedger.exhaustionStateByWindow[stateKey] = true
                shouldPersist = true
            }
        }

        return shouldPersist
    }

    private func evaluateCreditExpiry(
        credits: [RateLimitResetCredit],
        now: Date,
        updatedLedger: inout SmartAlertLedger
    ) async -> Bool {
        var shouldPersist = false
        let threshold = now.addingTimeInterval(86_400)

        for credit in credits where credit.isAvailable && credit.expiresAt <= threshold {
            let key = "expire:\(Int(credit.expiresAt.timeIntervalSince1970 / 60))"
            if updatedLedger.creditExpirySentByCredit[key] != nil {
                continue
            }

            await sendSafeNotification(
                title: "Reset credit expires soon",
                body: "A reset credit expires within 24 hours. Based on observed usage pace.",
                identifier: "cm-credit-expire-\(key)"
            )

            updatedLedger.creditExpirySentByCredit[key] = now
            shouldPersist = true
        }

        return shouldPersist
    }

    private func evaluateCreditReturn(
        previousObservation: UsageObservation?,
        currentObservation: UsageObservation,
        updatedLedger: inout SmartAlertLedger
    ) async -> Bool {
        guard let previous = previousObservation else {
            updatedLedger.lastAvailableResetCreditCount = currentObservation.availableResetCredits
            return false
        }

        let previousCount = previous.availableResetCredits
        let currentCount = currentObservation.availableResetCredits
        guard currentCount > previousCount else {
            return false
        }

        if updatedLedger.lastAvailableResetCreditCount != currentCount {
            await sendSafeNotification(
                title: "Reset capacity restored",
                body: "Reset credits are available again. Based on observed usage pace.",
                identifier: "cm-reset-credit-return-\(currentCount)-\(currentObservation.sampledAt.timeIntervalSince1970)"
            )
            updatedLedger.lastAvailableResetCreditCount = currentCount
            return true
        }

        return false
    }

    private func sendSafeNotification(title: String, body: String, identifier: String) async {
        guard canSendNotifications else {
            return
        }
        await notificationService.sendNotification(title: title, body: body, identifier: identifier)
    }

    private static let notificationTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return formatter
    }()
}

private enum DefaultsKey {
    static let tintIndex = "tintIndex"
    static let autoRefreshEnabled = "autoRefreshEnabled"
    static let refreshIntervalSeconds = "refreshIntervalSeconds"
    static let showSparkUsage = "showSparkUsage"
    static let meterStyle = "meterStyle"
    static let smartAlertsEnabled = "smartAlertsEnabled"
    static let alertThresholdsEnabled = "alertThresholdsEnabled"
    static let alert20PercentEnabled = "alert20PercentEnabled"
    static let alert10PercentEnabled = "alert10PercentEnabled"
    static let alert5PercentEnabled = "alert5PercentEnabled"
    static let alertProjectedRunoutEnabled = "alertProjectedRunoutEnabled"
    static let alertCreditsExpiringEnabled = "alertCreditsExpiringEnabled"
    static let alertResetAvailableEnabled = "alertResetAvailableEnabled"
}
