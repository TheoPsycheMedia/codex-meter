import SwiftUI

struct SettingsView: View {
    @ObservedObject var store: WidgetStore

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
            }
            .padding(22)
        }
        .frame(width: 420)
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
