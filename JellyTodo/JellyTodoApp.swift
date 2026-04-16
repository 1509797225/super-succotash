import SwiftUI

@main
struct JellyTodoApp: App {
    @StateObject private var store = AppStore()

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .environmentObject(store)
                .preferredColorScheme(store.preferredColorScheme)
                .background(ThemeTokens.background(for: store.settings.themeMode).ignoresSafeArea())
        }
    }
}
