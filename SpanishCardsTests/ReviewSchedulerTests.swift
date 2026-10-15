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
