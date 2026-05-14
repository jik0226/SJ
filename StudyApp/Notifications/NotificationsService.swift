// NotificationsService — thin wrapper over UNUserNotificationCenter.
// Permission opt-in; all post calls are no-ops until authorization is granted.

import Foundation
import UserNotifications

@MainActor
enum NotificationsService {
    private static let center = UNUserNotificationCenter.current()

    static func requestAuthorizationIfNeeded() async {
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .notDetermined else { return }
        _ = try? await center.requestAuthorization(options: [.alert, .sound, .badge])
    }

    static func postDailyGoalAchieved(subjectName: String) {
        post(
            id: "goal.\(subjectName)",
            title: "오늘 목표 달성! 🎯",
            body: "\(subjectName) 목표 시간을 채웠어요. 식물에 영양분이 쌓이고 있어요 🌱"
        )
    }

    static func postWeeklyStreak() {
        post(
            id: "streak.weekly",
            title: "7일 연속 달성! 🔥",
            body: "보너스 영양분이 식물에 더해졌어요"
        )
    }

    /// Schedules a single repeating daily reminder at 21:00 local time.
    /// Idempotent: re-registering with the same identifier replaces the
    /// previous request.
    static func scheduleDailyReminder() {
        let content = UNMutableNotificationContent()
        content.title = "오늘 학습 어땠어요?"
        content.body = "잠들기 전 마스코트와 오늘 진도를 확인해보세요."
        content.sound = .default

        var components = DateComponents()
        components.hour = 21
        components.minute = 0

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        let request = UNNotificationRequest(
            identifier: "reminder.daily.21",
            content: content,
            trigger: trigger
        )
        center.add(request)
    }

    static func cancelDailyReminder() {
        center.removePendingNotificationRequests(withIdentifiers: ["reminder.daily.21"])
    }

    static func postGroupChatReceived(groupName: String, senderLabel: String) {
        post(
            id: "chat.\(UUID().uuidString)",
            title: groupName,
            body: "\(senderLabel) 님: 새 메시지"
        )
    }

    private static func post(id: String, title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        let request = UNNotificationRequest(
            identifier: id,
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 0.5, repeats: false)
        )
        center.add(request)
    }
}
