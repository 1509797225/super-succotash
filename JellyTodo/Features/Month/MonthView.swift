import SwiftUI

struct MonthView: View {
    @EnvironmentObject private var store: AppStore
    @State private var showingNewTask = false
    @State private var editingTodo: TodoItem?

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            ThemeTokens.background(for: store.settings.themeMode)
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    if store.monthSections.isEmpty {
                        Text("No tasks this month")
                            .font(ThemeTokens.Typography.sectionTitle)
                            .foregroundStyle(ThemeTokens.Colors.textSecondary)
                            .frame(maxWidth: .infinity, minHeight: 320, alignment: .center)
                    } else {
                        ForEach(store.monthSections) { section in
                            VStack(alignment: .leading, spacing: 18) {
                                Text(section.date.formattedMonthDay())
                                    .font(ThemeTokens.Typography.sectionTitle)
                                    .foregroundStyle(ThemeTokens.Colors.textPrimary)

                                LazyVStack(spacing: ThemeTokens.Metrics.cardSpacing) {
                                    ForEach(Array(section.items.enumerated()), id: \.element.id) { offset, todo in
                                        TodoRow(index: offset + 1, item: todo) {
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
        .navigationTitle("Month")
        .navigationBarTitleDisplayMode(.large)
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
