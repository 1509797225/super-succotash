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
            VStack(spacing: 24) {
                Text(todo.title)
                    .font(ThemeTokens.Typography.taskTitle)
                    .foregroundStyle(ThemeTokens.Colors.textPrimary)
                    .lineLimit(3)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .strikethrough(todo.isCompleted, color: ThemeTokens.Colors.textPrimary)
                    .padding(.top, 6)

                CapsuleButton(title: "Start Focus", minWidth: 180) {
                    dismiss()
                    onStartFocus(todo)
                }

                HStack(spacing: 16) {
                    CapsuleButton(title: "Edit") {
                        showingEditor = true
                    }

                    CapsuleButton(title: "Delete") {
                        store.deleteTodo(id: todo.id)
                        dismiss()
                    }
                }

                Button {
                    durationUnit = durationUnit.next
                } label: {
                    VStack(spacing: 8) {
                        Text("Focused")
                            .font(ThemeTokens.Typography.caption)
                            .foregroundStyle(ThemeTokens.Colors.textSecondary)

                        Text(durationUnit.format(seconds: store.focusedSeconds(for: todo.id)))
                            .font(.system(size: 34, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(ThemeTokens.Colors.textPrimary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(ThemeTokens.card(for: store.settings.themeMode))
                    .clipShape(RoundedRectangle(cornerRadius: ThemeTokens.Metrics.cornerRadius, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
        .presentationDetents([.height(430)])
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
                    if isLandscape {
                        HStack(spacing: 28) {
                            clockBlock(todo, isLandscape: true)
                            controlBlock(todo)
                        }
                        .padding(28)
                    } else {
                        VStack(spacing: 34) {
                            clockBlock(todo, isLandscape: false)
                            controlBlock(todo)
                        }
                        .padding(.horizontal, ThemeTokens.Metrics.horizontalPadding)
                        .padding(.vertical, 28)
                    }
                } else {
                    Text("Task deleted")
                        .font(ThemeTokens.Typography.sectionTitle)
                        .foregroundStyle(ThemeTokens.Colors.textSecondary)
                }

                VStack {
                    HStack {
                        Spacer()
                        JellyToolMenu(isExpanded: $isToolMenuExpanded, actions: toolMenuActions)
                    }
                    Spacer()
                }
                .padding(.top, 12)
                .padding(.trailing, 12)
                .zIndex(10)
            }
        }
        .navigationTitle("Focus")
        .navigationBarTitleDisplayMode(.inline)
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
            return isLandscape ? 112 : 96
        }
        return isLandscape ? 82 : 68
    }

    private var toolMenuActions: [JellyToolMenuAction] {
        [
            JellyToolMenuAction(
                id: "orientation",
                title: isLandscapeLocked ? "Portrait" : "Land",
                systemImage: isLandscapeLocked ? "rectangle.portrait" : "rectangle.landscape",
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
    }

    private func toggleOrientation() {
        isLandscapeLocked.toggle()
#if canImport(UIKit)
        OrientationLock.rotate(to: isLandscapeLocked ? .landscapeRight : .portrait)
#endif
    }
}
