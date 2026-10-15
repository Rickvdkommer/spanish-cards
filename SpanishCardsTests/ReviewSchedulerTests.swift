import XCTest
@testable import SpanishCards

final class ReviewSchedulerTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)
    private let day: TimeInterval = 86_400

    private func answer(_ answers: [Bool]) -> ReviewState {
        answers.reduce(ReviewState.new(now: now)) { ReviewScheduler.review($0, correct: $1, now: now) }
    }

    func testRightAnswersStillRepeatAFewTimesBeforeTheGapGrows() {
        let first = answer([true])
        XCTAssertEqual(first.dueDate.timeIntervalSince(now), 10 * 60, accuracy: 1)
        XCTAssertTrue(ReviewScheduler.repeatsThisSession(first, now: now))

        let second = answer([true, true])
        XCTAssertEqual(second.dueDate.timeIntervalSince(now), day, accuracy: 1)
        XCTAssertFalse(ReviewScheduler.repeatsThisSession(second, now: now))

        let third = answer([true, true, true])
        XCTAssertEqual(third.intervalDays, 3)
        XCTAssertTrue(ReviewScheduler.isLearned(third))

        let fourth = answer([true, true, true, true])
        XCTAssertGreaterThan(fourth.intervalDays, 3 * 2.5)
    }

    func testWrongAnswerResetsStreakAndComesBackThisSession() {
        let state = answer([true, true, true, false])
        XCTAssertEqual(state.streak, 0)
        XCTAssertEqual(state.lapses, 1)
        XCTAssertFalse(ReviewScheduler.isLearned(state))
        XCTAssertTrue(ReviewScheduler.repeatsThisSession(state, now: now))
    }

    func testMissedCardsComeBackMoreOftenLater() {
        let clean = answer([true, true, true, true])
        let missedOnce = answer([false, true, true, true, true])
        XCTAssertLessThan(missedOnce.ease, clean.ease)
        XCTAssertLessThan(missedOnce.intervalDays, clean.intervalDays)
    }

    func testEaseStaysInBounds() {
        XCTAssertEqual(answer(Array(repeating: false, count: 20)).ease, ReviewScheduler.minEase, accuracy: 0.0001)
        XCTAssertEqual(answer(Array(repeating: true, count: 40)).ease, ReviewScheduler.maxEase, accuracy: 0.0001)
    }
}

final class StudySessionTests: XCTestCase {
    private let ids = (0..<6).map { _ in UUID() }

    func testWrongCardComesBackThreeCardsLater() {
        var session = StudySession(cardIDs: ids)
        session.answer(correct: false, repeatSoon: true)
        XCTAssertEqual(session.queue, [ids[1], ids[2], ids[3], ids[0], ids[4], ids[5]])
        XCTAssertEqual(session.reviewed, 1)
        XCTAssertEqual(session.correct, 0)
    }

    func testRightCardThatIsDueSoonGoesToTheBack() {
        var session = StudySession(cardIDs: ids)
        session.answer(correct: true, repeatSoon: true)
        XCTAssertEqual(session.queue.last, ids[0])
        XCTAssertEqual(session.remaining, ids.count)
    }

    func testDoneCardLeavesTheQueue() {
        var session = StudySession(cardIDs: [ids[0]])
        session.answer(correct: true, repeatSoon: false)
        XCTAssertNil(session.current)
        XCTAssertEqual(session.correct, 1)
    }

    func testLastWrongCardStaysUp() {
        var session = StudySession(cardIDs: [ids[0]])
        session.answer(correct: false, repeatSoon: true)
        XCTAssertEqual(session.current, ids[0])
    }
}

final class StarterDecksTests: XCTestCase {
    func testStarterCardsAreUniqueAndFilledIn() {
        var seen = Set<String>()
        for deck in StarterDecks.all {
            XCTAssertFalse(deck.cards.isEmpty, deck.name)
            for card in deck.cards {
                XCTAssertFalse(card.spanish.isEmpty)
                XCTAssertFalse(card.english.isEmpty)
                XCTAssertTrue(seen.insert("\(deck.name)|\(card.spanish)").inserted, "Duplicate: \(card.spanish)")
            }
        }
    }
}

final class StudySessionUndoTests: XCTestCase {
    private let ids = (0..<4).map { _ in UUID() }

    func testUndoPutsLastCardBackOnTopWithItsOldState() {
        var session = StudySession(cardIDs: ids)
        let before = ReviewState.new()
        session.answer(correct: true, repeatSoon: false, previousState: before)
        session.answer(correct: false, repeatSoon: true, previousState: before)
        XCTAssertEqual(session.reviewed, 2)

        let restore = session.undo()
        XCTAssertEqual(restore?.cardID, ids[1])
        XCTAssertEqual(restore?.previousState, before)
        XCTAssertEqual(session.queue, [ids[1], ids[2], ids[3]])
        XCTAssertEqual(session.reviewed, 1)
        XCTAssertEqual(session.correct, 1)

        XCTAssertEqual(session.undo()?.cardID, ids[0])
        XCTAssertEqual(session.queue, ids)
        XCTAssertFalse(session.canUndo)
        XCTAssertNil(session.undo())
    }

    func testUndoWorksFromTheEndOfTheSession() {
        var session = StudySession(cardIDs: [ids[0]])
        session.answer(correct: true, repeatSoon: false)
        XCTAssertNil(session.current)
        session.undo()
        XCTAssertEqual(session.current, ids[0])
    }
}

final class ProgressStatsTests: XCTestCase {
    private var calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }()
    private let now = Date(timeIntervalSince1970: 1_800_000_000) // 08:00 UTC
    private func daysAgo(_ days: Int) -> Date { now.addingTimeInterval(-Double(days) * 86_400) }

    func testStreakCountsConsecutiveDaysEndingToday() {
        let dates = [now, daysAgo(1), daysAgo(1), daysAgo(2), daysAgo(4)]
        XCTAssertEqual(ProgressStats.dayStreak(reviewDates: dates, now: now, calendar: calendar), 3)
    }

    func testStreakSurvivesUntilTodayIsOver() {
        let dates = [daysAgo(1), daysAgo(2)]
        XCTAssertEqual(ProgressStats.dayStreak(reviewDates: dates, now: now, calendar: calendar), 2)
    }

    func testStreakIsZeroAfterAMissedDay() {
        XCTAssertEqual(ProgressStats.dayStreak(reviewDates: [daysAgo(2)], now: now, calendar: calendar), 0)
        XCTAssertEqual(ProgressStats.dayStreak(reviewDates: [], now: now, calendar: calendar), 0)
    }

    func testActivityHasOneEntryPerDayOldestFirst() {
        let reviews: [(date: Date, correct: Bool)] = [(now, true), (now, false), (daysAgo(6), true), (daysAgo(9), true)]
        let week = ProgressStats.activity(lastDays: 7, reviews: reviews, now: now, calendar: calendar)
        XCTAssertEqual(week.count, 7)
        XCTAssertEqual(week.first?.correct, 1)
        XCTAssertEqual(week.last?.correct, 1)
        XCTAssertEqual(week.last?.wrong, 1)
        XCTAssertEqual(week.reduce(0) { $0 + $1.total }, 3)
    }
}

final class DailyReminderTests: XCTestCase {
    private var calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }()
    private let now = Date(timeIntervalSince1970: 1_800_000_000) // 08:00 UTC

    func testOneReminderPerDayAtThePickedTime() {
        let plans = DailyReminder.plan(now: now, hour: 19, minute: 30, reviewDueDates: [], newCards: 5, practicedToday: false, days: 7, calendar: calendar)
        XCTAssertEqual(plans.count, 7)
        let first = calendar.dateComponents([.hour, .minute], from: plans[0].fireDate)
        XCTAssertEqual(first.hour, 19)
        XCTAssertEqual(first.minute, 30)
        XCTAssertEqual(calendar.startOfDay(for: plans[0].fireDate), calendar.startOfDay(for: now))
    }

    func testTimeAlreadyPassedTodayStartsTomorrow() {
        let plans = DailyReminder.plan(now: now, hour: 7, minute: 0, reviewDueDates: [], newCards: 0, practicedToday: false, days: 3, calendar: calendar)
        XCTAssertEqual(plans.count, 2)
        XCTAssertGreaterThan(plans[0].fireDate, now)
    }

    func testCountsCardsDueByEachReminder() {
        let dueDates = [now, now.addingTimeInterval(86_400)]
        let plans = DailyReminder.plan(now: now, hour: 19, minute: 0, reviewDueDates: dueDates, newCards: 0, practicedToday: false, days: 2, calendar: calendar)
        XCTAssertEqual(plans.map(\.body), [DailyReminder.message(due: 1, newCards: 0), DailyReminder.message(due: 2, newCards: 0)])
    }

    func testSkipsTodayWhenAlreadyPracticedAndNothingDue() {
        let plans = DailyReminder.plan(now: now, hour: 19, minute: 0, reviewDueDates: [], newCards: 10, practicedToday: true, days: 3, calendar: calendar)
        XCTAssertEqual(plans.count, 2)
        XCTAssertGreaterThan(calendar.startOfDay(for: plans[0].fireDate), calendar.startOfDay(for: now))
    }
}
