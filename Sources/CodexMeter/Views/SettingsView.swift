import SwiftUI

struct SettingsView: View {
    @ObservedObject var store: WidgetStore
    @ObservedObject var launchAtLoginService: LaunchAtLoginService

    private let refreshChoices: [TimeInterval] = [30, 60, 120, 300]

    var body: some View {
        ScrollView {
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

                VStack(alignment: .leading, spacing: 10) {
                    Text("Smart Alerts")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(.primary)

                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 8) {
                            Image(systemName: notificationIcon)
                                .foregroundStyle(notificationIconColor)
                            Text(store.notificationAuthStatus.label)
                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                                .foregroundStyle(.secondary)
                        }

                        if store.notificationAuthStatus == .notDetermined {
                            Button("Enable Local Alerts") {
                                Task {
                                    await store.requestNotificationPermission()
                                }
                            }
                            .buttonStyle(WidgetButtonStyle())
                            .frame(maxWidth: .infinity, minHeight: 34)
                        } else if store.notificationAuthStatus == .denied {
                            Text("Mac notifications are blocked. Open System Settings > Notifications to allow Codex Meter.")
                                .font(.system(size: 11, weight: .medium, design: .rounded))
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        } else if !store.canSendTestNotification {
                            Text("Your notifications are in quiet mode. Alerts still arrive in Notification Center.")
                                .font(.system(size: 11, weight: .medium, design: .rounded))
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        Text("Mac notifications only. No account or analytics.")
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundStyle(.secondary)
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Toggle("Enable smart alerts", isOn: $store.smartAlertsEnabled)
                            .disabled(store.notificationAuthStatus != .authorized && store.notificationAuthStatus != .provisional && store.notificationAuthStatus != .ephemeral)

                        Toggle("Low capacity thresholds", isOn: $store.alertThresholdsEnabled)
                            .disabled(!store.smartAlertsEnabled)

                        if store.alertThresholdsEnabled && store.smartAlertsEnabled {
                            HStack(alignment: .center, spacing: 6) {
                                Text("Thresholds")
                                    .font(.system(size: 12, weight: .medium, design: .rounded))
                                    .foregroundStyle(.secondary)
                                Spacer()
                            }
                            VStack(alignment: .leading, spacing: 6) {
                                Toggle("Warn below 20%", isOn: $store.alert20PercentEnabled)
                                    .disabled(!store.smartAlertsEnabled)
                                Toggle("Warn below 10%", isOn: $store.alert10PercentEnabled)
                                    .disabled(!store.smartAlertsEnabled)
                                Toggle("Warn below 5%", isOn: $store.alert5PercentEnabled)
                                    .disabled(!store.smartAlertsEnabled)
                            }
                            .padding(.leading, 10)
                        }

                        Toggle("Projected to run out before reset", isOn: $store.alertProjectedRunoutEnabled)
                            .disabled(!store.smartAlertsEnabled)
                        Toggle("Reset credit expires within 24h", isOn: $store.alertCreditsExpiringEnabled)
                            .disabled(!store.smartAlertsEnabled)
                        Toggle("Capacity reset available again", isOn: $store.alertResetAvailableEnabled)
                            .disabled(!store.smartAlertsEnabled)
                    }

                    Button("Send Test Notification") {
                        Task {
                            await store.sendTestNotification()
                        }
                    }
                    .buttonStyle(WidgetButtonStyle())
                    .frame(maxWidth: .infinity, minHeight: 34)
                    .disabled(!store.smartAlertsEnabled || !store.canSendTestNotification)
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

                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Image(systemName: store.hasRunwayHistory ? "clock.arrow.trianglehead.counterclockwise" : "clock")
                            .foregroundStyle(.secondary)
                        Text("Runway prediction")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundStyle(.primary)
                    }

                    Text(runwayStateDescription)
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                }

                Divider()

                VStack(alignment: .leading, spacing: 8) {
                    EndpointSettingsRow(title: "Usage", state: store.usageRefreshState)
                    EndpointSettingsRow(title: "Reset Bank", state: store.resetCreditRefreshState)
                }

                HStack {
                    Button {
                        store.copyDiagnostics()
                    } label: {
                        Label(store.diagnosticsCopyMessage ?? "Copy Diagnostics", systemImage: "doc.on.doc")
                    }

                    Spacer()
                }
            }
            .padding(22)
        }
        .frame(width: 430)
        .onAppear {
            launchAtLoginService.refresh()
            Task {
                await store.refreshNotificationStatus()
            }
        }
    }

    private var runwayStateDescription: String {
        if store.hasRunwayHistory {
            return "History is stored locally in Application Support and used for runway estimates."
        } else {
            return "Runway needs a few refreshes before predictions appear. History is stored locally on this Mac."
        }
    }

    private var notificationIcon: String {
        switch store.notificationAuthStatus {
        case .authorized:
            return "checkmark.seal.fill"
        case .provisional:
            return "bell.badge.fill"
        case .ephemeral:
            return "checkmark.shield.fill"
        case .denied:
            return "xmark.octagon.fill"
        case .notDetermined:
            return "bell.badge"
        }
    }

    private var notificationIconColor: Color {
        switch store.notificationAuthStatus {
        case .authorized:
            return .green
        case .provisional:
            return .yellow
        case .ephemeral:
            return .blue
        case .denied, .notDetermined:
            return .orange
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
            errorMessage: store.primaryFailure?.message,
            lastUpdated: store.lastUpdated,
            staleAfterSeconds: store.statusItemStaleAfterSeconds
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

private struct EndpointSettingsRow: View {
    let title: String
    let state: EndpointRefreshState

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: state.systemName)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 16)

            Text(title)
                .font(.system(size: 12, weight: .semibold, design: .rounded))

            Spacer()

            Text(state.title)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(.thinMaterial)
        }
    }

    private var tint: Color {
        switch state.tone {
        case .neutral:
            return .secondary
        case .progress, .live:
            return Color(red: 0.25, green: 0.76, blue: 0.91)
        case .warning:
            return Color(red: 0.96, green: 0.68, blue: 0.22)
        case .error:
            return Color(red: 0.96, green: 0.28, blue: 0.24)
        }
    }
}
