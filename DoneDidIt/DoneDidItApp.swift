import SwiftUI

@main
struct DoneDidItApp: App {
    @State private var store = HabitStore()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(store)
                .tint(Palette.accent)
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { store.now = Date() }
        }
    }
}

struct ContentView: View {
    @Environment(HabitStore.self) private var store

    var body: some View {
        ZStack {
            TabView {
                TodayView()
                    .tabItem { Label("Today", systemImage: "checkmark.circle") }
                HabitCalendarView()
                    .tabItem { Label("Calendar", systemImage: "calendar") }
                StatsView()
                    .tabItem { Label("Progress", systemImage: "chart.bar.fill") }
            }
            ConfettiView(trigger: store.celebrate)
                .ignoresSafeArea()
        }
    }
}
