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

struct JellyToolMenuAction: Identifiable {
    let id: String
    let title: String
    let systemImage: String
    var isActive = false
    let action: () -> Void
}

struct JellyToolMenu: View {
    @Environment(\.appThemeMode) private var themeMode
    @Environment(\.appLanguage) private var language
    @Binding var isExpanded: Bool

    let actions: [JellyToolMenuAction]

    var body: some View {
        ZStack(alignment: .topTrailing) {
            if isExpanded {
                VStack(spacing: 10) {
                    ForEach(actions) { item in
                        Button {
                            item.action()
                        } label: {
                            VStack(spacing: 4) {
                                Image(systemName: item.systemImage)
                                    .font(.system(size: 18, weight: .bold))

                                Text(item.title)
                                    .font(.system(size: 10, weight: .bold, design: .rounded))
                                    .lineLimit(1)
                            }
                            .foregroundStyle(item.isActive ? ThemeTokens.Colors.backgroundPrimary : ThemeTokens.Colors.textPrimary)
                            .frame(width: 54, height: 54)
                            .background(item.isActive ? ThemeTokens.accent(for: themeMode) : Color.clear)
                            .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 12)
                .padding(.horizontal, 6)
                .background(ThemeTokens.card(for: themeMode).opacity(0.96))
                .clipShape(Capsule())
                .modifier(JellyCardModifier(shadowStyle: .standard))
                .padding(.top, 60)
                .transition(.asymmetric(
                    insertion: .scale(scale: 0.82, anchor: .topTrailing).combined(with: .opacity),
                    removal: .scale(scale: 0.92, anchor: .topTrailing).combined(with: .opacity)
                ))
            }

            Button {
                withAnimation(.spring(response: 0.28, dampingFraction: 0.78)) {
                    isExpanded.toggle()
                }
            } label: {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(ThemeTokens.Colors.textPrimary)
                    .frame(width: 52, height: 52)
                    .background(ThemeTokens.card(for: themeMode))
                    .clipShape(Circle())
                    .modifier(JellyCardModifier(shadowStyle: .standard))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isExpanded ? L10n.t(.closeSettingsMenu, language) : L10n.t(.openSettingsMenu, language))
        }
        .frame(width: 72, alignment: .topTrailing)
        .animation(.spring(response: 0.28, dampingFraction: 0.78), value: isExpanded)
    }
}
