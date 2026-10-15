import SwiftUI
import SwiftData

@main
struct SpanishCardsApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(for: Card.self)
    }
}

struct RootView: View {
    @Environment(\.modelContext) private var context

    var body: some View {
        TabView {
            StudyView()
                .tabItem { Label("Study", systemImage: "rectangle.on.rectangle.angled") }
            CardLibraryView()
                .tabItem { Label("Cards", systemImage: "list.bullet.rectangle.portrait") }
        }
        .onAppear { StarterSeeder.seedIfNeeded(context) }
    }
}
