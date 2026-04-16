import SwiftUI

struct TodoRow: View {
    let index: Int
    let item: TodoItem
    let themeMode: AppThemeMode
    let onTap: () -> Void
    var onLongPress: (() -> Void)? = nil
    var onEdit: (() -> Void)? = nil
    var onDelete: (() -> Void)? = nil
    var onSwipeComplete: (() -> Void)? = nil

    @State private var settledFillWidth: CGFloat = 0
    @GestureState private var activeRightDrag: CGFloat = 0

    private var actionWidth: CGFloat {
        let actionCount = [onEdit, onDelete].compactMap { $0 }.count
        guard actionCount > 0 else { return 0 }
        return CGFloat(actionCount) * 82
    }

    var body: some View {
        GeometryReader { proxy in
            let rowWidth = proxy.size.width

            ScrollViewReader { reader in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        rowCard(width: rowWidth)
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
        .onChange(of: item.isCompleted) { isCompleted in
            if !isCompleted {
                settledFillWidth = 0
            }
        }
    }

    private func rowCard(width: CGFloat) -> some View {
        JellyCard(shadowStyle: .listItem) {
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: ThemeTokens.Metrics.cornerRadius, style: .continuous)
                    .fill(ThemeTokens.accent(for: themeMode).opacity(item.isCompleted ? 0.34 : 0.42))
                    .frame(width: displayedFillWidth(for: width), height: ThemeTokens.Metrics.cardHeight)
                    .animation(.easeOut(duration: 0.18), value: item.isCompleted)

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
                                .fill(item.isCompleted ? ThemeTokens.accent(for: themeMode) : .clear)
                        )
                        .frame(width: 28, height: 28)
                }
                .padding(.horizontal, 20)
            }
            .frame(width: width, height: ThemeTokens.Metrics.cardHeight)
        }
        .contentShape(RoundedRectangle(cornerRadius: ThemeTokens.Metrics.cornerRadius, style: .continuous))
        .simultaneousGesture(rightFillGesture(rowWidth: width))
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
                .background(ThemeTokens.card(for: themeMode))
                .clipShape(Capsule())
                .shadow(color: .white.opacity(0.8), radius: 4, x: -2, y: -2)
                .shadow(color: .black.opacity(0.1), radius: 6, x: 2, y: 2)
        }
        .buttonStyle(.plain)
    }

    private func displayedFillWidth(for rowWidth: CGFloat) -> CGFloat {
        if item.isCompleted {
            return rowWidth
        }

        return min(max(settledFillWidth + activeRightDrag, 0), rowWidth)
    }

    private func rightFillGesture(rowWidth: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 18, coordinateSpace: .local)
            .updating($activeRightDrag) { value, state, _ in
                guard isRightFillSwipe(value) else { return }
                state = value.translation.width
            }
            .onEnded { value in
                guard isRightFillSwipe(value) else { return }

                let targetWidth = min(max(settledFillWidth + value.translation.width, 0), rowWidth)
                if targetWidth >= rowWidth * 0.94 {
                    settledFillWidth = rowWidth
                    if !item.isCompleted {
                        onSwipeComplete?()
                    }
                } else {
                    settledFillWidth = targetWidth
                }
            }
    }

    private func isRightFillSwipe(_ value: DragGesture.Value) -> Bool {
        let horizontal = value.translation.width
        let vertical = abs(value.translation.height)
        return horizontal > 0 && horizontal > vertical * 1.25
    }
}

struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}
