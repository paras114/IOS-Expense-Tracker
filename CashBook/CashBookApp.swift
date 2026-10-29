import SwiftUI
import AppIntents

enum AppTab: Hashable {
    case home, history, settings
}

@MainActor
@Observable
final class AppRouter {
    static let shared = AppRouter()
    var tab: AppTab = .home
    var showAdd = false

    init() {
        // Launch options used for preview screenshots: -tab history|settings, -add
        let args = CommandLine.arguments
        if let i = args.firstIndex(of: "-tab"), i + 1 < args.count {
            switch args[i + 1] {
            case "history": tab = .history
            case "settings": tab = .settings
            default: break
            }
        }
        showAdd = args.contains("-add")
    }
}

@main
struct CashBookApp: App {
    @State private var store = Store()
    @State private var router = AppRouter.shared

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
                .environment(router)
        }
    }
}

struct RootView: View {
    @Environment(Store.self) private var store
    @Environment(AppRouter.self) private var router
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        @Bindable var router = router
        TabView(selection: $router.tab) {
            HomeView()
                .tabItem { Label("Overview", systemImage: "chart.pie.fill") }
                .tag(AppTab.home)
            HistoryView()
                .tabItem { Label("History", systemImage: "list.bullet.rectangle.fill") }
                .tag(AppTab.history)
            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape.fill") }
                .tag(AppTab.settings)
        }
        .sheet(isPresented: $router.showAdd) {
            ExpenseFormView()
        }
        .onChange(of: store.settings) { _, _ in
            store.saveSettings()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { await store.sync() } }
        }
    }
}

// MARK: Siri / Action Button / Shortcuts

struct AddExpenseIntent: AppIntent {
    static var title: LocalizedStringResource = "Add Cash Expense"
    static var description = IntentDescription("Opens Cash Book ready to log a new expense.")
    static var openAppWhenRun: Bool = true

    @MainActor
    func perform() async throws -> some IntentResult {
        AppRouter.shared.showAdd = true
        return .result()
    }
}

struct CashBookShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: AddExpenseIntent(),
            phrases: [
                "Add expense in \(.applicationName)",
                "Log cash in \(.applicationName)",
                "New \(.applicationName) expense"
            ],
            shortTitle: "Add Expense",
            systemImageName: "plus.circle.fill"
        )
    }
}
