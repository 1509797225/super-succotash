import SwiftUI

struct TaskActionSheet: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss

    let todo: TodoItem
    let onStartFocus: (TodoItem) -> Void

    @State private var showingEditor = false
    @State private var durationUnit: FocusDurationUnit = .minutes

    var body: some View {
        BottomSheetContainer(title: "Task") {
            VStack(spacing: 20) {
                taskSummaryCard
                focusedDurationCard
                editDeleteRow
            }
        }
        .presentationDetents([.height(460)])
        .presentationDragIndicator(.hidden)
        .sheet(isPresented: $showingEditor) {
            TodoEditorSheet(title: "Edit Task", todo: latestTodo, confirmTitle: "Save") { result in
                store.updateTodo(id: todo.id, title: result.title)
                store.updateTodoDetail(
                    id: todo.id,
                    cycle: result.cycle,
                    dailyDurationMinutes: result.dailyDurationMinutes,
                    focusTimerDirection: result.focusTimerDirection,
                    note: latestTodo.note
                )
            }
        }
    }

    private var latestTodo: TodoItem {
        store.todos.first { $0.id == todo.id } ?? todo
    }

    private var taskSummaryCard: some View {
        JellyCard {
            VStack(spacing: 18) {
                HStack(spacing: 8) {
                    taskMetaPill(title: todo.cycle.title)
                    taskMetaPill(title: "\(todo.dailyDurationMinutes) min")
                    taskMetaPill(title: todo.focusTimerDirection.shortTitle)
                }

                Text(todo.title)
                    .font(ThemeTokens.Typography.taskTitle)
                    .foregroundStyle(ThemeTokens.Colors.textPrimary)
                    .lineLimit(3)
                    .minimumScaleFactor(0.82)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .strikethrough(todo.isCompleted, color: ThemeTokens.Colors.textPrimary)

                focusButton
            }
            .padding(20)
        }
    }

    private var focusButton: some View {
        Button {
            dismiss()
            onStartFocus(todo)
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "play.fill")
                    .font(.system(size: 20, weight: .bold))
                Text("Start Focus")
                    .font(ThemeTokens.Typography.body)
            }
            .foregroundStyle(ThemeTokens.Colors.backgroundPrimary)
            .frame(maxWidth: .infinity)
            .frame(height: ThemeTokens.Metrics.controlHeight)
            .background(ThemeTokens.Colors.textPrimary)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private var editDeleteRow: some View {
        HStack(spacing: 14) {
            actionPill(title: "Edit", systemImage: "square.and.pencil") {
                showingEditor = true
            }

            actionPill(title: "Delete", systemImage: "trash") {
                store.deleteTodo(id: todo.id)
                dismiss()
            }
        }
    }

    private var focusedDurationCard: some View {
        Button {
            durationUnit = durationUnit.next
        } label: {
            JellyCard {
                VStack(spacing: 8) {
                    Text("Focused")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(ThemeTokens.Colors.textSecondary)

                    Text(durationUnit.format(seconds: store.focusedSeconds(for: todo.id)))
                        .font(.system(size: 42, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(ThemeTokens.Colors.textPrimary)
                        .lineLimit(1)

                    Text("tap h / min / s")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(ThemeTokens.Colors.textSecondary.opacity(0.75))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
            }
        }
        .buttonStyle(.plain)
    }

    private func taskMetaPill(title: String) -> some View {
        Text(title)
            .font(.system(size: 14, weight: .bold, design: .rounded))
            .foregroundStyle(ThemeTokens.Colors.textSecondary)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .frame(maxWidth: .infinity)
            .frame(height: 34)
            .background(ThemeTokens.Colors.backgroundPrimary.opacity(0.8))
            .clipShape(Capsule())
    }

    private func actionPill(title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: systemImage)
                    .font(.system(size: 16, weight: .bold))
                Text(title)
                    .font(ThemeTokens.Typography.body)
            }
            .foregroundStyle(ThemeTokens.Colors.textPrimary)
            .frame(maxWidth: .infinity)
            .frame(height: ThemeTokens.Metrics.controlHeight)
            .background(ThemeTokens.card(for: store.settings.themeMode))
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

private enum FocusDurationUnit {
    case hours
    case minutes
    case seconds

    var next: FocusDurationUnit {
        switch self {
        case .hours:
            return .minutes
        case .minutes:
            return .seconds
        case .seconds:
            return .hours
        }
    }

    func format(seconds: Int) -> String {
        switch self {
        case .hours:
            return String(format: "%.1f h", Double(seconds) / 3600)
        case .minutes:
            return "\(max(seconds / 60, 0)) min"
        case .seconds:
            return "\(max(seconds, 0)) s"
        }
    }
}

struct FocusSessionView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss

    let todoID: UUID

    @State private var hasStarted = false
    @State private var usesHugeClock = true
    @State private var isLandscapeLocked = false
    @State private var isToolMenuExpanded = false
    @State private var isImmersiveMode = false

    private var todo: TodoItem? {
        store.todos.first { $0.id == todoID }
    }

    var body: some View {
        GeometryReader { proxy in
            let isLandscape = proxy.size.width > proxy.size.height

            ZStack {
                ThemeTokens.background(for: store.settings.themeMode)
                    .ignoresSafeArea()

                if let todo {
                    if isLandscape && isImmersiveMode {
                        immersiveLandscapeLayout(todo)
                    } else if isLandscape {
                        landscapeFocusLayout(todo)
                    } else {
                        portraitFocusLayout(todo)
                    }
                } else {
                    Text("Task deleted")
                        .font(ThemeTokens.Typography.sectionTitle)
                        .foregroundStyle(ThemeTokens.Colors.textSecondary)
                }

                if isLandscape && isImmersiveMode {
                    immersiveExitButton
                } else {
                    VStack {
                        HStack {
                            Spacer()
                            JellyToolMenu(isExpanded: $isToolMenuExpanded, actions: toolMenuActions(isLandscape: isLandscape))
                        }
                        Spacer()
                    }
                    .padding(.top, 12)
                    .padding(.trailing, 12)
                    .zIndex(10)
                }
            }
        }
        .navigationTitle("Focus")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(isImmersiveMode ? .hidden : .visible, for: .navigationBar)
        .toolbar((isLandscapeLocked || isImmersiveMode) ? .hidden : .visible, for: .tabBar)
        .onAppear {
#if canImport(UIKit)
            OrientationLock.rotate(to: .portrait)
#endif
            guard !hasStarted, let todo else { return }
            hasStarted = true
            store.startPomodoro(
                mode: .focus,
                relatedTodoID: todo.id,
                durationSeconds: max(todo.dailyDurationMinutes, 1) * 60,
                direction: todo.focusTimerDirection
            )
        }
        .onDisappear {
#if canImport(UIKit)
            OrientationLock.set(.portrait)
#endif
            isImmersiveMode = false
        }
    }

    private func portraitFocusLayout(_ todo: TodoItem) -> some View {
        VStack(spacing: 34) {
            clockBlock(todo, isLandscape: false)
            controlBlock(todo)
        }
        .padding(.horizontal, ThemeTokens.Metrics.horizontalPadding)
        .padding(.vertical, 28)
    }

    private func landscapeFocusLayout(_ todo: TodoItem) -> some View {
        VStack(spacing: 18) {
            Spacer(minLength: 0)

            clockBlock(todo, isLandscape: true)
                .padding(.horizontal, 86)

            compactControlBar
                .padding(.bottom, 18)
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 18)
    }

    private func immersiveLandscapeLayout(_ todo: TodoItem) -> some View {
        ZStack {
            ThemeTokens.background(for: store.settings.themeMode)
                .ignoresSafeArea()

            Text(store.timerState.displaySeconds.formattedClock())
                .font(.system(size: immersiveClockFontSize, weight: .bold, design: .rounded))
                .monospacedDigit()
                .minimumScaleFactor(0.42)
                .lineLimit(1)
                .foregroundStyle(ThemeTokens.Colors.textPrimary)
                .padding(.horizontal, 42)
        }
    }

    private func clockBlock(_ todo: TodoItem, isLandscape: Bool) -> some View {
        VStack(spacing: isLandscape ? 16 : 24) {
            Text(todo.title)
                .font(ThemeTokens.Typography.sectionTitle)
                .foregroundStyle(ThemeTokens.Colors.textSecondary)
                .lineLimit(2)
                .multilineTextAlignment(.center)

            Text(store.timerState.displaySeconds.formattedClock())
                .font(.system(size: clockFontSize(isLandscape: isLandscape), weight: .bold, design: .rounded))
                .monospacedDigit()
                .minimumScaleFactor(0.55)
                .lineLimit(1)
                .foregroundStyle(ThemeTokens.Colors.textPrimary)
                .frame(maxWidth: .infinity)

            Text("\(todo.focusTimerDirection.title) · \(todo.dailyDurationMinutes) min")
                .font(ThemeTokens.Typography.body)
                .foregroundStyle(ThemeTokens.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var compactControlBar: some View {
        HStack(spacing: 16) {
            Text(statusText)
                .font(ThemeTokens.Typography.caption)
                .foregroundStyle(ThemeTokens.Colors.textSecondary)
                .frame(width: 92, alignment: .leading)

            ProgressView(value: store.timerState.progress)
                .tint(ThemeTokens.accent(for: store.settings.themeMode))
                .frame(width: 132)

            if store.timerState.isRunning {
                compactControlButton(title: "Pause") {
                    store.pausePomodoro()
                }
            } else if store.timerState.isPaused {
                compactControlButton(title: "Resume") {
                    store.resumePomodoro()
                }
            }

            compactControlButton(title: "Stop") {
                store.stopPomodoro(discard: true)
                dismiss()
            }
        }
        .padding(.horizontal, 18)
        .frame(height: 58)
        .background(ThemeTokens.card(for: store.settings.themeMode).opacity(0.94))
        .clipShape(Capsule())
        .modifier(JellyCardModifier(shadowStyle: .standard))
    }

    private func controlBlock(_ todo: TodoItem) -> some View {
        JellyCard {
            VStack(spacing: 18) {
                Text(statusText)
                    .font(ThemeTokens.Typography.sectionTitle)
                    .foregroundStyle(ThemeTokens.Colors.textPrimary)

                ProgressView(value: store.timerState.progress)
                    .tint(ThemeTokens.accent(for: store.settings.themeMode))

                HStack(spacing: 14) {
                    if store.timerState.isRunning {
                        CapsuleButton(title: "Pause") {
                            store.pausePomodoro()
                        }
                    } else if store.timerState.isPaused {
                        CapsuleButton(title: "Resume") {
                            store.resumePomodoro()
                        }
                    }

                    CapsuleButton(title: "Stop") {
                        store.stopPomodoro(discard: true)
                        dismiss()
                    }
                }
            }
            .padding(24)
        }
        .frame(maxWidth: 420)
    }

    private func compactControlButton(title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(ThemeTokens.Colors.textPrimary)
                .frame(minWidth: 74)
                .frame(height: 42)
                .background(ThemeTokens.Colors.backgroundPrimary.opacity(0.88))
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private var immersiveExitButton: some View {
        VStack {
            HStack {
                Spacer()

                Button {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                        isImmersiveMode = false
                    }
                } label: {
                    Text("Exit")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(ThemeTokens.Colors.textPrimary)
                        .frame(width: 86, height: 48)
                        .background(ThemeTokens.card(for: store.settings.themeMode).opacity(0.94))
                        .clipShape(Capsule())
                        .modifier(JellyCardModifier(shadowStyle: .standard))
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
        .padding(.top, 16)
        .padding(.trailing, 20)
        .zIndex(12)
    }

    private var statusText: String {
        if store.timerState.isRunning {
            return "Focusing"
        }
        if store.timerState.isPaused {
            return "Paused"
        }
        return "Ready"
    }

    private func clockFontSize(isLandscape: Bool) -> CGFloat {
        if usesHugeClock {
            return isLandscape ? 138 : 96
        }
        return isLandscape ? 104 : 68
    }

    private var immersiveClockFontSize: CGFloat {
        usesHugeClock ? 168 : 126
    }

    private func toolMenuActions(isLandscape: Bool) -> [JellyToolMenuAction] {
        var actions = [
            JellyToolMenuAction(
                id: "orientation",
                title: isLandscapeLocked ? "Stand" : "Rotate",
                systemImage: isLandscapeLocked ? "rotate.left.fill" : "rotate.right.fill",
                isActive: isLandscapeLocked
            ) {
                toggleOrientation()
            },
            JellyToolMenuAction(
                id: "clock-size",
                title: usesHugeClock ? "Small" : "Huge",
                systemImage: usesHugeClock ? "textformat.size.smaller" : "textformat.size.larger",
                isActive: usesHugeClock
            ) {
                usesHugeClock.toggle()
            }
        ]

        if isLandscape {
            actions.append(
                JellyToolMenuAction(
                    id: "immersive",
                    title: "Immersive",
                    systemImage: "viewfinder",
                    isActive: isImmersiveMode
                ) {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                        isImmersiveMode = true
                        isToolMenuExpanded = false
                    }
                }
            )
        }

        return actions
    }

    private func toggleOrientation() {
        isLandscapeLocked.toggle()
        if !isLandscapeLocked {
            isImmersiveMode = false
        }
#if canImport(UIKit)
        OrientationLock.rotate(to: isLandscapeLocked ? .landscapeRight : .portrait)
#endif
    }
}
