import SwiftUI
import SwiftData

struct StudyView: View {
    static let allDecks = "All decks"

    @Environment(\.modelContext) private var context
    @Query(sort: \Card.createdAt) private var cards: [Card]
    /// `Int.max` means no limit: every new card in the deck goes into the session.
    @AppStorage("newCardsLimit") private var newPerSession = Int.max
    @AppStorage("englishFirst") private var englishFirst = true
    @AppStorage("studyDeck") private var selectedDeck = StudyView.allDecks

    @State private var session: StudySession?

    var body: some View {
        NavigationStack {
            content
                .padding()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(.systemGroupedBackground))
                .navigationTitle("Study")
                .toolbar {
                    if let session {
                        ToolbarItem(placement: .topBarLeading) {
                            Button(action: undo) {
                                Image(systemName: "arrow.uturn.backward.circle")
                            }
                            .disabled(!session.canUndo)
                            .accessibilityLabel("Back to the last card")
                        }
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("End") { self.session = nil }
                        }
                    }
                }
        }
    }

    @ViewBuilder
    private var content: some View {
        if let session {
            if let id = session.current, let card = card(withID: id) {
                SwipeDeckView(card: card, englishFirst: englishFirst, remaining: session.remaining) { correct in
                    answer(card, correct: correct)
                }
                // Fresh swipe state for every answer, even when the same card comes straight back.
                .id(session.reviewed)
            } else {
                SessionSummaryView(reviewed: session.reviewed, correct: session.correct) {
                    self.session = nil
                }
            }
        } else {
            startScreen
        }
    }

    // MARK: Start screen

    private var startScreen: some View {
        VStack(spacing: 20) {
            HStack(spacing: 12) {
                StatTile(value: dueCards.count, label: "Due", tint: .orange)
                StatTile(value: min(newCards.count, newPerSession), label: "New", tint: .blue)
                StatTile(value: deckCards.filter(\.isLearned).count, label: "Learned", tint: .green)
            }

            VStack(spacing: 0) {
                HStack {
                    Text("Deck")
                    Spacer()
                    Picker("Deck", selection: $selectedDeck) {
                        Text(Self.allDecks).tag(Self.allDecks)
                        ForEach(deckNames, id: \.self) { Text($0).tag($0) }
                    }
                    .pickerStyle(.menu)
                }
                .padding(.vertical, 6)
                Divider()
                Toggle("Show English first", isOn: $englishFirst)
                    .padding(.vertical, 10)
                Divider()
                HStack {
                    Text("New cards per session")
                    Spacer()
                    Picker("New cards per session", selection: $newPerSession) {
                        ForEach([10, 20, 50, 100], id: \.self) { Text("\($0)").tag($0) }
                        Text("All").tag(Int.max)
                        Text("None").tag(0)
                    }
                    .pickerStyle(.menu)
                }
                .padding(.vertical, 6)
            }
            .padding(.horizontal)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))

            Spacer()

            if deckCards.isEmpty {
                Text("No cards here yet. Add some in the Cards tab.")
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            } else {
                if scheduledCards.isEmpty {
                    Text("Nothing due right now. ¡Muy bien! You can still do some extra practice.")
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                Button(action: startSession) {
                    Text(scheduledCards.isEmpty ? "Extra practice" : "Start (\(scheduledCards.count) cards)")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
        }
    }

    // MARK: Picking cards

    private var deckNames: [String] {
        Set(cards.map(\.deck)).sorted { lhs, rhs in
            if lhs == Decks.mine { return true }
            if rhs == Decks.mine { return false }
            return lhs < rhs
        }
    }

    private var deckCards: [Card] {
        selectedDeck == Self.allDecks ? cards : cards.filter { $0.deck == selectedDeck }
    }

    private var dueCards: [Card] {
        let now = Date.now
        return deckCards
            .filter { !$0.isNew && $0.dueDate <= now }
            .sorted { $0.dueDate < $1.dueDate }
    }

    /// New cards, your own before the starter decks.
    private var newCards: [Card] {
        deckCards
            .filter(\.isNew)
            .sorted { ($0.isStarter ? 1 : 0, $0.createdAt) < ($1.isStarter ? 1 : 0, $1.createdAt) }
    }

    private var scheduledCards: [Card] {
        dueCards + Array(newCards.prefix(newPerSession))
    }

    private func card(withID id: UUID) -> Card? {
        cards.first { $0.uid == id }
    }

    private func startSession() {
        var picked = scheduledCards
        var isPractice = false
        if picked.isEmpty {
            picked = Array(deckCards.sorted { $0.dueDate < $1.dueDate }.prefix(20))
            isPractice = true
        }
        session = StudySession(cardIDs: picked.shuffled().map(\.uid), isPractice: isPractice)
    }

    private func answer(_ card: Card, correct: Bool) {
        guard var current = session else { return }
        let previousState = card.reviewState
        let previousReviewedAt = card.lastReviewedAt
        // In extra practice a right answer doesn't push the card further out, a wrong one still counts.
        let counts = !(current.isPractice && correct)
        if counts {
            card.record(correct: correct)
        }
        let log = ReviewLog(cardUID: card.uid, correct: correct)
        context.insert(log)
        let repeatSoon = !correct || (counts && ReviewScheduler.repeatsThisSession(card.reviewState))
        current.answer(
            correct: correct,
            repeatSoon: repeatSoon,
            previousState: counts ? previousState : nil,
            previousReviewedAt: previousReviewedAt,
            logID: log.uid
        )
        session = current
        try? context.save()
    }

    /// Back to the last card: it goes back on top and its progress is put back as it was.
    private func undo() {
        guard var current = session else { return }
        guard let restore = current.undo() else { return }
        if let previous = restore.previousState, let card = card(withID: restore.cardID) {
            card.reviewState = previous
            card.lastReviewedAt = restore.previousReviewedAt
        }
        if let logID = restore.logID {
            try? context.delete(model: ReviewLog.self, where: #Predicate<ReviewLog> { $0.uid == logID })
        }
        session = current
        try? context.save()
    }
}

struct SessionSummaryView: View {
    let reviewed: Int
    let correct: Int
    let onDone: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "party.popper.fill")
                .font(.system(size: 64))
                .foregroundStyle(.orange)
            Text("¡Muy bien!")
                .font(.largeTitle.bold())
            Text(reviewed == 0 ? "Nothing to review." : "\(correct) of \(reviewed) swipes were right.")
                .foregroundStyle(.secondary)
            Spacer()
            Button(action: onDone) {
                Text("Done")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
    }
}
