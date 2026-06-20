import AppKit
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

    @Published var statusItemDisplayMode: StatusItemDisplayMode {
        didSet { save() }
    }

    @Published var launchAtLoginEnabled: Bool {
        didSet { save() }
    }

    @Published private(set) var availableCount: Int?
    @Published private(set) var credits: [RateLimitResetCredit] = []
    @Published private(set) var usage: UsageResponse?
    @Published private(set) var isLoading = false
    @Published private(set) var lastUpdated: Date?
    @Published private(set) var usageRefreshState = EndpointRefreshState.idle(.usage)
    @Published private(set) var resetCreditRefreshState = EndpointRefreshState.idle(.resetCredits)
    @Published private(set) var lastSnapshot = WidgetSnapshot.empty
    @Published private(set) var diagnosticsCopyMessage: String?

    private let defaults: UserDefaults
    private let authReader: CodexAuthTokenReader
    private let client: RateLimitResetClient
    private let usageClient: UsageClient

    init(
        defaults: UserDefaults = .standard,
        authReader: CodexAuthTokenReader = CodexAuthTokenReader(),
        client: RateLimitResetClient = RateLimitResetClient(),
        usageClient: UsageClient = UsageClient()
    ) {
        self.defaults = defaults
        self.authReader = authReader
        self.client = client
        self.usageClient = usageClient
        self.tintIndex = defaults.object(forKey: DefaultsKey.tintIndex) as? Int ?? 0
        self.autoRefreshEnabled = defaults.object(forKey: DefaultsKey.autoRefreshEnabled) as? Bool ?? true
        self.refreshIntervalSeconds = defaults.object(forKey: DefaultsKey.refreshIntervalSeconds) as? TimeInterval ?? 60
        self.showSparkUsage = defaults.object(forKey: DefaultsKey.showSparkUsage) as? Bool ?? true
        self.meterStyle = defaults
            .string(forKey: DefaultsKey.meterStyle)
            .flatMap(MeterStyle.init(rawValue:)) ?? .circular
        self.statusItemDisplayMode = defaults
            .string(forKey: DefaultsKey.statusItemDisplayMode)
            .flatMap(StatusItemDisplayMode.init(rawValue:)) ?? .percentageOnly
        self.launchAtLoginEnabled = defaults.object(forKey: DefaultsKey.launchAtLoginEnabled) as? Bool ?? false
    }

    func cycleTint() {
        tintIndex = (tintIndex + 1) % WidgetTint.all.count
    }

    func refresh() async {
        guard !isLoading else {
            return
        }

        let startedAt = Date()
        isLoading = true
        diagnosticsCopyMessage = nil
        usageRefreshState.beginRefresh(at: startedAt, hasPriorData: usage != nil)
        resetCreditRefreshState.beginRefresh(at: startedAt, hasPriorData: hasResetCreditData)

        let token: String

        do {
            token = try authReader.accessToken()
        } catch {
            let usageFailure = Self.failure(from: error, endpoint: .usage)
            let resetFailure = Self.failure(from: error, endpoint: .resetCredits)
            usageRefreshState.recordFailure(usageFailure, hasPriorData: usage != nil)
            resetCreditRefreshState.recordFailure(resetFailure, hasPriorData: hasResetCreditData)
            isLoading = false
            return
        }

        let usageClient = usageClient
        let resetClient = client

        async let usageOutcome = Self.fetchUsageResult(using: usageClient, token: token)
        async let resetOutcome = Self.fetchCreditsResult(using: resetClient, token: token)

        let (usageResult, resetResult) = await (usageOutcome, resetOutcome)
        let finishedAt = Date()
        var didUpdateSnapshot = false
        var latestUsage: UsageResponse?
        var latestResetResponse: RateLimitResetResponse?

        switch usageResult {
        case .success(let response):
            usage = response
            latestUsage = response
            usageRefreshState.recordSuccess(at: finishedAt)
            didUpdateSnapshot = true
        case .failure(let failure):
            usageRefreshState.recordFailure(failure, hasPriorData: usage != nil)
        }

        switch resetResult {
        case .success(let response):
            latestResetResponse = response
            credits = response.credits.sorted { $0.expiresAt < $1.expiresAt }
            resetCreditRefreshState.recordSuccess(at: finishedAt, hasPriorData: true)
            didUpdateSnapshot = true
        case .failure(let failure):
            resetCreditRefreshState.recordFailure(failure, hasPriorData: hasResetCreditData)
        }

        // Take the freshest available-count from whichever endpoint succeeded.
        // A successful usage fetch can carry a newer count even when the
        // reset-credit call fails, so don't gate this on the reset response.
        if let usageCount = latestUsage?.rateLimitResetCredits?.availableCount {
            availableCount = usageCount
        } else if let latestResetResponse {
            availableCount = latestResetResponse.availableCount
        }

        if didUpdateSnapshot {
            lastUpdated = finishedAt
            lastSnapshot = WidgetSnapshot(
                usage: usage,
                availableCount: availableCount,
                credits: credits,
                capturedAt: finishedAt
            )
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
        defaults.set(statusItemDisplayMode.rawValue, forKey: DefaultsKey.statusItemDisplayMode)
        defaults.set(launchAtLoginEnabled, forKey: DefaultsKey.launchAtLoginEnabled)
    }

    var hasVisibleData: Bool {
        usage != nil || hasResetCreditData
    }

    var hasResetCreditData: Bool {
        availableCount != nil || !credits.isEmpty
    }

    var shouldShowUnavailableState: Bool {
        !hasVisibleData
            && !isLoading
            && (usageRefreshState.isUnavailable || resetCreditRefreshState.isUnavailable)
    }

    var primaryFailure: EndpointFailure? {
        let failures = [
            usageRefreshState.failure,
            resetCreditRefreshState.failure
        ].compactMap { $0 }

        return failures.first { $0.category == .missingAuth }
            ?? failures.first { $0.category == .expiredSession }
            ?? failures.first { $0.category == .schemaMismatch || $0.category == .malformedPayload }
            ?? failures.first
    }

    func copyDiagnostics() {
        let diagnostics = diagnosticsText()
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        let didCopy = pasteboard.setString(diagnostics, forType: .string)
        let message = didCopy ? "Diagnostics copied" : "Could not copy diagnostics"
        diagnosticsCopyMessage = message

        Task { @MainActor in
            try? await Task.sleep(for: .seconds(2))
            if diagnosticsCopyMessage == message {
                diagnosticsCopyMessage = nil
            }
        }
    }

    func diagnosticsText(now: Date = Date()) -> String {
        DiagnosticsBuilder.build(
            DiagnosticsInput(
                appVersion: Self.appVersion,
                macOSVersion: ProcessInfo.processInfo.operatingSystemVersionString,
                generatedAt: now,
                autoRefreshEnabled: autoRefreshEnabled,
                refreshIntervalSeconds: refreshIntervalSeconds,
                meterStyle: meterStyle,
                hasUsageData: usage != nil,
                hasResetCreditData: hasResetCreditData,
                usageState: usageRefreshState,
                resetCreditState: resetCreditRefreshState
            )
        )
    }

    private static func fetchUsageResult(
        using client: UsageClient,
        token: String
    ) async -> Result<UsageResponse, EndpointFailure> {
        do {
            return .success(try await client.fetchUsage(accessToken: token))
        } catch {
            return .failure(failure(from: error, endpoint: .usage))
        }
    }

    private static func fetchCreditsResult(
        using client: RateLimitResetClient,
        token: String
    ) async -> Result<RateLimitResetResponse, EndpointFailure> {
        do {
            return .success(try await client.fetchCredits(accessToken: token))
        } catch {
            return .failure(failure(from: error, endpoint: .resetCredits))
        }
    }

    private static func failure(from error: Error, endpoint: WidgetEndpoint) -> EndpointFailure {
        if let clientError = error as? EndpointClientError {
            return clientError.failure
        }

        if let authError = error as? CodexAuthError {
            return EndpointFailure(
                endpoint: endpoint,
                category: .missingAuth,
                message: authError.localizedDescription,
                recoverySuggestion: authError.recoverySuggestion
            )
        }

        return EndpointFailure(
            endpoint: endpoint,
            category: .unknown,
            message: error.localizedDescription,
            recoverySuggestion: (error as? LocalizedError)?.recoverySuggestion ?? "Try refreshing again."
        )
    }

    private static var appVersion: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String
        let build = info?["CFBundleVersion"] as? String

        switch (version, build) {
        case let (version?, build?) where !build.isEmpty:
            return "\(version) (\(build))"
        case let (version?, _):
            return version
        default:
            return "local"
        }
    }
}

private enum DefaultsKey {
    static let tintIndex = "tintIndex"
    static let autoRefreshEnabled = "autoRefreshEnabled"
    static let refreshIntervalSeconds = "refreshIntervalSeconds"
    static let showSparkUsage = "showSparkUsage"
    static let meterStyle = "meterStyle"
    static let statusItemDisplayMode = "statusItemDisplayMode"
    static let launchAtLoginEnabled = "launchAtLoginEnabled"
}
