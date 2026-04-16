import SwiftUI

struct TodoRow: View {
    let index: Int
    let item: TodoItem
    let onTap: () -> Void
    var onLongPress: (() -> Void)? = nil
    var onEdit: (() -> Void)? = nil
    var onDelete: (() -> Void)? = nil

    @State private var settledOffset: CGFloat = 0
    @GestureState private var dragOffset: CGFloat = 0

    private var actionWidth: CGFloat {
        let actionCount = [onEdit, onDelete].compactMap { $0 }.count
        guard actionCount > 0 else { return 0 }
        return CGFloat(actionCount) * 82
    }

    private var visibleOffset: CGFloat {
        min(0, max(-actionWidth, settledOffset + dragOffset))
    }

    var body: some View {
        ZStack(alignment: .trailing) {
            actionButtons
                .opacity(actionWidth > 0 ? 1 : 0)

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
            .offset(x: visibleOffset)
            .contentShape(RoundedRectangle(cornerRadius: ThemeTokens.Metrics.cornerRadius, style: .continuous))
            .onTapGesture {
                if settledOffset < 0 {
                    closeActions()
                } else {
                    onTap()
                }
            }
            .onLongPressGesture(minimumDuration: 0.45) {
                guard settledOffset == 0 else { return }
                onLongPress?()
            }
            .gesture(swipeGesture)
        }
        .animation(.easeOut(duration: 0.18), value: settledOffset)
    }

    private var actionButtons: some View {
        HStack(spacing: 8) {
            if let onEdit {
                swipeButton(title: "Edit") {
                    closeActions()
                    onEdit()
                }
            }

            if let onDelete {
                swipeButton(title: "Delete") {
                    closeActions()
                    onDelete()
                }
            }
        }
        .padding(.trailing, 2)
    }

    private var swipeGesture: some Gesture {
        DragGesture(minimumDistance: 12)
            .updating($dragOffset) { value, state, _ in
                guard actionWidth > 0 else { return }
                guard abs(value.translation.width) > abs(value.translation.height) else { return }
                state = value.translation.width
            }
            .onEnded { value in
                guard actionWidth > 0 else { return }
                guard abs(value.translation.width) > abs(value.translation.height) else { return }

                let targetOffset = settledOffset + value.translation.width
                settledOffset = targetOffset < -actionWidth * 0.35 ? -actionWidth : 0
            }
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

    private func closeActions() {
        settledOffset = 0
    }
}

struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}
