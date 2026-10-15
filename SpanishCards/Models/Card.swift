import Foundation
import SwiftData

enum Decks {
    static let mine = "My Cards"
}

@Model
final class Card {
    var uid: UUID = UUID()
    var spanish: String = ""
    var english: String = ""
    var note: String = ""
    var deck: String = "My Cards"
    var isStarter: Bool = false
    var createdAt: Date = Date.now

    var dueDate: Date = Date.now
    var intervalDays: Double = 0
    var ease: Double = 2.5
    var streak: Int = 0
    var reps: Int = 0
    var lapses: Int = 0
    var lastReviewedAt: Date?

    init(spanish: String, english: String, note: String = "", deck: String = Decks.mine, isStarter: Bool = false) {
        self.uid = UUID()
        self.spanish = spanish
        self.english = english
        self.note = note
        self.deck = deck
        self.isStarter = isStarter
        self.createdAt = .now
        self.dueDate = .now
        self.ease = ReviewScheduler.startingEase
    }

    var reviewState: ReviewState {
        get {
            ReviewState(dueDate: dueDate, intervalDays: intervalDays, ease: ease, streak: streak, reps: reps, lapses: lapses)
        }
        set {
            dueDate = newValue.dueDate
            intervalDays = newValue.intervalDays
            ease = newValue.ease
            streak = newValue.streak
            reps = newValue.reps
            lapses = newValue.lapses
        }
    }

    var isNew: Bool { reps == 0 }
    var isLearned: Bool { ReviewScheduler.isLearned(reviewState) }

    func record(correct: Bool, now: Date = .now) {
        reviewState = ReviewScheduler.review(reviewState, correct: correct, now: now)
        lastReviewedAt = now
    }

    func resetProgress() {
        reviewState = .new()
        lastReviewedAt = nil
    }
}
