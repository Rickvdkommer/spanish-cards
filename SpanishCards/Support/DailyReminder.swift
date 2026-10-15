import Foundation
import SwiftData
import UserNotifications

/// One local notification a day at the time picked on the Profile tab, saying how many cards are waiting.
/// Notifications are planned 30 days ahead and re-planned whenever the app goes to the background,
/// so the counts stay fresh.
enum DailyReminder {
    static let enabledKey = "reminderEnabled"
    static let hourKey = "reminderHour"
    static let minuteKey = "reminderMinute"
    static let defaultHour = 19
    static let daysAhead = 30

    private static let idPrefix = "daily-reminder-"

    struct Plan: Equatable {
        let fireDate: Date
        let body: String
    }

    /// What to send on each upcoming day. Today is skipped if you already practiced and nothing is due.
    static func plan(
        now: Date,
        hour: Int,
        minute: Int,
        reviewDueDates: [Date],
        newCards: Int,
        practicedToday: Bool,
        days: Int = daysAhead,
        calendar: Calendar = .current
    ) -> [Plan] {
        let today = calendar.startOfDay(for: now)
        return (0..<days).compactMap { (offset: Int) -> Plan? in
            guard let day = calendar.date(byAdding: .day, value: offset, to: today),
                  let fire = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: day),
                  fire > now
            else { return nil }
            let due = reviewDueDates.filter { $0 <= fire }.count
            if offset == 0 && practicedToday && due == 0 { return nil }
            return Plan(fireDate: fire, body: message(due: due, newCards: newCards))
        }
    }

    static func message(due: Int, newCards: Int) -> String {
        if due == 1 { return "1 card to review. Takes ten seconds, ¡vamos!" }
        if due > 1 { return "\(due) cards to review. ¡Vamos!" }
        if newCards > 0 { return "Nothing to review, so learn some new words. \(newCards) waiting for you." }
        return "Keep the streak going. Add the words you picked up today."
    }

    static func requestPermission() async -> Bool {
        (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])) ?? false
    }

    /// Replaces the pending reminders with fresh ones, or just clears them when reminders are off.
    static func refresh(context: ModelContext, defaults: UserDefaults = .standard) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: (0..<daysAhead).map { idPrefix + "\($0)" })
        guard defaults.bool(forKey: enabledKey) else { return }

        let cards = (try? context.fetch(FetchDescriptor<Card>())) ?? []
        let startOfToday = Calendar.current.startOfDay(for: .now)
        let todayCount = (try? context.fetchCount(
            FetchDescriptor<ReviewLog>(predicate: #Predicate<ReviewLog> { $0.date >= startOfToday })
        )) ?? 0

        let plans = plan(
            now: .now,
            hour: defaults.object(forKey: hourKey) as? Int ?? defaultHour,
            minute: defaults.integer(forKey: minuteKey),
            reviewDueDates: cards.filter { !$0.isNew }.map(\.dueDate),
            newCards: cards.filter(\.isNew).count,
            practicedToday: todayCount > 0
        )

        for (index, item) in plans.enumerated() {
            let content = UNMutableNotificationContent()
            content.title = "Spanish time 🇪🇸"
            content.body = item.body
            content.sound = .default
            let when = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: item.fireDate)
            let trigger = UNCalendarNotificationTrigger(dateMatching: when, repeats: false)
            center.add(UNNotificationRequest(identifier: idPrefix + "\(index)", content: content, trigger: trigger))
        }
    }
}
