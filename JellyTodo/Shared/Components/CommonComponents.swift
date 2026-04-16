import SwiftUI

enum JellyShadowStyle {
    case standard
    case listItem
}

struct JellyCardModifier: ViewModifier {
    @Environment(\.appThemeMode) private var themeMode

    let shadowStyle: JellyShadowStyle

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: ThemeTokens.Metrics.cornerRadius, style: .continuous)

        content
            .clipShape(shape)
            .background(
                cardBackground(shape: shape)
            )
    }

    @ViewBuilder
    private func cardBackground(shape: RoundedRectangle) -> some View {
        switch shadowStyle {
        case .standard:
            shape
                .fill(ThemeTokens.card(for: themeMode))
                .shadow(color: .white.opacity(0.75), radius: 3, x: -1, y: -1)
                .shadow(color: .black.opacity(0.08), radius: 5, x: 2, y: 2)
        case .listItem:
            shape
                .fill(ThemeTokens.card(for: themeMode))
                .shadow(color: .white.opacity(0.55), radius: 1, x: 0, y: -1)
                .shadow(color: .black.opacity(0.045), radius: 9, x: 0, y: 4)
        }
    }
}

struct JellyCard<Content: View>: View {
    let content: Content
    let shadowStyle: JellyShadowStyle

    init(shadowStyle: JellyShadowStyle = .standard, @ViewBuilder content: () -> Content) {
        self.shadowStyle = shadowStyle
        self.content = content()
    }

    var body: some View {
        content
            .modifier(JellyCardModifier(shadowStyle: shadowStyle))
    }
}

struct SectionCard<Content: View>: View {
    let title: String
    let content: Content

    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title)
                .font(ThemeTokens.Typography.sectionTitle)
                .foregroundStyle(ThemeTokens.Colors.textPrimary)

            JellyCard {
                VStack(spacing: 0) {
                    content
                }
                .padding(20)
            }
        }
    }
}

struct CapsuleButton: View {
    @Environment(\.appThemeMode) private var themeMode

    let title: String
    var fill: Color? = nil
    var foreground: Color = ThemeTokens.Colors.textPrimary
    var minWidth: CGFloat? = nil
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(ThemeTokens.Typography.body)
                .foregroundStyle(foreground)
                .frame(minWidth: minWidth)
                .frame(height: ThemeTokens.Metrics.controlHeight)
                .padding(.horizontal, 24)
                .background(fill ?? ThemeTokens.card(for: themeMode))
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .scaleEffect(1)
    }
}

struct BottomSheetContainer<Content: View>: View {
    @Environment(\.appThemeMode) private var themeMode

    let title: String
    let content: Content

    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(spacing: 24) {
            Capsule()
                .fill(ThemeTokens.Colors.subtleLine)
                .frame(width: 52, height: 6)
                .padding(.top, 8)

            Text(title)
                .font(ThemeTokens.Typography.sectionTitle)
                .foregroundStyle(ThemeTokens.Colors.textPrimary)

            content
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 24)
        .background(ThemeTokens.background(for: themeMode))
    }
}

struct StatRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack {
            Text(title)
                .font(ThemeTokens.Typography.body)
                .foregroundStyle(ThemeTokens.Colors.textSecondary)
            Spacer()
            Text(value)
                .font(ThemeTokens.Typography.body)
                .foregroundStyle(ThemeTokens.Colors.textPrimary)
        }
        .padding(.vertical, 4)
    }
}
