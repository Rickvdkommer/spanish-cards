import SwiftUI
import SwiftData
import Charts

struct ProfileView: View {
    @Query private var cards: [Card]
    @Query(sort: \ReviewLog.date) private var logs: [ReviewLog]
    @AppStorage("profileName") private var name = ""
    @State private var isEditingName = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    header
                    tiles
                    overallProgress
                    activityChart
                    deckProgress
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Profile")
            .alert("Your name", isPresented: $isEditingName) {
                TextField("Name", text: $name)
                Button("OK") {}
            }
        }
    }

    // MARK: Sections

    private var header: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle().fill(Color.accentColor.gradient)
                Text(initial)
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
            }
            .frame(width: 64, height: 64)

            VStack(alignment: .leading, spacing: 4) {
                Button { isEditingName = true } label: {
                    HStack(spacing: 6) {
                        Text("¡Hola, \(name.isEmpty ? "amigo" : name)!")
                            .font(.title2.bold())
                        Image(systemName: "pencil")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
                .buttonStyle(.plain)
                Text(levelTitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .card()
    }

    private var tiles: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
            BigStat(icon: "flame.fill", tint: .orange, value: "\(streak)", label: "day streak")
            BigStat(icon: "checkmark.seal.fill", tint: .green, value: "\(learned)", label: "cards learned")
            BigStat(icon: "hand.draw.fill", tint: .blue, value: "\(reviewsToday)", label: "swipes today")
            BigStat(icon: "target", tint: .purple, value: accuracyText, label: "right, last 7 days")
        }
    }

    private var overallProgress: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Overall").font(.headline)
                Spacer()
                Text("\(learned) of \(cards.count) learned")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            ProgressView(value: Double(learned), total: Double(max(cards.count, 1)))
                .tint(.green)
            HStack {
                legendDot(.blue, "New", newCount)
                Spacer()
                legendDot(.orange, "Learning", learning)
                Spacer()
                legendDot(.green, "Learned", learned)
                Spacer()
                legendDot(.red, "Due now", dueNow)
            }
            .font(.caption)
        }
        .card()
    }

    private var activityChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Last 7 days").font(.headline)
            if week.allSatisfy({ $0.total == 0 }) {
                Text("No swipes yet this week. Go hit the Study tab.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 120)
            } else {
                Chart {
                    ForEach(week) { day in
                        BarMark(x: .value("Day", day.day, unit: .day), y: .value("Swipes", day.correct))
                            .foregroundStyle(by: .value("Answer", "Right"))
                        BarMark(x: .value("Day", day.day, unit: .day), y: .value("Swipes", day.wrong))
                            .foregroundStyle(by: .value("Answer", "Wrong"))
                    }
                }
                .chartForegroundStyleScale(["Right": Color.green, "Wrong": Color.red.opacity(0.7)])
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day)) { _ in
                        AxisValueLabel(format: .dateTime.weekday(.narrow))
                    }
                }
                .frame(height: 160)
            }
        }
        .card()
    }

    private var deckProgress: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Decks").font(.headline)
            ForEach(deckNames, id: \.self) { deck in
                let deckCards = cards.filter { $0.deck == deck }
                let deckLearned = deckCards.filter(\.isLearned).count
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(deck).font(.subheadline.weight(.medium))
                        Spacer()
                        Text("\(deckLearned)/\(deckCards.count)")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                    ProgressView(value: Double(deckLearned), total: Double(max(deckCards.count, 1)))
                        .tint(deckLearned == deckCards.count && !deckCards.isEmpty ? Color.green : Color.accentColor)
                }
            }
        }
        .card()
    }

    private func legendDot(_ color: Color, _ label: String, _ value: Int) -> some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text("\(label) \(value)").foregroundStyle(.secondary)
        }
    }

    // MARK: Numbers

    private var initial: String {
        name.trimmingCharacters(in: .whitespaces).first.map { String($0).uppercased() } ?? "¡"
    }

    private var learned: Int { cards.filter(\.isLearned).count }
    private var newCount: Int { cards.filter(\.isNew).count }
    private var learning: Int { cards.count - learned - newCount }
    private var dueNow: Int {
        let now = Date.now
        return cards.filter { !$0.isNew && $0.dueDate <= now }.count
    }

    private var streak: Int { ProgressStats.dayStreak(reviewDates: logs.map(\.date)) }

    private var reviewsToday: Int {
        let today = Calendar.current.startOfDay(for: .now)
        return logs.filter { $0.date >= today }.count
    }

    private var week: [ProgressStats.DayActivity] {
        ProgressStats.activity(lastDays: 7, reviews: logs.map { (date: $0.date, correct: $0.correct) })
    }

    private var accuracyText: String {
        let total = week.reduce(0) { $0 + $1.total }
        guard total > 0 else { return "–" }
        let right = week.reduce(0) { $0 + $1.correct }
        return "\(Int((Double(right) / Double(total) * 100).rounded()))%"
    }

    private var levelTitle: String {
        switch learned {
        case 0..<10: return "Principiante · just getting started"
        case 10..<50: return "Aprendiz · picking it up"
        case 50..<150: return "Intermedio · getting there"
        case 150..<300: return "Avanzado · seriously good"
        default: return "Maestro · ¡increíble!"
        }
    }

    private var deckNames: [String] {
        Set(cards.map(\.deck)).sorted { lhs, rhs in
            if lhs == Decks.mine { return true }
            if rhs == Decks.mine { return false }
            return lhs < rhs
        }
    }
}

private struct BigStat: View {
    let icon: String
    let tint: Color
    let value: String
    let label: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(tint)
            Text(value)
                .font(.system(size: 30, weight: .bold, design: .rounded))
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }
}

private extension View {
    func card() -> some View {
        padding()
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}
