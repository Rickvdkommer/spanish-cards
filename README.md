# spanish-cards 🇪🇸

A personal iPhone flashcard app for learning Spanish. Think Duolingo, but you feed it the words and sentences you actually run into.

## Stack
- SwiftUI (iOS 17+)
- SwiftData for local storage (iCloud sync later, maybe)

## How it works
1. **Add cards** manually: Spanish on one side, translation on the other (words or full sentences).
2. **Study deck**: see the card, tap to flip and reveal the translation.
3. **Swipe right** = got it. **Swipe left** = missed it.
4. **Spaced repetition**:
   - Right answers still come back a few times, with growing gaps, until the card is "learned".
   - Wrong answers reset the streak and come back much sooner and more often.
5. **Built-in basics**: starter decks (greetings, numbers, colors, days/months, common verbs, ser vs estar, pronouns, phrases) so there's something to study on day one.

## Roadmap
- [ ] Xcode project + SwiftData `Card` model
- [ ] Add/edit card screen
- [ ] Swipeable card stack with tap-to-flip
- [ ] Scheduling logic (SM-2 style: ease, interval, due date)
- [ ] Starter decks (bundled JSON)
- [ ] Stats: streak, due today, learned count
- [ ] Optional: text-to-speech pronunciation via AVSpeechSynthesizer
