import Foundation

final class UsageHistoryStore {
    private let fileManager: FileManager
    private let filename = "usage-history-v1.json"
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private let maxRetentionDays: TimeInterval

    private(set) var payload: UsageHistoryPayload

    init(fileManager: FileManager = .default, maxRetentionDays: TimeInterval = 14) {
        self.fileManager = fileManager
        self.maxRetentionDays = maxRetentionDays
        self.payload = UsageHistoryPayload()
        self.payload.schemaVersion = 1
        self.decoder.dateDecodingStrategy = .iso8601

        load()
    }

    func historyDirectory() throws -> URL {
        let support = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: fileManager.temporaryDirectory.path)

        return support.appendingPathComponent("CodexMeter", isDirectory: true)
    }

    func allObservations() -> [UsageObservation] {
        payload.observations
    }

    func observations(for kind: UsageWindowKind) -> [UsageWindowObservation] {
        payload.observations
            .compactMap { observation in
                observation.windows.first(where: { $0.kind == kind })
            }
            .sorted { $0.sampledAt < $1.sampledAt }
    }

    func append(_ observation: UsageObservation) {
        var sorted = payload.observations
        sorted.append(observation)
        sorted.sort { $0.sampledAt < $1.sampledAt }
        payload.observations = prune(sorted)
        save()
    }

    func updateLedger(_ block: (inout SmartAlertLedger) -> Void) {
        block(&payload.alertLedger)
        save()
    }

    func load() {
        do {
            let fileURL = try historyFileURL()
            guard fileManager.fileExists(atPath: fileURL.path) else {
                return
            }

            let data = try Data(contentsOf: fileURL)
            let decoded = try decoder.decode(UsageHistoryPayload.self, from: data)
            payload = decoded
            payload.observations = prune(payload.observations)
        } catch {
            payload = UsageHistoryPayload()
        }
    }

    func latestObservation() -> UsageObservation? {
        payload.observations.last
    }

    private func prune(_ observations: [UsageObservation]) -> [UsageObservation] {
        let cutoff = Date().addingTimeInterval(-maxRetentionDays * 86_400)
        return observations.filter { $0.sampledAt >= cutoff }
    }

    private func historyFileURL() throws -> URL {
        let directory = try historyDirectory()
        if !fileManager.fileExists(atPath: directory.path) {
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        }

        return directory.appendingPathComponent(filename)
    }

    private func save() {
        do {
            let fileURL = try historyFileURL()
            encoder.outputFormatting = .sortedKeys
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(payload)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            // Ignore write failures in local storage; app still functions with in-memory state.
        }
    }
}
