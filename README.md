# spanish-cards 🇪🇸

A personal iPhone flashcard app for learning Spanish. Think Duolingo, but you feed it the words and sentences you actually run into.

## How it works
1. **Add cards** in the Cards tab: Spanish, English, an optional note, and a deck. The sheet stays open so you can add a bunch in a row, and the keyboard bar has á é í ó ú ñ ü ¿ ¡.
2. **Study**: see the card, tap to flip and reveal the translation, tap 🔊 to hear it in Spanish.
3. **Swipe right** = got it. **Swipe left** = missed it. (Or use the ✓ / ✗ buttons.)
4. **Spaced repetition** (simplified SM-2, see `ReviewScheduler.swift`):
   - Right: the card still comes back a few times (later this session, then in 1 day, then 3 days), after that the gap keeps growing.
   - Wrong: the streak resets, the card comes back 3 cards later in the same session, and its gaps grow slower from then on, so missed cards show up more often.
   - A card counts as **learned** after 3 right answers in a row.
5. **Built-in basics**: 15 starter decks, 330+ cards (greetings, numbers, days and months, time and weather, colors, pronouns, articles and gender, ser vs estar, common verbs, present tense patterns, question words, food, family, directions, survival phrases).

New cards per session (default 10), deck filter and English-first mode are on the Study screen. When nothing is due you can still do extra practice.

## Run it on your iPhone
You need a Mac with **Xcode 16 or newer**.

1. `git clone https://github.com/Rickvdkommer/spanish-cards.git` and open `SpanishCards.xcodeproj`.
2. Click the **SpanishCards** project in the sidebar, then the **SpanishCards** target, then **Signing & Capabilities**. Pick your Apple ID under **Team** (Xcode > Settings > Accounts to add one; a free account works).
3. If Xcode complains the bundle ID is taken, change `com.rickvdkommer.spanishcards` to anything unique.
4. Plug in your iPhone (or use the same Wi-Fi), select it in the device menu at the top, and hit **Run** (⌘R).
5. First time only: on the phone, turn on **Settings > Privacy & Security > Developer Mode**, and trust your developer certificate under **Settings > General > VPN & Device Management**.

With a free Apple ID the app expires after 7 days; just hit Run again. A paid developer account makes it last a year.

## Project layout
```
SpanishCards/
  SpanishCardsApp.swift      app entry + tabs, seeds starter decks on first launch
  Models/Card.swift          SwiftData model
  Models/ReviewScheduler.swift  repetition rules + study session queue (pure Swift, unit tested)
  Data/StarterDecks.swift    the built-in Spanish basics
  Data/StarterSeeder.swift   inserts starter decks (bump StarterDecks.version to ship new ones)
  Views/                     Study, swipe card, card library, add/edit card
SpanishCardsTests/           scheduler, session and starter deck tests
```
CI builds the app and runs the tests on a macOS runner for every push and PR.

## Ideas for later
- [ ] iCloud sync between devices
- [ ] Daily streak and reminder notification
- [ ] Type-the-answer mode
- [ ] Import cards from CSV
- [ ] Verb conjugation drills
