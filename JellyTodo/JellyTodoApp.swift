import SwiftUI

#if canImport(UIKit)
import UIKit

final class OrientationLock {
    static var supportedOrientations: UIInterfaceOrientationMask = .portrait

    static func set(_ orientations: UIInterfaceOrientationMask) {
        supportedOrientations = orientations
        refreshSupportedOrientations()
    }

    static func rotate(to orientations: UIInterfaceOrientationMask) {
        supportedOrientations = orientations
        refreshSupportedOrientations()

        guard let windowScene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive })
        else { return }

        windowScene.requestGeometryUpdate(.iOS(interfaceOrientations: orientations))
    }

    private static func refreshSupportedOrientations() {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .forEach { $0.rootViewController?.setNeedsUpdateOfSupportedInterfaceOrientations() }
    }
}

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        supportedInterfaceOrientationsFor window: UIWindow?
    ) -> UIInterfaceOrientationMask {
        OrientationLock.supportedOrientations
    }
}
#endif

@main
struct JellyTodoApp: App {
#if canImport(UIKit)
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
#endif
    @StateObject private var store = AppStore()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ZStack(alignment: .topTrailing) {
                RootTabView()
#if DEBUG
                DebugPomodoroSeedOverlay()
#endif
            }
                .environmentObject(store)
                .environment(\.appThemeMode, store.settings.themeMode)
                .environment(\.appLanguage, store.settings.language)
                .environment(\.appTextScale, store.settings.textScale)
                .environment(\.locale, Locale(identifier: store.settings.language.localeIdentifier))
                .preferredColorScheme(store.preferredColorScheme)
                .background(ThemeTokens.background(for: store.settings.themeMode).ignoresSafeArea())
                .task {
                    store.loadInitialState()
                }
                .onChange(of: scenePhase) { phase in
                    guard phase == .active else { return }
                    store.materializeTodayOccurrencesIfNeeded()
                    Task {
                        await store.performForegroundAutoSyncIfNeeded()
                    }
                }
        }
    }
}
