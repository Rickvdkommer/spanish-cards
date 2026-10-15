import SwiftUI
import SwiftData

@main
struct SpanishCardsApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(for: [Card.self, ReviewLog.self])
    }
}

struct RootView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        TabView {
            StudyView()
                .tabItem { Label("Study", systemImage: "rectangle.on.rectangle.angled") }
            CardLibraryView()
                .tabItem { Label("Cards", systemImage: "list.bullet.rectangle.portrait") }
            ProfileView()
                .tabItem { Label("Profile", systemImage: "person.crop.circle") }
        }
        .onAppear {
            StarterSeeder.seedIfNeeded(context)
            DailyReminder.refresh(context: context)
        }
        .onChange(of: scenePhase) { _, phase in
            // Re-plan reminders with fresh due counts every time you leave the app.
            if phase == .background { DailyReminder.refresh(context: context) }
        }
    }
}
