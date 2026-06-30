import SwiftUI

struct AmbientBackdrop: View {
    let tint: WidgetTint

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(.ultraThinMaterial)

            LinearGradient(
                colors: [
                    tint.primary.opacity(0.24),
                    Color.black.opacity(0.04),
                    tint.secondary.opacity(0.18)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Circle()
                .fill(tint.glow.opacity(0.28))
                .frame(width: 230, height: 230)
                .blur(radius: 58)
                .offset(x: -130, y: -112)

            Circle()
                .fill(tint.secondary.opacity(0.18))
                .frame(width: 190, height: 190)
                .blur(radius: 54)
                .offset(x: 150, y: 118)
        }
    }
}

struct IconButton: View {
    let systemName: String
    let help: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 13, weight: .semibold))
                .frame(width: 34, height: 34)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(.thinMaterial)
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(.white.opacity(0.16), lineWidth: 1)
                }
        }
        .foregroundStyle(.primary)
        .help(help)
    }
}

struct WidgetButtonStyle: ButtonStyle {
    var isActive = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(.primary)
            .background {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(isActive ? .regularMaterial : .thinMaterial)
                    .overlay {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .strokeBorder(.white.opacity(isActive ? 0.28 : 0.16), lineWidth: 1)
                    }
            }
            .scaleEffect(configuration.isPressed ? 0.975 : 1)
            .animation(.spring(response: 0.24, dampingFraction: 0.78), value: configuration.isPressed)
    }
}

extension SessionReadinessAdvice {
    var readinessTint: Color {
        switch level {
        case .ready:
            return Color(red: 0.25, green: 0.78, blue: 0.45)
        case .watch:
            return Color(red: 0.96, green: 0.68, blue: 0.22)
        case .save:
            return Color(red: 0.96, green: 0.28, blue: 0.24)
        case .learning, .unavailable:
            return .secondary
        }
    }
}
