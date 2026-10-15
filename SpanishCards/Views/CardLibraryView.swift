import SwiftUI
import SwiftData

struct CardLibraryView: View {
    @Query(sort: \Card.createdAt, order: .reverse) private var cards: [Card]
    @State private var search = ""
    @State private var isAdding = false
    @State private var editing: Card?

    var body: some View {
        NavigationStack {
            List {
                if search.isEmpty {
                    ForEach(deckNames, id: \.self) { deck in
                        NavigationLink(value: deck) {
                            DeckRow(name: deck, cards: cards.filter { $0.deck == deck })
                        }
                    }
                } else {
                    CardRows(cards: searchResults, editing: $editing)
                }
            }
            .navigationTitle("Cards")
            .navigationDestination(for: String.self) { DeckDetailView(deck: $0) }
            .searchable(text: $search, prompt: "Search Spanish or English")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { isAdding = true } label: { Image(systemName: "plus") }
                        .accessibilityLabel("Add card")
                }
            }
            .sheet(isPresented: $isAdding) { CardEditorView(card: nil) }
            .sheet(item: $editing) { CardEditorView(card: $0) }
            .overlay {
                if !search.isEmpty && searchResults.isEmpty {
                    ContentUnavailableView.search(text: search)
                }
            }
        }
    }

    private var deckNames: [String] {
        Set(cards.map(\.deck)).sorted { lhs, rhs in
            if lhs == Decks.mine { return true }
            if rhs == Decks.mine { return false }
            return lhs < rhs
        }
    }

    private var searchResults: [Card] {
        cards.filter {
            $0.spanish.localizedStandardContains(search) || $0.english.localizedStandardContains(search)
        }
    }
}

struct DeckRow: View {
    let name: String
    let cards: [Card]

    var body: some View {
        let due = cards.filter { !$0.isNew && $0.dueDate <= .now }.count
        let learned = cards.filter(\.isLearned).count
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text(name).font(.headline)
                Text("\(cards.count) cards, \(learned) learned")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if due > 0 {
                Text("\(due) due")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.orange)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.orange.opacity(0.15), in: Capsule())
            }
        }
    }
}

struct DeckDetailView: View {
    let deck: String
    @Query private var cards: [Card]
    @State private var isAdding = false
    @State private var editing: Card?

    init(deck: String) {
        self.deck = deck
        _cards = Query(filter: #Predicate<Card> { $0.deck == deck }, sort: \Card.createdAt)
    }

    var body: some View {
        List {
            CardRows(cards: cards, editing: $editing)
        }
        .navigationTitle(deck)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { isAdding = true } label: { Image(systemName: "plus") }
                    .accessibilityLabel("Add card to \(deck)")
            }
        }
        .sheet(isPresented: $isAdding) { CardEditorView(card: nil, defaultDeck: deck) }
        .sheet(item: $editing) { CardEditorView(card: $0) }
        .overlay {
            if cards.isEmpty {
                ContentUnavailableView("No cards", systemImage: "rectangle.stack", description: Text("Tap + to add one."))
            }
        }
    }
}

/// Card rows with tap to edit and swipe to delete. The parent owns the edit sheet.
struct CardRows: View {
    let cards: [Card]
    @Binding var editing: Card?
    @Environment(\.modelContext) private var context

    var body: some View {
        ForEach(cards) { card in
            Button { editing = card } label: { CardRow(card: card) }
                .foregroundStyle(.primary)
        }
        .onDelete { offsets in
            for index in offsets { context.delete(cards[index]) }
            try? context.save()
        }
    }
}

struct CardRow: View {
    let card: Card

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(card.spanish).font(.body.weight(.semibold))
                Text(card.english)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            ProgressBadge(card: card)
        }
        .contentShape(Rectangle())
    }
}
