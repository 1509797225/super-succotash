import SwiftUI

struct MonthView: View {
    @EnvironmentObject private var store: AppStore
    @State private var showingNewTask = false
    @State private var editingTodo: TodoItem?
    @State private var selectedTodo: TodoItem?
    @State private var focusTodoID: UUID?

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            ThemeTokens.background(for: store.settings.themeMode)
                .ignoresSafeArea()

            List {
                if store.monthSections.isEmpty {
                    Text("No tasks this month")
                        .font(ThemeTokens.Typography.sectionTitle)
                        .foregroundStyle(ThemeTokens.Colors.textSecondary)
                        .frame(maxWidth: .infinity, minHeight: 320, alignment: .center)
                        .listRowInsets(rowInsets(top: 24, bottom: 0))
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                } else {
                    ForEach(Array(store.monthSections.enumerated()), id: \.element.id) { sectionOffset, section in
                        Text(section.date.formattedMonthDay())
                            .font(ThemeTokens.Typography.sectionTitle)
                            .foregroundStyle(ThemeTokens.Colors.textPrimary)
                            .listRowInsets(rowInsets(top: sectionOffset == 0 ? 24 : 8, bottom: 18))
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)

                        ForEach(Array(section.items.enumerated()), id: \.element.id) { offset, todo in
                            TodoRow(index: offset + 1, item: todo, themeMode: store.settings.themeMode) {
                                selectedTodo = todo
                            } onEdit: {
                                editingTodo = todo
                            } onDelete: {
                                store.deleteTodo(id: todo.id)
                            } onSwipeComplete: {
                                if !todo.isCompleted {
                                    store.toggleTodoCompleted(id: todo.id)
                                }
                            }
                            .listRowInsets(rowInsets(top: 0))
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                        }
                    }
                }

                Color.clear
                    .frame(height: 90)
                    .listRowInsets(EdgeInsets())
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
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
        .navigationTitle("Month")
        .navigationBarTitleDisplayMode(.large)
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

    private func rowInsets(top: CGFloat = 0, bottom: CGFloat = ThemeTokens.Metrics.cardSpacing) -> EdgeInsets {
        EdgeInsets(
            top: top,
            leading: ThemeTokens.Metrics.horizontalPadding,
            bottom: bottom,
            trailing: ThemeTokens.Metrics.horizontalPadding
        )
    }
}
