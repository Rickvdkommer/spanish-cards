import Foundation

/// The spaced-repetition state of one card, kept separate from SwiftData so the rules are easy to test.
struct ReviewState: Equatable {
    var dueDate: Date
    var intervalDays: Double
    var ease: Double
    /// Correct answers in a row. A wrong answer resets it to 0.
    var streak: Int
    var reps: Int
    var lapses: Int

    static func new(now: Date = .now) -> ReviewState {
        ReviewState(dueDate: now, intervalDays: 0, ease: ReviewScheduler.startingEase, streak: 0, reps: 0, lapses: 0)
    }
}

/// Simplified SM-2.
///
/// - Right: the card still comes back a few times (10 min, 1 day, 3 days), then the gap grows by `ease`.
/// - Wrong: the streak resets, the card comes back in a minute (so again this session),
///   and its ease drops so future gaps grow slower. Cards you miss show up more often.
enum ReviewScheduler {
    static let startingEase = 2.5
    static let minEase = 1.3
    static let maxEase = 3.0
    /// Correct answers in a row before a card counts as learned.
    static let learnedStreak = 3
    /// A card due within this window is shown again in the same session.
    static let sessionWindow: TimeInterval = 20 * 60
    /// A missed card comes back this many cards later in the same session.
    static let wrongRequeueOffset = 3

    private static let minute = 1.0 / (24 * 60)

    static func review(_ state: ReviewState, correct: Bool, now: Date = .now) -> ReviewState {
        var next = state
        next.reps += 1
        if correct {
            next.streak += 1
            next.ease = min(maxEase, state.ease + 0.05)
            switch next.streak {
            case 1: next.intervalDays = 10 * minute
            case 2: next.intervalDays = 1
            case 3: next.intervalDays = 3
            default: next.intervalDays = max(state.intervalDays * next.ease, state.intervalDays + 1)
            }
        } else {
            next.streak = 0
            next.lapses += 1
            next.ease = max(minEase, state.ease - 0.2)
            next.intervalDays = minute
        }
        next.dueDate = now.addingTimeInterval(next.intervalDays * 86_400)
        return next
    }

    static func isLearned(_ state: ReviewState) -> Bool {
        state.streak >= learnedStreak
    }

    static func repeatsThisSession(_ state: ReviewState, now: Date = .now) -> Bool {
        state.dueDate.timeIntervalSince(now) <= sessionWindow
    }
}

/// The queue of cards for one study session. Missed cards are slotted back in a few cards later,
/// cards that are due again soon go to the back of the line. Every answer can be undone.
struct StudySession {
    /// What a card looked like before an answer, so undo can put it back.
    struct Undo: Equatable {
        let cardID: UUID
        let previousState: ReviewState?
        let previousReviewedAt: Date?
        let logID: UUID?
    }

    private struct Snapshot {
        let queue: [UUID]
        let reviewed: Int
        let correct: Int
        let undo: Undo
    }

    private(set) var queue: [UUID]
    private(set) var reviewed = 0
    private(set) var correct = 0
    private var history: [Snapshot] = []
    /// Extra practice when nothing is due: right answers don't push cards further out.
    let isPractice: Bool

    init(cardIDs: [UUID], isPractice: Bool = false) {
        queue = cardIDs
        self.isPractice = isPractice
    }

    var current: UUID? { queue.first }
    var remaining: Int { queue.count }
    var canUndo: Bool { !history.isEmpty }

    /// `previousState` is the card's state before this answer (nil when the answer didn't change it).
    mutating func answer(
        correct isCorrect: Bool,
        repeatSoon: Bool,
        previousState: ReviewState? = nil,
        previousReviewedAt: Date? = nil,
        logID: UUID? = nil
    ) {
        guard let id = queue.first else { return }
        history.append(Snapshot(
            queue: queue,
            reviewed: reviewed,
            correct: correct,
            undo: Undo(cardID: id, previousState: previousState, previousReviewedAt: previousReviewedAt, logID: logID)
        ))
        queue.removeFirst()
        reviewed += 1
        if isCorrect { correct += 1 }
        guard repeatSoon else { return }
        let position = isCorrect ? queue.count : min(ReviewScheduler.wrongRequeueOffset, queue.count)
        queue.insert(id, at: position)
    }

    /// Puts the last answered card back on top and returns what the card needs restored.
    @discardableResult
    mutating func undo() -> Undo? {
        guard let last = history.popLast() else { return nil }
        queue = last.queue
        reviewed = last.reviewed
        correct = last.correct
        return last.undo
    }
}
