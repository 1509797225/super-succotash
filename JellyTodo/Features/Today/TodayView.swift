import SwiftUI

struct TodayView: View {
    @EnvironmentObject private var store: AppStore
    @State private var showingNewTask = false
    @State private var editingTodo: TodoItem?
    @State private var detailTodoID: UUID?

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            ThemeTokens.background(for: store.settings.themeMode)
                .ignoresSafeArea()

            List {
                if store.todayTodos.isEmpty {
                    Text("Today is clear")
                        .font(ThemeTokens.Typography.sectionTitle)
                        .foregroundStyle(ThemeTokens.Colors.textSecondary)
                        .frame(maxWidth: .infinity, minHeight: 320, alignment: .center)
                        .listRowInsets(rowInsets(top: 24, bottom: 0))
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                } else {
                    ForEach(Array(store.todayTodos.enumerated()), id: \.element.id) { offset, todo in
                        TodoRow(index: offset + 1, item: todo, themeMode: store.settings.themeMode) {
                            detailTodoID = todo.id
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
                        .listRowInsets(rowInsets(top: offset == 0 ? 24 : 0))
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
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
        .navigationTitle("Today")
        .navigationBarTitleDisplayMode(.large)
        .navigationDestination(
            isPresented: Binding(
                get: { detailTodoID != nil },
                set: { isPresented in
                    if !isPresented {
                        detailTodoID = nil
                    }
                }
            )
        ) {
            if let detailTodoID {
                TaskDetailView(todoID: detailTodoID)
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
        .sheet(item: $editingTodo) { todo in
            TodoEditorSheet(title: "Edit Task", initialText: todo.title, confirmTitle: "Save") { text in
                store.updateTodo(id: todo.id, title: text)
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
