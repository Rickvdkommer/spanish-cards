import Foundation

/// Pure helpers behind the Profile tab.
enum ProgressStats {
    struct DayActivity: Identifiable, Equatable {
        let day: Date
        let correct: Int
        let wrong: Int
        var id: Date { day }
        var total: Int { correct + wrong }
    }

    /// Days in a row with at least one review, counting back from today.
    /// Nothing yet today doesn't break the streak until the day is over.
    static func dayStreak(reviewDates: [Date], now: Date = .now, calendar: Calendar = .current) -> Int {
        let days = Set(reviewDates.map { calendar.startOfDay(for: $0) })
        var day = calendar.startOfDay(for: now)
        if !days.contains(day) {
            day = calendar.date(byAdding: .day, value: -1, to: day) ?? day
        }
        var streak = 0
        while days.contains(day) {
            streak += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: day) else { break }
            day = previous
        }
        return streak
    }

    /// Right and wrong answers per day for the last `count` days, oldest first, including empty days.
    static func activity(
        lastDays count: Int,
        reviews: [(date: Date, correct: Bool)],
        now: Date = .now,
        calendar: Calendar = .current
    ) -> [DayActivity] {
        let today = calendar.startOfDay(for: now)
        var tally: [Date: (correct: Int, wrong: Int)] = [:]
        for review in reviews {
            let day = calendar.startOfDay(for: review.date)
            var entry = tally[day] ?? (0, 0)
            if review.correct { entry.correct += 1 } else { entry.wrong += 1 }
            tally[day] = entry
        }
        return (0..<count).reversed().compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: -offset, to: today) else { return nil }
            let entry = tally[day] ?? (0, 0)
            return DayActivity(day: day, correct: entry.correct, wrong: entry.wrong)
        }
    }
}
