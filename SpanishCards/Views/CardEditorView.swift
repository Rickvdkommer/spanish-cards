import SwiftUI
import SwiftData

/// Add a new card (stays open so you can add a bunch in a row) or edit an existing one.
struct CardEditorView: View {
    private static let newDeckTag = "__new_deck__"
    private static let accents = ["á", "é", "í", "ó", "ú", "ñ", "ü", "¿", "¡"]

    let card: Card?

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query private var allCards: [Card]

    @State private var spanish: String
    @State private var english: String
    @State private var note: String
    @State private var deck: String
    @State private var newDeckName = ""
    @State private var addedCount = 0
    @FocusState private var focus: Field?

    private enum Field { case spanish, english, note, deckName }

    init(card: Card?, defaultDeck: String = Decks.mine) {
        self.card = card
        _spanish = State(initialValue: card?.spanish ?? "")
        _english = State(initialValue: card?.english ?? "")
        _note = State(initialValue: card?.note ?? "")
        _deck = State(initialValue: card?.deck ?? defaultDeck)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Spanish") {
                    TextField("¿Dónde está el baño?", text: $spanish, axis: .vertical)
                        .focused($focus, equals: .spanish)
                }
                Section("English") {
                    TextField("Where is the bathroom?", text: $english, axis: .vertical)
                        .focused($focus, equals: .english)
                }
                Section("Note (optional)") {
                    TextField("Grammar tip, context, memory trick", text: $note, axis: .vertical)
                        .focused($focus, equals: .note)
                }
                Section("Deck") {
                    Picker("Deck", selection: $deck) {
                        ForEach(deckOptions, id: \.self) { Text($0).tag($0) }
                        Text("New deck…").tag(Self.newDeckTag)
                    }
                    if deck == Self.newDeckTag {
                        TextField("Deck name", text: $newDeckName)
                            .focused($focus, equals: .deckName)
                    }
                }
                if let card {
                    Section {
                        Button("Reset progress", role: .destructive) {
                            card.resetProgress()
                            try? context.save()
                        }
                    } footer: {
                        Text("Seen \(card.reps) times, missed \(card.lapses). Next up \(card.dueDate.formatted(.relative(presentation: .named))).")
                    }
                }
                if addedCount > 0 {
                    Section {
                        Label("\(addedCount) added. Keep going or tap Done.", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    }
                }
            }
            .navigationTitle(card == nil ? "New card" : "Edit card")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(card == nil && addedCount > 0 ? "Done" : "Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(card == nil ? "Add" : "Save", action: save)
                        .disabled(!canSave)
                }
                ToolbarItemGroup(placement: .keyboard) {
                    ForEach(Self.accents, id: \.self) { letter in
                        Button(letter) { insert(letter) }
                    }
                }
            }
            .onAppear {
                if card == nil { focus = .spanish }
            }
        }
    }

    private var deckOptions: [String] {
        var names = Set(allCards.map(\.deck))
        names.insert(Decks.mine)
        if deck != Self.newDeckTag { names.insert(deck) }
        return names.sorted { lhs, rhs in
            if lhs == Decks.mine { return true }
            if rhs == Decks.mine { return false }
            return lhs < rhs
        }
    }

    private var resolvedDeck: String {
        deck == Self.newDeckTag ? newDeckName.trimmingCharacters(in: .whitespacesAndNewlines) : deck
    }

    private var canSave: Bool {
        !spanish.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !english.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !resolvedDeck.isEmpty
    }

    private func insert(_ letter: String) {
        switch focus {
        case .english: english += letter
        case .note: note += letter
        case .deckName: newDeckName += letter
        case .spanish, .none: spanish += letter
        }
    }

    private func save() {
        let es = spanish.trimmingCharacters(in: .whitespacesAndNewlines)
        let en = english.trimmingCharacters(in: .whitespacesAndNewlines)
        let tip = note.trimmingCharacters(in: .whitespacesAndNewlines)
        let deckName = resolvedDeck

        if let card {
            card.spanish = es
            card.english = en
            card.note = tip
            card.deck = deckName
            try? context.save()
            dismiss()
        } else {
            context.insert(Card(spanish: es, english: en, note: tip, deck: deckName))
            try? context.save()
            addedCount += 1
            spanish = ""
            english = ""
            note = ""
            deck = deckName
            newDeckName = ""
            focus = .spanish
        }
    }
}
