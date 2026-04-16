import SwiftUI

struct TodoRow: View {
    let index: Int
    let item: TodoItem
    let onTap: () -> Void
    var onLongPress: (() -> Void)? = nil
    var onEdit: (() -> Void)? = nil
    var onDelete: (() -> Void)? = nil

    private var actionWidth: CGFloat {
        let actionCount = [onEdit, onDelete].compactMap { $0 }.count
        guard actionCount > 0 else { return 0 }
        return CGFloat(actionCount) * 82
    }

    var body: some View {
        GeometryReader { proxy in
            ScrollViewReader { reader in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        rowCard(width: proxy.size.width)
                            .id("card")

                        if actionWidth > 0 {
                            actionButtons
                                .frame(width: actionWidth, alignment: .trailing)
                                .id("actions")
                        }
                    }
                    .frame(height: ThemeTokens.Metrics.cardHeight)
                }
                .onAppear {
                    reader.scrollTo("card", anchor: .leading)
                }
            }
        }
        .frame(height: ThemeTokens.Metrics.cardHeight)
    }

    private func rowCard(width: CGFloat) -> some View {
        JellyCard(shadowStyle: .listItem) {
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
            .frame(width: width, height: ThemeTokens.Metrics.cardHeight)
        }
        .contentShape(RoundedRectangle(cornerRadius: ThemeTokens.Metrics.cornerRadius, style: .continuous))
        .onTapGesture(perform: onTap)
        .onLongPressGesture(minimumDuration: 0.45) {
            onLongPress?()
        }
    }

    private var actionButtons: some View {
        HStack(spacing: 8) {
            if let onEdit {
                swipeButton(title: "Edit") {
                    onEdit()
                }
            }

            if let onDelete {
                swipeButton(title: "Delete") {
                    onDelete()
                }
            }
        }
        .padding(.trailing, 2)
    }

    private func swipeButton(title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(ThemeTokens.Typography.caption)
                .foregroundStyle(ThemeTokens.Colors.textPrimary)
                .frame(width: 74, height: 72)
                .background(ThemeTokens.Colors.card)
                .clipShape(Capsule())
                .shadow(color: .white.opacity(0.8), radius: 4, x: -2, y: -2)
                .shadow(color: .black.opacity(0.1), radius: 6, x: 2, y: 2)
        }
        .buttonStyle(.plain)
    }
}

struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}
