import SwiftUI
import UIKit

/// One card on screen: tap to flip, swipe right if you knew it, left if you didn't.
struct SwipeDeckView: View {
    let card: Card
    let englishFirst: Bool
    let remaining: Int
    let onAnswer: (Bool) -> Void

    @State private var offset: CGSize = .zero
    @State private var isFlipped = false
    @State private var isFlyingOff = false

    private let threshold: CGFloat = 110

    var body: some View {
        VStack(spacing: 24) {
            Text(remaining == 1 ? "Last card" : "\(remaining) to go")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)

            FlashcardView(
                frontLabel: englishFirst ? "English" : "Español",
                front: englishFirst ? card.english : card.spanish,
                backLabel: englishFirst ? "Español" : "English",
                back: englishFirst ? card.spanish : card.english,
                note: card.note,
                isFlipped: isFlipped
            )
            .overlay(alignment: .top) { swipeStamp }
            .offset(x: offset.width, y: offset.height * 0.2)
            .rotationEffect(.degrees(Double(offset.width / 20)))
            .onTapGesture {
                withAnimation(.spring(duration: 0.45)) { isFlipped.toggle() }
            }
            .gesture(drag)

            HStack(spacing: 36) {
                RoundIconButton(systemImage: "xmark", tint: .red, label: "Didn't know it") { fling(correct: false) }
                RoundIconButton(systemImage: "speaker.wave.2.fill", tint: .blue, label: "Say it in Spanish", size: 52) {
                    Speech.speak(card.spanish)
                }
                RoundIconButton(systemImage: "checkmark", tint: .green, label: "Knew it") { fling(correct: true) }
            }

            Text("Tap to flip. Swipe right if you knew it, left if you didn't.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    @ViewBuilder
    private var swipeStamp: some View {
        let progress = min(abs(offset.width) / threshold, 1)
        if offset.width > 0 {
            Stamp(text: "¡SÍ!", color: .green)
                .rotationEffect(.degrees(-12))
                .opacity(progress)
                .padding(.top, 28)
        } else if offset.width < 0 {
            Stamp(text: "NOPE", color: .red)
                .rotationEffect(.degrees(12))
                .opacity(progress)
                .padding(.top, 28)
        }
    }

    private var drag: some Gesture {
        DragGesture()
            .onChanged { value in
                guard !isFlyingOff else { return }
                offset = value.translation
            }
            .onEnded { value in
                guard !isFlyingOff else { return }
                if value.translation.width > threshold {
                    fling(correct: true)
                } else if value.translation.width < -threshold {
                    fling(correct: false)
                } else {
                    withAnimation(.spring(duration: 0.35)) { offset = .zero }
                }
            }
    }

    private func fling(correct: Bool) {
        guard !isFlyingOff else { return }
        isFlyingOff = true
        UINotificationFeedbackGenerator().notificationOccurred(correct ? .success : .error)
        withAnimation(.easeIn(duration: 0.25)) {
            offset = CGSize(width: correct ? 700 : -700, height: offset.height)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            onAnswer(correct)
        }
    }
}

struct FlashcardView: View {
    let frontLabel: String
    let front: String
    let backLabel: String
    let back: String
    let note: String
    let isFlipped: Bool

    var body: some View {
        ZStack {
            face(label: frontLabel, text: front, note: nil, hint: "Tap to see the translation")
                .opacity(isFlipped ? 0 : 1)
            face(label: backLabel, text: back, note: note.isEmpty ? nil : note, hint: nil)
                .opacity(isFlipped ? 1 : 0)
                .rotation3DEffect(.degrees(180), axis: (x: 0, y: 1, z: 0))
        }
        .rotation3DEffect(.degrees(isFlipped ? 180 : 0), axis: (x: 0, y: 1, z: 0), perspective: 0.4)
    }

    private func face(label: String, text: String, note: String?, hint: String?) -> some View {
        VStack(spacing: 14) {
            Text(label.uppercased())
                .tracking(1.5)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Spacer(minLength: 0)
            Text(text)
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.4)
            if let note {
                Text(note)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            Spacer(minLength: 0)
            if let hint {
                Text(hint)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(28)
        .frame(maxWidth: .infinity)
        .frame(height: 400)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
                .shadow(color: .black.opacity(0.12), radius: 16, y: 8)
        )
    }
}
