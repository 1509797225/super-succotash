import SwiftUI

private enum AppTab: Hashable {
    case plan
    case today
    case set
}

struct RootTabView: View {
    @Environment(\.appThemeMode) private var themeMode
    @Environment(\.appLanguage) private var language
    @State private var selectedTab: AppTab = .today

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                PlanView()
            }
            .tabItem {
                Label(L10n.t(.plan, language), systemImage: "list.bullet.rectangle.portrait")
            }
            .tag(AppTab.plan)

            NavigationStack {
                TodayView()
            }
            .tabItem {
                Label(L10n.t(.today, language), systemImage: "sun.max")
            }
            .tag(AppTab.today)

            NavigationStack {
                SetView()
            }
            .tabItem {
                Label(L10n.t(.set, language), systemImage: "slider.horizontal.3")
            }
            .tag(AppTab.set)
        }
        .tint(ThemeTokens.accent(for: themeMode))
    }
}
