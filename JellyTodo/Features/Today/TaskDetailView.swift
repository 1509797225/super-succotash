import SwiftUI

struct TaskDetailView: View {
    @EnvironmentObject private var store: AppStore
    let todoID: UUID

    @State private var cycle: TodoTaskCycle = .daily
    @State private var dailyDurationMinutes = 25
    @State private var note = ""
    @State private var hasLoadedState = false

    private var todo: TodoItem? {
        store.todos.first { $0.id == todoID }
    }

    var body: some View {
        ZStack {
            ThemeTokens.background(for: store.settings.themeMode)
                .ignoresSafeArea()

            if let todo {
                ScrollView {
                    VStack(alignment: .leading, spacing: ThemeTokens.Metrics.sectionSpacing) {
                        headerCard(todo)
                        cycleSection
                        durationSection
                        bodySection
                    }
                    .padding(.horizontal, ThemeTokens.Metrics.horizontalPadding)
                    .padding(.top, 24)
                    .padding(.bottom, 24)
                }
            } else {
                Text("Task deleted")
                    .font(ThemeTokens.Typography.sectionTitle)
                    .foregroundStyle(ThemeTokens.Colors.textSecondary)
            }
        }
        .navigationTitle("Task")
        .navigationBarTitleDisplayMode(.large)
        .safeAreaInset(edge: .bottom) {
            if let todo {
                pomodoroEntry(todo)
            }
        }
        .onAppear {
            if let todo, !hasLoadedState {
                syncLocalState(from: todo)
                hasLoadedState = true
            }
        }
        .onChange(of: note) { _ in
            saveDetail()
        }
    }

    private func headerCard(_ todo: TodoItem) -> some View {
        JellyCard {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top, spacing: 16) {
                    Text(todo.title)
                        .font(ThemeTokens.Typography.pageTitle)
                        .foregroundStyle(ThemeTokens.Colors.textPrimary)
                        .lineLimit(3)
                        .strikethrough(todo.isCompleted, color: ThemeTokens.Colors.textPrimary)

                    Spacer()

                    Circle()
                        .strokeBorder(ThemeTokens.Colors.textSecondary, lineWidth: 2)
                        .background(
                            Circle()
                                .fill(todo.isCompleted ? ThemeTokens.Colors.textPrimary : .clear)
                        )
                        .frame(width: 34, height: 34)
                }

                HStack {
                    Text(todo.taskDate.formatted(.dateTime.month(.abbreviated).day()))
                    Spacer()
                    Text(todo.isCompleted ? "Completed" : "Active")
                }
                .font(ThemeTokens.Typography.body)
                .foregroundStyle(ThemeTokens.Colors.textSecondary)
            }
            .padding(24)
        }
    }

    private var cycleSection: some View {
        SectionCard(title: "Task Cycle") {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(TodoTaskCycle.allCases) { item in
                    Button {
                        cycle = item
                        saveDetail()
                    } label: {
                        Text(item.title)
                            .font(ThemeTokens.Typography.body)
                            .foregroundStyle(cycle == item ? ThemeTokens.Colors.backgroundPrimary : ThemeTokens.Colors.textPrimary)
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .background(cycle == item ? ThemeTokens.Colors.textPrimary : ThemeTokens.Colors.backgroundPrimary)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var durationSection: some View {
        SectionCard(title: "Daily Duration") {
            HStack(spacing: 18) {
                durationButton(systemName: "minus") {
                    dailyDurationMinutes = max(5, dailyDurationMinutes - 5)
                    saveDetail()
                }

                VStack(spacing: 6) {
                    Text("\(dailyDurationMinutes)")
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .foregroundStyle(ThemeTokens.Colors.textPrimary)

                    Text("minutes / day")
                        .font(ThemeTokens.Typography.body)
                        .foregroundStyle(ThemeTokens.Colors.textSecondary)
                }
                .frame(maxWidth: .infinity)

                durationButton(systemName: "plus") {
                    dailyDurationMinutes = min(480, dailyDurationMinutes + 5)
                    saveDetail()
                }
            }
        }
    }

    private var bodySection: some View {
        SectionCard(title: "Body") {
            ZStack(alignment: .topLeading) {
                if note.isEmpty {
                    Text("Write task notes here")
                        .font(ThemeTokens.Typography.body)
                        .foregroundStyle(ThemeTokens.Colors.textSecondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 10)
                }

                TextEditor(text: $note)
                    .font(ThemeTokens.Typography.body)
                    .foregroundStyle(ThemeTokens.Colors.textPrimary)
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 210)
                    .background(Color.clear)
            }
        }
    }

    private func durationButton(systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(ThemeTokens.Colors.textPrimary)
                .frame(width: 54, height: 54)
                .background(ThemeTokens.Colors.backgroundPrimary)
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
    }

    private func pomodoroEntry(_ todo: TodoItem) -> some View {
        NavigationLink {
            PomodoroStatsView(initialRelatedTodoID: todo.id)
        } label: {
            Text("Enter Pomodoro")
                .font(ThemeTokens.Typography.body)
                .foregroundStyle(ThemeTokens.Colors.backgroundPrimary)
                .frame(maxWidth: .infinity)
                .frame(height: ThemeTokens.Metrics.controlHeight)
                .background(ThemeTokens.Colors.textPrimary)
                .clipShape(Capsule())
                .padding(.horizontal, ThemeTokens.Metrics.horizontalPadding)
                .padding(.top, 12)
                .padding(.bottom, 12)
                .background(ThemeTokens.background(for: store.settings.themeMode).opacity(0.96))
        }
        .buttonStyle(.plain)
    }

    private func syncLocalState(from todo: TodoItem) {
        cycle = todo.cycle
        dailyDurationMinutes = todo.dailyDurationMinutes
        note = todo.note
    }

    private func saveDetail() {
        guard hasLoadedState else { return }
        store.updateTodoDetail(
            id: todoID,
            cycle: cycle,
            dailyDurationMinutes: dailyDurationMinutes,
            note: note
        )
    }
}
