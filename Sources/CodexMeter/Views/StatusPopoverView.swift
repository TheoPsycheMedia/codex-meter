import SwiftUI

struct StatusPopoverView: View {
    @ObservedObject var store: WidgetStore
    let widgetButtonTitle: String
    let onRefresh: () -> Void
    let onToggleWidget: () -> Void
    let onSettings: () -> Void

    private var snapshot: StatusItemSnapshot {
        StatusItemSnapshot(
            usage: store.usage,
            showSparkUsage: store.showSparkUsage,
            mode: store.statusItemDisplayMode,
            isLoading: store.isLoading,
            errorMessage: store.primaryFailure?.message,
            lastUpdated: store.lastUpdated,
            staleAfterSeconds: store.statusItemStaleAfterSeconds
        )
    }

    private var lowestWindow: StatusItemUsageWindow? {
        snapshot.windows.min { lhs, rhs in
            if lhs.percent != rhs.percent {
                return lhs.percent < rhs.percent
            }

            if lhs.resetAfterSeconds != rhs.resetAfterSeconds {
                return lhs.resetAfterSeconds < rhs.resetAfterSeconds
            }

            return lhs.id < rhs.id
        }
    }

    var body: some View {
        VStack(spacing: -1) {
            PopoverArrow()
                .fill(.regularMaterial)
                .frame(width: 18, height: 10)
                .overlay {
                    PopoverArrow()
                        .stroke(.primary.opacity(0.08), lineWidth: 1)
                }

            card
        }
        .frame(width: 318)
    }

    private var card: some View {
        VStack(alignment: .leading, spacing: 10) {
            PopoverReadinessRow(advice: store.sessionReadinessAdvice)

            PopoverMetricBand(
                lowest: lowestWindow.map { "\($0.shortMenuLabel) \($0.percent)%" } ?? "--",
                resetCredits: store.availableCount.map(String.init) ?? "--",
                nextReset: lowestWindow?.remainingText ?? "--"
            )

            windowBreakdown

            HStack(spacing: 8) {
                PopoverActionButton(title: L10n.text("action.refreshNow"), systemName: store.isLoading ? "hourglass" : "arrow.clockwise", action: onRefresh)
                PopoverActionButton(title: widgetButtonTitle, systemName: "rectangle.on.rectangle", action: onToggleWidget)
                PopoverIconActionButton(systemName: "gearshape", help: L10n.text("menu.settings"), action: onSettings)
            }
        }
        .padding(12)
        .frame(width: 318)
        .background {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(.regularMaterial)
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(.primary.opacity(0.08), lineWidth: 1)
                }
        }
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    @ViewBuilder
    private var windowBreakdown: some View {
        if snapshot.windows.isEmpty {
            Text(snapshot.errorMessage ?? L10n.text("statusItem.menu.noUsageData"))
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, minHeight: 42, alignment: .leading)
        } else {
            VStack(alignment: .leading, spacing: 8) {
                Text(L10n.text("statusPopover.windows"))
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)

                ForEach(snapshot.windows.prefix(4)) { window in
                    PopoverUsageWindowRow(window: window)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 9)
            .background {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(.primary.opacity(0.035))
            }
        }
    }
}

private struct PopoverArrow: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

private struct PopoverReadinessRow: View {
    let advice: SessionReadinessAdvice

    var body: some View {
        HStack(alignment: .top, spacing: 9) {
            Image(systemName: advice.systemName)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(advice.readinessTint)
                .frame(width: 22, height: 22)
                .background {
                    Circle()
                        .fill(advice.readinessTint.opacity(0.12))
                }

            VStack(alignment: .leading, spacing: 1) {
                Text(advice.title)
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)

                Text(advice.headline)
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(advice.readinessTint)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)

                Text(advice.detail)
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.82)
            }

            Spacer(minLength: 4)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, minHeight: 58, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(advice.readinessTint.opacity(0.055))
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(advice.readinessTint.opacity(0.10), lineWidth: 1)
                }
        }
        .accessibilityElement(children: .combine)
    }
}

private struct PopoverMetricBand: View {
    let lowest: String
    let resetCredits: String
    let nextReset: String

    var body: some View {
        HStack(spacing: 0) {
            PopoverMetricItem(title: L10n.text("statusPopover.lowest"), value: lowest)
            Divider().frame(height: 30)
            PopoverMetricItem(title: L10n.text("endpoint.resetCredits.title"), value: resetCredits)
            Divider().frame(height: 30)
            PopoverMetricItem(title: L10n.text("statusPopover.nextReset"), value: nextReset)
        }
        .padding(.vertical, 8)
        .background {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(.primary.opacity(0.035))
        }
    }
}

private struct PopoverMetricItem: View {
    let title: String
    let value: String

    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.68)

            Text(title)
                .font(.system(size: 9, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .frame(maxWidth: .infinity, minHeight: 38)
    }
}

private struct PopoverUsageWindowRow: View {
    let window: StatusItemUsageWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(window.menuLabelPrefix)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)

                Spacer(minLength: 8)

                Text("\(window.percent)%")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(percentTint)

                Text(window.remainingText)
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule(style: .continuous)
                        .fill(.primary.opacity(0.08))

                    Capsule(style: .continuous)
                        .fill(percentTint)
                        .frame(width: max(5, proxy.size.width * CGFloat(max(0, min(100, window.percent))) / 100))
                }
            }
            .frame(height: 4)
        }
    }

    private var percentTint: Color {
        switch window.percent {
        case 50...100:
            return Color(red: 0.25, green: 0.78, blue: 0.45)
        case 20..<50:
            return Color(red: 0.96, green: 0.68, blue: 0.22)
        default:
            return Color(red: 0.96, green: 0.28, blue: 0.24)
        }
    }
}

private struct PopoverActionButton: View {
    let title: String
    let systemName: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: systemName)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .frame(maxWidth: .infinity, minHeight: 30)
        }
        .buttonStyle(PopoverButtonStyle())
    }
}

private struct PopoverIconActionButton: View {
    let systemName: String
    let help: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 12, weight: .semibold))
                .frame(width: 32, height: 30)
        }
        .buttonStyle(PopoverButtonStyle())
        .help(help)
        .accessibilityLabel(help)
    }
}

private struct PopoverButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(.primary)
            .background {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(.primary.opacity(configuration.isPressed ? 0.11 : 0.065))
            }
    }
}
