import SwiftUI

struct PlanView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.appLanguage) private var language
    @State private var showingNewTask = false
    @State private var addingItemTaskID: UUID?
    @State private var editingTodo: TodoItem?
    @State private var selectedTodo: TodoItem?
    @State private var focusTodoID: UUID?

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            ThemeTokens.background(for: store.settings.themeMode)
                .ignoresSafeArea()

            List {
                if store.planSections.isEmpty {
                    Text(L10n.t(.noPlansYet, language))
                        .font(ThemeTokens.Typography.sectionTitle)
                        .foregroundStyle(ThemeTokens.Colors.textSecondary)
                        .frame(maxWidth: .infinity, minHeight: 320, alignment: .center)
                        .listRowInsets(rowInsets(top: 24, bottom: 0))
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                } else {
                    ForEach(Array(store.planSections.enumerated()), id: \.element.id) { offset, section in
                        planHeader(section)
                            .listRowInsets(rowInsets(top: offset == 0 ? 24 : 10, bottom: 14))
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)

                        if !section.task.isCollapsed {
                            ForEach(section.items) { item in
                                CompactTodoRow(
                                    item: item,
                                    themeMode: store.settings.themeMode,
                                    showsDate: true
                                ) {
                                    selectedTodo = item
                                } onAddToday: {
                                    store.addTodoToToday(id: item.id)
                                }
                                .listRowInsets(rowInsets(top: 0, bottom: 12, leading: 32))
                                .listRowSeparator(.hidden)
                                .listRowBackground(Color.clear)
                            }

                            Button {
                                addingItemTaskID = section.task.id
                            } label: {
                                HStack {
                                    Image(systemName: "plus")
                                    Text(L10n.t(.addItem, language))
                                }
                                .font(.system(size: 18, weight: .bold, design: .rounded))
                                .foregroundStyle(ThemeTokens.Colors.textSecondary)
                                .frame(maxWidth: .infinity)
                                .frame(height: 54)
                                .background(ThemeTokens.card(for: store.settings.themeMode).opacity(0.72))
                                .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                            .listRowInsets(rowInsets(top: 0, bottom: 18, leading: 32))
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

            CapsuleButton(title: L10n.t(.newPlan, language), minWidth: 120) {
                showingNewTask = true
            }
            .padding(.trailing, ThemeTokens.Metrics.horizontalPadding)
            .padding(.bottom, 18)
        }
        .navigationTitle(L10n.t(.plan, language))
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
            TodoEditorSheet(title: L10n.t(.newPlan, language), confirmTitle: L10n.t(.confirm, language)) { title in
                store.addPlanTask(title: title)
            }
        }
        .sheet(
            isPresented: Binding(
                get: { addingItemTaskID != nil },
                set: { isPresented in
                    if !isPresented {
                        addingItemTaskID = nil
                    }
                }
            )
        ) {
            TodoEditorSheet(title: L10n.t(.newItem, language), confirmTitle: L10n.t(.add, language), showsFocusSettings: true) { result in
                if let addingItemTaskID {
                    store.addPlanItem(
                        title: result.title,
                        to: addingItemTaskID,
                        cycle: result.cycle,
                        dailyDurationMinutes: result.dailyDurationMinutes,
                        focusTimerDirection: result.focusTimerDirection
                    )
                }
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
            TodoEditorSheet(title: L10n.t(.editTask, language), todo: todo, confirmTitle: L10n.t(.save, language)) { result in
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

    private func planHeader(_ section: PlanTaskSection) -> some View {
        Button {
            store.togglePlanTaskCollapsed(id: section.task.id)
        } label: {
            JellyCard {
                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(section.task.title)
                            .font(ThemeTokens.Typography.taskTitle)
                            .foregroundStyle(ThemeTokens.Colors.textPrimary)
                            .lineLimit(1)

                        Text(itemsCountText(section.items.count))
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundStyle(ThemeTokens.Colors.textSecondary)
                    }

                    Spacer()

                    Image(systemName: section.task.isCollapsed ? "chevron.down" : "chevron.up")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(ThemeTokens.Colors.textSecondary)
                }
                .padding(.horizontal, 20)
                .frame(height: 92)
            }
        }
        .buttonStyle(.plain)
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

    private func itemsCountText(_ count: Int) -> String {
        switch language {
        case .english:
            return count == 1 ? "1 item" : "\(count) items"
        case .chinese:
            return "\(count) 个事项"
        }
    }
}
