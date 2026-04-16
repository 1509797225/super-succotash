import SwiftUI

struct JellyCardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(ThemeTokens.Colors.card)
            .clipShape(RoundedRectangle(cornerRadius: ThemeTokens.Metrics.cornerRadius, style: .continuous))
            .shadow(color: .white.opacity(0.8), radius: 4, x: -2, y: -2)
            .shadow(color: .black.opacity(0.1), radius: 6, x: 2, y: 2)
    }
}

struct JellyCard<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .modifier(JellyCardModifier())
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
    let title: String
    var fill: Color = ThemeTokens.Colors.card
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
                .background(fill)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .scaleEffect(1)
    }
}

struct BottomSheetContainer<Content: View>: View {
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
        .background(ThemeTokens.Colors.backgroundPrimary)
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
