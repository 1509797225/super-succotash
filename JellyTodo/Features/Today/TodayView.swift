import SwiftUI

private enum TodayDisplayMode: String, CaseIterable, Identifiable {
    case today = "Today"
    case month = "Month"

    var id: String { rawValue }
}

struct TodayView: View {
    @EnvironmentObject private var store: AppStore
    @Binding var tabTitle: String
    @State private var showingNewTask = false
    @State private var editingTodo: TodoItem?
    @State private var selectedTodo: TodoItem?
    @State private var focusTodoID: UUID?
    @State private var displayMode: TodayDisplayMode = .today
    @State private var collapsedDates: Set<Date> = []

    init(tabTitle: Binding<String> = .constant("Today")) {
        _tabTitle = tabTitle
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            ThemeTokens.background(for: store.settings.themeMode)
                .ignoresSafeArea()

            List {
                modePickerRow

                switch displayMode {
                case .today:
                    todayRows
                case .month:
                    monthRows
                }

                bottomSpacerRow
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .environment(\.defaultMinListRowHeight, 0)

            CapsuleButton(title: "New Task", minWidth: 120) {
                showingNewTask = true
            }
            .padding(.trailing, ThemeTokens.Metrics.horizontalPadding)
            .padding(.bottom, 18)
        }
        .navigationTitle(displayMode.rawValue)
        .navigationBarTitleDisplayMode(.large)
        .onAppear {
            tabTitle = displayMode.rawValue
        }
        .onChange(of: displayMode) { mode in
            tabTitle = mode.rawValue
        }
        .navigationDestination(
            isPresented: Binding(
                get: { focusTodoID != nil },
                set: { isPresented in
                    if !isPresented {
                        focusTodoID = nil
                    }
                }
            )
        ) {
            if let focusTodoID {
                FocusSessionView(todoID: focusTodoID)
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink {
                    PomodoroStatsView()
                } label: {
                    Image(systemName: "chart.pie.fill")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(ThemeTokens.Colors.textPrimary)
                }
            }
        }
        .sheet(isPresented: $showingNewTask) {
            TodoEditorSheet(title: "New Task", confirmTitle: "Confirm") { text in
                store.addTodo(title: text, taskDate: Date())
            }
        }
        .sheet(item: $selectedTodo) { todo in
            TaskActionSheet(todo: todo) { todo in
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                    focusTodoID = todo.id
                }
            }
        }
        .sheet(item: $editingTodo) { todo in
            TodoEditorSheet(title: "Edit Task", todo: todo, confirmTitle: "Save") { result in
                store.updateTodo(id: todo.id, title: result.title)
                store.updateTodoDetail(
                    id: todo.id,
                    cycle: result.cycle,
                    dailyDurationMinutes: result.dailyDurationMinutes,
                    focusTimerDirection: result.focusTimerDirection,
                    note: todo.note
                )
            }
        }
    }

    @ViewBuilder
    private var todayRows: some View {
        if store.todayTodos.isEmpty {
            Text("Today is clear")
                .font(ThemeTokens.Typography.sectionTitle)
                .foregroundStyle(ThemeTokens.Colors.textSecondary)
                .frame(maxWidth: .infinity, minHeight: 280, alignment: .center)
                .listRowInsets(rowInsets(top: 18, bottom: 0))
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
        } else {
            ForEach(Array(store.todayTodos.enumerated()), id: \.element.id) { offset, todo in
                TodoRow(index: offset + 1, item: todo, themeMode: store.settings.themeMode) {
                    selectedTodo = todo
                } onLongPress: {
                    store.toggleTodoCompleted(id: todo.id)
                } onEdit: {
                    editingTodo = todo
                } onDelete: {
                    store.deleteTodo(id: todo.id)
                } onSwipeComplete: {
                    if !todo.isCompleted {
                        store.toggleTodoCompleted(id: todo.id)
                    }
                }
                .listRowInsets(rowInsets(top: offset == 0 ? 16 : 0))
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
            }
        }
    }

    @ViewBuilder
    private var monthRows: some View {
        let sections = store.monthSections(for: Date(), compact: true)

        if sections.isEmpty {
            Text("No tasks this month")
                .font(ThemeTokens.Typography.sectionTitle)
                .foregroundStyle(ThemeTokens.Colors.textSecondary)
                .frame(maxWidth: .infinity, minHeight: 280, alignment: .center)
                .listRowInsets(rowInsets(top: 18, bottom: 0))
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
        } else {
            ForEach(Array(sections.enumerated()), id: \.element.id) { offset, section in
                monthHeader(section)
                    .listRowInsets(rowInsets(top: offset == 0 ? 16 : 8, bottom: 12))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)

                if !collapsedDates.contains(section.date) {
                    ForEach(section.items) { todo in
                        CompactTodoRow(
                            item: todo,
                            themeMode: store.settings.themeMode,
                            showsDate: false
                        ) {
                            selectedTodo = todo
                        }
                        .listRowInsets(rowInsets(top: 0, bottom: 12, leading: 24))
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                    }
                }
            }
        }
    }

    private var modePickerRow: some View {
        HStack(spacing: 8) {
            ForEach(TodayDisplayMode.allCases) { mode in
                Button {
                    displayMode = mode
                } label: {
                    Text(mode.rawValue)
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(displayMode == mode ? ThemeTokens.Colors.backgroundPrimary : ThemeTokens.Colors.textPrimary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(displayMode == mode ? ThemeTokens.accent(for: store.settings.themeMode) : ThemeTokens.card(for: store.settings.themeMode))
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .listRowInsets(rowInsets(top: 10, bottom: 8))
        .listRowSeparator(.hidden)
        .listRowBackground(Color.clear)
    }

    private func monthHeader(_ section: TodoDaySection) -> some View {
        Button {
            if collapsedDates.contains(section.date) {
                collapsedDates.remove(section.date)
            } else {
                collapsedDates.insert(section.date)
            }
        } label: {
            HStack {
                Text(section.date.formattedMonthDay())
                    .font(ThemeTokens.Typography.sectionTitle)
                    .foregroundStyle(ThemeTokens.Colors.textPrimary)

                Spacer()

                Text("\(section.items.count)")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(ThemeTokens.Colors.textSecondary)

                Image(systemName: collapsedDates.contains(section.date) ? "chevron.down" : "chevron.up")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(ThemeTokens.Colors.textSecondary)
            }
            .padding(.horizontal, 18)
            .frame(height: 62)
            .background(ThemeTokens.card(for: store.settings.themeMode))
            .clipShape(RoundedRectangle(cornerRadius: ThemeTokens.Metrics.cornerRadius, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var bottomSpacerRow: some View {
        Color.clear
            .frame(height: 90)
            .listRowInsets(EdgeInsets())
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
    }

    private func rowInsets(
        top: CGFloat = 0,
        bottom: CGFloat = ThemeTokens.Metrics.cardSpacing,
        leading: CGFloat = ThemeTokens.Metrics.horizontalPadding
    ) -> EdgeInsets {
        EdgeInsets(
            top: top,
            leading: leading,
            bottom: bottom,
            trailing: ThemeTokens.Metrics.horizontalPadding
        )
    }
}
