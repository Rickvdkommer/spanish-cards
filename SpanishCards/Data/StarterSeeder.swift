import Foundation
import SwiftData

/// Inserts the bundled starter decks once, and again whenever `StarterDecks.version` goes up.
/// Cards already in the store (same deck and Spanish text) are skipped, so progress is never lost.
enum StarterSeeder {
    private static let versionKey = "starterDecksVersion"

    static func seedIfNeeded(_ context: ModelContext) {
        let defaults = UserDefaults.standard
        guard defaults.integer(forKey: versionKey) < StarterDecks.version else { return }

        let existing = (try? context.fetch(FetchDescriptor<Card>(predicate: #Predicate<Card> { $0.isStarter == true }))) ?? []
        var seen = Set(existing.map { "\($0.deck)|\($0.spanish)" })

        for deck in StarterDecks.all {
            for entry in deck.cards where seen.insert("\(deck.name)|\(entry.spanish)").inserted {
                context.insert(Card(spanish: entry.spanish, english: entry.english, note: entry.note, deck: deck.name, isStarter: true))
            }
        }
        try? context.save()
        defaults.set(StarterDecks.version, forKey: versionKey)
    }
}
