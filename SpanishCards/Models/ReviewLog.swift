import Foundation
import SwiftData

/// One swipe. Powers the Profile tab (streak, accuracy, activity chart).
@Model
final class ReviewLog {
    var uid: UUID = UUID()
    var cardUID: UUID = UUID()
    var date: Date = Date.now
    var correct: Bool = false

    init(cardUID: UUID, correct: Bool, date: Date = .now) {
        self.uid = UUID()
        self.cardUID = cardUID
        self.correct = correct
        self.date = date
    }
}
