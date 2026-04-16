import SwiftUI

private enum AppTab: Hashable {
    case month
    case today
    case set
}

struct RootTabView: View {
    @Environment(\.appThemeMode) private var themeMode
    @State private var selectedTab: AppTab = .today

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                MonthView()
            }
            .tabItem {
                Label("Month", systemImage: "calendar")
            }
            .tag(AppTab.month)

            NavigationStack {
                TodayView()
            }
            .tabItem {
                Label("Today", systemImage: "sun.max")
            }
            .tag(AppTab.today)

            NavigationStack {
                SetView()
            }
            .tabItem {
                Label("Set", systemImage: "slider.horizontal.3")
            }
            .tag(AppTab.set)
        }
        .tint(ThemeTokens.accent(for: themeMode))
    }
}
