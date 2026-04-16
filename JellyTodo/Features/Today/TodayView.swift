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

            ScrollView {
                VStack(alignment: .leading, spacing: ThemeTokens.Metrics.sectionSpacing) {
                    if store.todayTodos.isEmpty {
                        Text("Today is clear")
                            .font(ThemeTokens.Typography.sectionTitle)
                            .foregroundStyle(ThemeTokens.Colors.textSecondary)
                            .frame(maxWidth: .infinity, minHeight: 320, alignment: .center)
                    } else {
                        LazyVStack(spacing: ThemeTokens.Metrics.cardSpacing) {
                            ForEach(Array(store.todayTodos.enumerated()), id: \.element.id) { offset, todo in
                                TodoRow(index: offset + 1, item: todo) {
                                    detailTodoID = todo.id
                                } onLongPress: {
                                    store.toggleTodoCompleted(id: todo.id)
                                } onEdit: {
                                    editingTodo = todo
                                } onDelete: {
                                    store.deleteTodo(id: todo.id)
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, ThemeTokens.Metrics.horizontalPadding)
                .padding(.top, 24)
                .padding(.bottom, 110)
            }

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
}
