import SwiftUI

struct TodoRow: View {
    let index: Int
    let item: TodoItem
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            JellyCard {
                HStack(spacing: 16) {
                    Text(String(format: "%02d", index))
                        .font(ThemeTokens.Typography.sectionTitle)
                        .foregroundStyle(ThemeTokens.Colors.textSecondary)
                        .frame(width: 44, alignment: .leading)

                    Text(item.title)
                        .font(ThemeTokens.Typography.taskTitle)
                        .foregroundStyle(ThemeTokens.Colors.textPrimary)
                        .lineLimit(1)
                        .strikethrough(item.isCompleted, color: ThemeTokens.Colors.textPrimary)
                        .opacity(item.isCompleted ? 0.55 : 1)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Circle()
                        .strokeBorder(ThemeTokens.Colors.textSecondary, lineWidth: 2)
                        .background(
                            Circle()
                                .fill(item.isCompleted ? ThemeTokens.Colors.textPrimary : .clear)
                        )
                        .frame(width: 28, height: 28)
                }
                .padding(.horizontal, 20)
                .frame(height: ThemeTokens.Metrics.cardHeight)
            }
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}
