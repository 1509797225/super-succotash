import SwiftUI

enum ThemeTokens {
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
        switch mode {
        case .pureWhite, .followSystem:
            return Colors.backgroundPrimary
        case .softGray:
            return Colors.backgroundSoft
        }
    }
}
