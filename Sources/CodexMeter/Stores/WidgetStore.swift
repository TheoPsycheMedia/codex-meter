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
    @Published private(set) var errorMessage: String?
    @Published private(set) var recoveryMessage: String?

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
        defaults.set(statusItemDisplayMode.rawValue, forKey: DefaultsKey.statusItemDisplayMode)
        defaults.set(launchAtLoginEnabled, forKey: DefaultsKey.launchAtLoginEnabled)
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
