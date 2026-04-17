import SwiftUI

private struct AppThemeModeKey: EnvironmentKey {
    static let defaultValue: AppThemeMode = .blackWhite
}

extension EnvironmentValues {
    var appThemeMode: AppThemeMode {
        get { self[AppThemeModeKey.self] }
        set { self[AppThemeModeKey.self] = newValue }
    }
}

enum ThemeTokens {
    struct Palette {
        let background: Color
        let card: Color
        let accent: Color
        let accentSoft: Color
    }

    enum Colors {
        static let backgroundPrimary = Color(hex: "#FFFFFF")
        static let backgroundSoft = Color(hex: "#F7F7F8")
        static let card = Color(hex: "#F5F5F7")
        static let textPrimary = Color(hex: "#333333")
        static let textSecondary = Color(hex: "#888888")
        static let subtleLine = Color(hex: "#E9E9EC")
    }

    enum Metrics {
        static let horizontalPadding: CGFloat = 16
        static let sectionSpacing: CGFloat = 24
        static let cardSpacing: CGFloat = 20
        static let cardHeight: CGFloat = 100
        static let controlHeight: CGFloat = 60
        static let cornerRadius: CGFloat = 32
    }

    enum Typography {
        static let pageTitle = Font.system(size: 40, weight: .bold, design: .rounded)
        static let largeStat = Font.system(size: 32, weight: .bold, design: .rounded)
        static let taskTitle = Font.system(size: 28, weight: .bold, design: .rounded)
        static let sectionTitle = Font.system(size: 24, weight: .bold, design: .rounded)
        static let tabLabel = Font.system(size: 20, weight: .bold, design: .rounded)
        static let body = Font.system(size: 20, weight: .bold, design: .rounded)
        static let caption = Font.system(size: 18, weight: .bold, design: .rounded)
    }

    static func background(for mode: AppThemeMode) -> Color {
        palette(for: mode).background
    }

    static func card(for mode: AppThemeMode) -> Color {
        palette(for: mode).card
    }

    static func accent(for mode: AppThemeMode) -> Color {
        palette(for: mode).accent
    }

    static func accentSoft(for mode: AppThemeMode) -> Color {
        palette(for: mode).accentSoft
    }

    static func palette(for mode: AppThemeMode) -> Palette {
        switch mode {
        case .pink:
            return Palette(
                background: Color(hex: "#FFF8FA"),
                card: Color(hex: "#FFF0F4"),
                accent: Color(hex: "#F58BA8"),
                accentSoft: Color(hex: "#FFDDE7")
            )
        case .blackWhite:
            return Palette(
                background: Colors.backgroundPrimary,
                card: Colors.card,
                accent: Colors.textPrimary,
                accentSoft: Colors.subtleLine
            )
        case .blue:
            return Palette(
                background: Color(hex: "#F7FBFF"),
                card: Color(hex: "#EEF6FF"),
                accent: Color(hex: "#78AEEA"),
                accentSoft: Color(hex: "#DCEEFF")
            )
        case .green:
            return Palette(
                background: Color(hex: "#F8FFF9"),
                card: Color(hex: "#EEFAF1"),
                accent: Color(hex: "#7BCB91"),
                accentSoft: Color(hex: "#DDF5E4")
            )
        case .rainbow:
            return Palette(
                background: Color(hex: "#FFFDF7"),
                card: Color(hex: "#FFF7EE"),
                accent: Color(hex: "#FF8A5B"),
                accentSoft: Color(hex: "#FFE8C7")
            )
        }
    }
}
