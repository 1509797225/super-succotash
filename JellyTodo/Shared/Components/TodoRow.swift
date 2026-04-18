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
    @State private var actionReveal: CGFloat = 0
    @State private var dragStartFillWidth: CGFloat = 0
    @State private var dragStartActionReveal: CGFloat = 0
    @State private var dragAxis: DragAxis = .undetermined
    @State private var hasCapturedDragStart = false

    private var actionWidth: CGFloat {
        let actionCount = [onEdit, onDelete].compactMap { $0 }.count
        guard actionCount > 0 else { return 0 }
        return CGFloat(actionCount) * 82
    }

    var body: some View {
        GeometryReader { proxy in
            let rowWidth = proxy.size.width

            ZStack(alignment: .trailing) {
                if actionWidth > 0 {
                    actionButtons
                        .frame(width: actionWidth, alignment: .trailing)
                }

                rowCard(width: rowWidth)
                    .offset(x: -actionReveal)
                    .animation(.easeOut(duration: 0.18), value: actionReveal)
            }
            .frame(width: rowWidth, height: ThemeTokens.Metrics.cardHeight)
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
        .simultaneousGesture(rowDragGesture(rowWidth: width))
        .onTapGesture {
            if actionReveal > 0 {
                actionReveal = 0
            } else {
                onTap()
            }
        }
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

        return min(max(settledFillWidth, 0), rowWidth)
    }

    private func rowDragGesture(rowWidth: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 18, coordinateSpace: .local)
            .onChanged { value in
                captureDragStartIfNeeded()
                updateDragAxisIfNeeded(value)

                guard dragAxis == .horizontal else { return }

                if shouldRevealActions(value) {
                    actionReveal = min(max(dragStartActionReveal - value.translation.width, 0), actionWidth)
                    return
                }

                if shouldFillCompletion(value) {
                    actionReveal = 0
                    settledFillWidth = min(max(dragStartFillWidth + value.translation.width, 0), rowWidth)
                }
            }
            .onEnded { value in
                defer { resetDragTracking() }
                guard dragAxis == .horizontal else { return }

                if shouldRevealActions(value) {
                    settleActionReveal()
                    return
                }

                guard shouldFillCompletion(value) else { return }
                if settledFillWidth >= rowWidth * 0.94 {
                    completeFromFill(rowWidth: rowWidth)
                }
            }
    }

    private func captureDragStartIfNeeded() {
        guard !hasCapturedDragStart else { return }
        hasCapturedDragStart = true
        dragStartFillWidth = item.isCompleted ? 0 : settledFillWidth
        dragStartActionReveal = actionReveal
        dragAxis = .undetermined
    }

    private func updateDragAxisIfNeeded(_ value: DragGesture.Value) {
        guard dragAxis == .undetermined else { return }

        let horizontal = value.translation.width
        let vertical = abs(value.translation.height)
        guard max(abs(horizontal), vertical) > 10 else { return }

        if abs(horizontal) > vertical * 1.2 {
            dragAxis = .horizontal
        } else if vertical > abs(horizontal) * 1.2 {
            dragAxis = .vertical
        }
    }

    private func shouldRevealActions(_ value: DragGesture.Value) -> Bool {
        actionWidth > 0 && (value.translation.width < 0 || dragStartActionReveal > 0)
    }

    private func shouldFillCompletion(_ value: DragGesture.Value) -> Bool {
        value.translation.width > 0 && dragStartActionReveal == 0
    }

    private func settleActionReveal() {
        let shouldStayOpen = actionReveal > min(actionWidth * 0.42, 68)
        actionReveal = shouldStayOpen ? actionWidth : 0
    }

    private func completeFromFill(rowWidth: CGFloat) {
        settledFillWidth = rowWidth
        if !item.isCompleted {
            onSwipeComplete?()
        }
    }

    private func resetDragTracking() {
        hasCapturedDragStart = false
        dragStartFillWidth = 0
        dragStartActionReveal = 0
        dragAxis = .undetermined
    }
}

struct CompactTodoRow: View {
    let item: TodoItem
    let themeMode: AppThemeMode
    var showsDate = false
    var onTap: (() -> Void)? = nil
    var onAddToday: (() -> Void)? = nil

    @State private var actionReveal: CGFloat = 0
    @State private var dragStartActionReveal: CGFloat = 0

    private var actionWidth: CGFloat {
        onAddToday == nil ? 0 : 96
    }

    var body: some View {
        GeometryReader { proxy in
            let rowWidth = proxy.size.width

            ZStack(alignment: .trailing) {
                if let onAddToday {
                    Button(action: onAddToday) {
                        Text("Today")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundStyle(ThemeTokens.Colors.textPrimary)
                            .frame(width: 82, height: 54)
                            .background(ThemeTokens.card(for: themeMode))
                            .clipShape(Capsule())
                            .shadow(color: .white.opacity(0.75), radius: 3, x: -1, y: -1)
                            .shadow(color: .black.opacity(0.08), radius: 5, x: 2, y: 2)
                    }
                    .buttonStyle(.plain)
                }

                compactCard(width: rowWidth)
                    .offset(x: -actionReveal)
                    .animation(.easeOut(duration: 0.18), value: actionReveal)
            }
            .frame(width: rowWidth, height: 72)
        }
        .frame(height: 72)
    }

    private func compactCard(width: CGFloat) -> some View {
        JellyCard(shadowStyle: .listItem) {
            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(item.title)
                        .font(.system(size: 21, weight: .bold, design: .rounded))
                        .foregroundStyle(ThemeTokens.Colors.textPrimary)
                        .lineLimit(1)
                        .strikethrough(item.isCompleted, color: ThemeTokens.Colors.textPrimary)
                        .opacity(item.isCompleted ? 0.55 : 1)

                    if showsDate {
                        Text(item.taskDate.formattedMonthDay())
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundStyle(ThemeTokens.Colors.textSecondary)
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 6) {
                    Text(item.cycle.title)
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(ThemeTokens.Colors.textSecondary)
                        .lineLimit(1)

                    HStack(spacing: 6) {
                        compactInfoPill("\(item.dailyDurationMinutes)m")
                        compactInfoPill(item.focusTimerDirection.shortTitle)
                    }
                }
            }
            .padding(.horizontal, 18)
            .frame(width: width, height: 72)
        }
        .contentShape(RoundedRectangle(cornerRadius: ThemeTokens.Metrics.cornerRadius, style: .continuous))
        .simultaneousGesture(addTodayDragGesture())
        .onTapGesture {
            if actionReveal > 0 {
                actionReveal = 0
            } else {
                onTap?()
            }
        }
    }

    private func addTodayDragGesture() -> some Gesture {
        DragGesture(minimumDistance: 18, coordinateSpace: .local)
            .onChanged { value in
                guard actionWidth > 0 else { return }
                if dragStartActionReveal == 0 {
                    dragStartActionReveal = actionReveal
                }
                guard abs(value.translation.width) > abs(value.translation.height) * 1.2 else { return }
                actionReveal = min(max(dragStartActionReveal - value.translation.width, 0), actionWidth)
            }
            .onEnded { _ in
                guard actionWidth > 0 else { return }
                actionReveal = actionReveal > 42 ? actionWidth : 0
                dragStartActionReveal = 0
            }
    }

    private func compactInfoPill(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 12, weight: .bold, design: .rounded))
            .foregroundStyle(ThemeTokens.Colors.textSecondary)
            .lineLimit(1)
            .padding(.horizontal, 8)
            .frame(height: 24)
            .background(ThemeTokens.Colors.backgroundPrimary.opacity(0.82))
            .clipShape(Capsule())
    }
}

private enum DragAxis: Equatable {
    case undetermined
    case horizontal
    case vertical
}

struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}
