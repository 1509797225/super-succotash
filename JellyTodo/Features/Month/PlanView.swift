import SwiftUI

struct PlanView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.appLanguage) private var language
    @Environment(\.appTextScale) private var textScale
    @State private var showingNewTask = false
    @State private var addingItemTaskID: UUID?
    @State private var editingTodo: TodoItem?
    @State private var editingPlan: PlanTask?
    @State private var pendingArchivePlan: PlanTask?
    @State private var pendingDeletePlan: PlanTask?
    @State private var selectedTodo: TodoItem?
    @State private var focusTodoID: UUID?
    @State private var feedbackMessage: String?

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            ThemeTokens.background(for: store.settings.themeMode)
                .ignoresSafeArea()

            List {
                if store.planSections.isEmpty {
                    Text(L10n.t(.noPlansYet, language))
                        .font(ThemeTokens.Typography.sectionTitle(for: textScale))
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
                                    showAddTodayFeedback(store.addTodoToToday(id: item.id))
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
                                .frame(height: ThemeTokens.Metrics.controlHeight(for: textScale) - 4)
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
            .padding(.trailing, ThemeTokens.Metrics.horizontalPadding(for: textScale))
            .padding(.bottom, 18)

            if let feedbackMessage {
                VStack {
                    Text(feedbackMessage)
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(ThemeTokens.Colors.textPrimary)
                        .padding(.horizontal, 18)
                        .frame(height: 46)
                        .background(ThemeTokens.card(for: store.settings.themeMode))
                        .clipShape(Capsule())
                        .shadow(color: .black.opacity(0.08), radius: 14, x: 0, y: 8)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.top, 10)
                .transition(.move(edge: .top).combined(with: .opacity))
                .zIndex(4)
            }
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
                        scheduleMode: result.scheduleMode,
                        recurrenceValue: result.recurrenceValue,
                        scheduledDates: result.scheduledDates,
                        dailyDurationMinutes: result.dailyDurationMinutes,
                        focusTimerDirection: result.focusTimerDirection,
                        note: result.note
                    )
                }
            }
        }
        .sheet(item: $selectedTodo) { todo in
	            TaskActionSheet(todo: todo) { todo in
	                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
	                    focusTodoID = store.prepareFocusTodoID(for: todo.id)
	                }
	            }
        }
        .sheet(item: $editingTodo) { todo in
            TodoEditorSheet(title: L10n.t(.editTask, language), todo: todo, confirmTitle: L10n.t(.save, language)) { result in
                store.updateTodo(id: todo.id, title: result.title)
                store.updateTodoDetail(
                    id: todo.id,
                    scheduleMode: result.scheduleMode,
                    recurrenceValue: result.recurrenceValue,
                    scheduledDates: result.scheduledDates,
                    dailyDurationMinutes: result.dailyDurationMinutes,
                    focusTimerDirection: result.focusTimerDirection,
                    note: result.note
                )
            }
        }
        .sheet(item: $editingPlan) { plan in
            TodoEditorSheet(
                title: language == .english ? "Edit Plan" : "编辑计划",
                initialText: plan.title,
                confirmTitle: L10n.t(.save, language)
            ) { title in
                store.updatePlanTask(id: plan.id, title: title)
            }
        }
        .alert(
            language == .english ? "Archive this plan?" : "归档这个计划？",
            isPresented: Binding(
                get: { pendingArchivePlan != nil },
                set: { if !$0 { pendingArchivePlan = nil } }
            )
        ) {
            Button(language == .english ? "Archive" : "归档") {
                if let pendingArchivePlan {
                    store.archivePlanTask(id: pendingArchivePlan.id)
                }
                pendingArchivePlan = nil
            }
            Button(L10n.t(.cancel, language), role: .cancel) {
                pendingArchivePlan = nil
            }
        } message: {
            Text(language == .english ? "Archived plans are hidden from Plan." : "归档后会从 Plan 页隐藏。")
        }
        .alert(
            language == .english ? "Delete this plan?" : "删除这个计划？",
            isPresented: Binding(
                get: { pendingDeletePlan != nil },
                set: { if !$0 { pendingDeletePlan = nil } }
            )
        ) {
            Button(L10n.t(.delete, language), role: .destructive) {
                if let pendingDeletePlan {
                    store.deletePlanTask(id: pendingDeletePlan.id)
                }
                pendingDeletePlan = nil
            }
            Button(L10n.t(.cancel, language), role: .cancel) {
                pendingDeletePlan = nil
            }
        } message: {
            Text(language == .english ? "Its plan items and generated Today items will be removed." : "该计划下的 item 和已生成的 Today 任务会一起移除。")
        }
    }

    private func planHeader(_ section: PlanTaskSection) -> some View {
        let progress = store.planProgress(for: section)

        return PlanHeaderRow(
            section: section,
            progress: progress,
            subtitle: planSubtitle(progress),
            todayValue: "\(progress.completedTodayItems)/\(max(progress.todayItems, 0))",
            weekValue: focusText(progress.weeklyFocusSeconds),
            itemsValue: "\(progress.totalItems)",
            themeMode: store.settings.themeMode,
            language: language,
            textScale: textScale
        ) {
            editingPlan = section.task
        } onToggleCollapse: {
            store.togglePlanTaskCollapsed(id: section.task.id)
        } onArchive: {
            pendingArchivePlan = section.task
        } onDelete: {
            pendingDeletePlan = section.task
        }
    }

    private func rowInsets(
        top: CGFloat = 0,
        bottom: CGFloat = 0,
        leading: CGFloat? = nil
    ) -> EdgeInsets {
        EdgeInsets(
            top: top,
            leading: leading ?? ThemeTokens.Metrics.horizontalPadding(for: textScale),
            bottom: bottom == 0 ? ThemeTokens.Metrics.cardSpacing(for: textScale) : bottom,
            trailing: ThemeTokens.Metrics.horizontalPadding(for: textScale)
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

    private func planSubtitle(_ progress: PlanProgress) -> String {
        switch language {
        case .english:
            return "\(itemsCountText(progress.totalItems)) · \(Int(progress.todayCompletionRate * 100))% today"
        case .chinese:
            return "\(itemsCountText(progress.totalItems)) · 今日完成 \(Int(progress.todayCompletionRate * 100))%"
        }
    }

    private func focusText(_ seconds: Int) -> String {
        if seconds < 3600 {
            return "\(max(seconds / 60, 0))m"
        }
        let hours = Double(seconds) / 3600
        return String(format: "%.1fh", hours)
    }

    private func showAddTodayFeedback(_ result: PlanAddTodayResult) {
        let message: String
        switch result {
        case .added:
            message = language == .english ? "Added to Today" : "已加入 Today"
        case .alreadyExists:
            message = language == .english ? "Already in Today" : "Today 已存在"
        case .missing:
            message = language == .english ? "Item not found" : "事项不存在"
        }

        withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
            feedbackMessage = message
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            guard feedbackMessage == message else { return }
            withAnimation(.easeOut(duration: 0.2)) {
                feedbackMessage = nil
            }
        }
    }
}

private struct PlanHeaderRow: View {
    let section: PlanTaskSection
    let progress: PlanProgress
    let subtitle: String
    let todayValue: String
    let weekValue: String
    let itemsValue: String
    let themeMode: AppThemeMode
    let language: AppLanguage
    let textScale: AppTextScale
    let onEdit: () -> Void
    let onToggleCollapse: () -> Void
    let onArchive: () -> Void
    let onDelete: () -> Void

    @State private var actionReveal: CGFloat = 0
    @State private var dragStartActionReveal: CGFloat = 0
    @State private var dragAxis: PlanHeaderDragAxis = .undetermined
    @State private var hasCapturedDragStart = false

    private let actionWidth: CGFloat = 164

    private var isExpanded: Bool {
        !section.task.isCollapsed
    }

    private var headerHeight: CGFloat {
        let base = ThemeTokens.Metrics.cardHeight(for: textScale)
        return base + (isExpanded ? 34 : 0)
    }

    private var expansionAnimation: Animation {
        .spring(response: 0.38, dampingFraction: 0.9)
    }

    var body: some View {
        ZStack(alignment: .trailing) {
            actionButtons
                .frame(width: actionWidth, alignment: .trailing)

            headerCard
                .offset(x: -actionReveal)
                .animation(.easeOut(duration: 0.18), value: actionReveal)
        }
        .frame(height: headerHeight)
        .animation(expansionAnimation, value: section.task.isCollapsed)
    }

    private var headerCard: some View {
        JellyCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 14) {
                    Button {
                        if actionReveal > 0 {
                            closeActionsIfNeeded()
                        } else {
                            onEdit()
                        }
                    } label: {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(section.task.title)
                                .font(ThemeTokens.Typography.taskTitle(for: textScale))
                                .foregroundStyle(ThemeTokens.Colors.textPrimary)
                                .lineLimit(1)

                            Text(subtitle)
                                .font(.system(size: 15, weight: .bold, design: .rounded))
                                .foregroundStyle(ThemeTokens.Colors.textSecondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.plain)

                    Spacer()

                    Button {
                        closeActionsIfNeeded()
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
                            onToggleCollapse()
                        }
                    } label: {
                        Image(systemName: section.task.isCollapsed ? "chevron.down" : "chevron.up")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(ThemeTokens.Colors.textSecondary)
                            .frame(width: 42, height: 42)
                            .background(ThemeTokens.Colors.backgroundPrimary.opacity(0.72))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                }

                metricStrip
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
        .frame(maxWidth: .infinity)
        .frame(height: headerHeight)
        .animation(expansionAnimation, value: section.task.isCollapsed)
        .contentShape(RoundedRectangle(cornerRadius: ThemeTokens.Metrics.cornerRadius * textScale.layoutScale, style: .continuous))
        .simultaneousGesture(planDragGesture())
    }

    private var metricStrip: some View {
        HStack(spacing: 9) {
            planMetric(title: language == .english ? "Today" : "今日", value: todayValue)
            planMetricDivider
            planMetric(title: language == .english ? "Week" : "本周", value: weekValue)
            planMetricDivider
            planMetric(title: language == .english ? "Items" : "事项", value: itemsValue)
            Spacer(minLength: 0)
        }
        .padding(.top, isExpanded ? 2 : 0)
        .frame(height: isExpanded ? 24 : 0, alignment: .top)
        .opacity(isExpanded ? 1 : 0)
        .offset(y: isExpanded ? 0 : -8)
        .scaleEffect(isExpanded ? 1 : 0.96, anchor: .topLeading)
        .clipped()
        .allowsHitTesting(isExpanded)
        .animation(expansionAnimation, value: section.task.isCollapsed)
    }

    private func planMetric(title: String, value: String) -> some View {
        HStack(spacing: 4) {
            Text(title)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(ThemeTokens.Colors.textSecondary.opacity(0.78))

            Text(value)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(ThemeTokens.Colors.textPrimary.opacity(0.78))
                .lineLimit(1)
        }
    }

    private var planMetricDivider: some View {
        Circle()
            .fill(ThemeTokens.Colors.textSecondary.opacity(0.24))
            .frame(width: 4, height: 4)
    }

    private var actionButtons: some View {
        HStack(spacing: 8) {
            actionButton(title: language == .english ? "Archive" : "归档") {
                closeActionsIfNeeded()
                onArchive()
            }

            actionButton(title: L10n.t(.delete, language)) {
                closeActionsIfNeeded()
                onDelete()
            }
        }
        .padding(.trailing, 2)
    }

    private func actionButton(title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(ThemeTokens.Typography.caption(for: textScale))
                .foregroundStyle(ThemeTokens.Colors.textPrimary)
                .frame(width: 74, height: 72)
                .background(ThemeTokens.card(for: themeMode))
                .clipShape(Capsule())
                .shadow(color: .white.opacity(0.8), radius: 4, x: -2, y: -2)
                .shadow(color: .black.opacity(0.1), radius: 6, x: 2, y: 2)
        }
        .buttonStyle(.plain)
    }

    private func planDragGesture() -> some Gesture {
        DragGesture(minimumDistance: 18, coordinateSpace: .local)
            .onChanged { value in
                captureDragStartIfNeeded()
                updateDragAxisIfNeeded(value)

                guard dragAxis == .horizontal else { return }
                actionReveal = min(max(dragStartActionReveal - value.translation.width, 0), actionWidth)
            }
            .onEnded { _ in
                defer { resetDragTracking() }
                guard dragAxis == .horizontal else { return }
                settleActionReveal()
            }
    }

    private func captureDragStartIfNeeded() {
        guard !hasCapturedDragStart else { return }
        hasCapturedDragStart = true
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

    private func settleActionReveal() {
        let shouldStayOpen = actionReveal > min(actionWidth * 0.42, 68)
        actionReveal = shouldStayOpen ? actionWidth : 0
    }

    private func closeActionsIfNeeded() {
        guard actionReveal > 0 else { return }
        actionReveal = 0
    }

    private func resetDragTracking() {
        hasCapturedDragStart = false
        dragStartActionReveal = 0
        dragAxis = .undetermined
    }
}

private enum PlanHeaderDragAxis: Equatable {
    case undetermined
    case horizontal
    case vertical
}
