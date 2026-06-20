import Foundation
import UserNotifications

@MainActor
enum NotificationAuthorizationStatus: String, Codable {
    case notDetermined
    case denied
    case ephemeral
    case provisional
    case authorized
}

extension NotificationAuthorizationStatus {
    var label: String {
        switch self {
        case .notDetermined:
            return "Notifications not requested"
        case .denied:
            return "Notifications blocked"
        case .ephemeral:
            return "Private / ephemeral notifications"
        case .provisional:
            return "Quiet delivery"
        case .authorized:
            return "Notifications enabled"
        }
    }
}

@MainActor
final class SmartNotificationService {
    private let center = UNUserNotificationCenter.current()

    func requestPermission() async -> Bool {
        let granted = try? await center.requestAuthorization(options: [.alert, .badge, .sound])
        return granted == true
    }

    func currentAuthorizationStatus() async -> NotificationAuthorizationStatus {
        await withCheckedContinuation { continuation in
            center.getNotificationSettings { settings in
                let status: NotificationAuthorizationStatus
                switch settings.authorizationStatus {
                case .notDetermined:
                    status = .notDetermined
                case .denied:
                    status = .denied
                case .ephemeral:
                    status = .ephemeral
                case .provisional:
                    status = .provisional
                case .authorized:
                    status = .authorized
                @unknown default:
                    status = .notDetermined
                }

                continuation.resume(returning: status)
            }
        }
    }

    func sendNotification(
        title: String,
        body: String,
        identifier: String
    ) async {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: nil
        )

        do {
            try await center.add(request)
        } catch {
            // Notification delivery is best-effort; keep polling resilient.
        }
    }
}
