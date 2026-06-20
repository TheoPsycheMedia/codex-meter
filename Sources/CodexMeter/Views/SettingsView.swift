import SwiftUI

struct SettingsView: View {
    @ObservedObject var store: WidgetStore
    @ObservedObject var launchAtLoginService: LaunchAtLoginService

    private let refreshChoices: [TimeInterval] = [30, 60, 120, 300]

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Codex Meter")
                    .font(.system(size: 24, weight: .semibold, design: .rounded))
                    .foregroundStyle(.primary)

                Text("Menu-bar usage and reset-credit monitor")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
            }

            Divider()

            Toggle("Auto refresh while running", isOn: $store.autoRefreshEnabled)

            HStack {
                Text("Refresh every")
                    .foregroundStyle(.primary)

                Spacer()

                Picker("Refresh interval", selection: $store.refreshIntervalSeconds) {
                    ForEach(refreshChoices, id: \.self) { seconds in
                        Text(intervalTitle(seconds))
                            .tag(seconds)
                    }
                }
                .labelsHidden()
                .frame(width: 128)
            }

            Toggle("Show Codex-Spark meter", isOn: $store.showSparkUsage)

            HStack {
                Text("Meter style")
                    .foregroundStyle(.primary)

                Spacer()

                Picker("Meter style", selection: $store.meterStyle) {
                    ForEach(MeterStyle.allCases) { style in
                        Text(style.title)
                            .tag(style)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(width: 210)
            }

            HStack {
                Text("Menu-bar display")
                    .foregroundStyle(.primary)

                Spacer()

                Picker("Menu-bar display", selection: $store.statusItemDisplayMode) {
                    ForEach(StatusItemDisplayMode.allCases) { mode in
                        Text("\(mode.title) (\(statusItemPreview(for: mode)))")
                            .tag(mode)
                    }
                }
                .labelsHidden()
                .frame(width: 248)
            }

            Text("Preview: \(statusItemPreview(for: store.statusItemDisplayMode))")
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)

            Toggle(
                "Launch Codex Meter at Login",
                isOn: Binding(
                    get: { store.launchAtLoginEnabled },
                    set: { enabled in
                        Task {
                            let applied = await launchAtLoginService.applyLaunchPreference(enabled)
                            store.launchAtLoginEnabled = applied
                        }
                    }
                )
            )
            .disabled(launchAtLoginService.isBusy)

            if launchAtLoginService.isBusy {
                HStack(spacing: 6) {
                    ProgressView()
                        .controlSize(.small)

                    Text("Updating launch-at-login setting")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                }
            } else {
                Text("Launch-at-login status: \(launchAtLoginService.displaySummary)")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
            }

            if launchAtLoginService.requiresApproval {
                Button {
                    launchAtLoginService.openLoginItemsSettings()
                } label: {
                    Text("Open Login Items...")
                }
            }

            if let message = launchAtLoginService.lastErrorMessage {
                Text(message)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(.red)
            }

            Divider()

            HStack {
                Button {
                    Task {
                        await store.refresh()
                    }
                } label: {
                    Label("Refresh Now", systemImage: "arrow.clockwise")
                }

                Spacer()

                Text(lastUpdatedText)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(22)
        .frame(width: 420, height: 455)
        .background(.regularMaterial)
        .onAppear {
            launchAtLoginService.refresh()
        }
    }

    private var lastUpdatedText: String {
        guard let lastUpdated = store.lastUpdated else {
            return "Not updated yet"
        }

        return "Updated \(Self.timeFormatter.string(from: lastUpdated))"
    }

    private func statusItemPreview(for mode: StatusItemDisplayMode) -> String {
        StatusItemSnapshot(
            usage: store.usage,
            showSparkUsage: store.showSparkUsage,
            mode: mode,
            isLoading: store.isLoading,
            errorMessage: store.errorMessage,
            lastUpdated: store.lastUpdated
        )
        .previewText(for: mode)
    }

    private func intervalTitle(_ seconds: TimeInterval) -> String {
        if seconds < 60 {
            return "\(Int(seconds)) seconds"
        }

        let minutes = Int(seconds / 60)
        return minutes == 1 ? "1 minute" : "\(minutes) minutes"
    }

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return formatter
    }()
}
