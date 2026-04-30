import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct TodayView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.appLanguage) private var language
    @Environment(\.appTextScale) private var textScale
    @AppStorage("today.checkinBanner.dismissedDayKey") private var dismissedCheckInBannerDayKey = ""
    @State private var showingNewTask = false
    @State private var editingTodo: TodoItem?
    @State private var selectedTodo: TodoItem?
    @State private var focusTodoID: UUID?
    @State private var hasShownCheckInPromptForCurrentDay = false

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            ThemeTokens.background(for: store.settings.themeMode)
                .ignoresSafeArea()

            List {
                todayRows
                bottomSpacerRow
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .environment(\.defaultMinListRowHeight, 0)

            floatingActionStack
                .padding(.trailing, ThemeTokens.Metrics.horizontalPadding(for: textScale))
                .padding(.bottom, 18)
                .zIndex(4)

            if shouldShowCheckInPromptModal {
                checkInPromptModal
                    .zIndex(6)
                    .transition(.opacity.combined(with: .scale(scale: 0.96)))
            }
        }
        .navigationTitle(L10n.t(.today, language))
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
            TodoEditorSheet(title: L10n.t(.newTask, language), confirmTitle: L10n.t(.confirm, language)) { text in
                store.addTodo(title: text, taskDate: Date())
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
        .sheet(
            isPresented: Binding(
                get: { store.isCheckInSheetPresented },
                set: { isPresented in
                    if !isPresented {
                        store.dismissCheckInCelebration()
                    }
                }
            )
        ) {
            if let date = store.presentedCheckInDate {
                CheckInSheet(date: date)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .todayCheckInMockActivated)) { _ in
            dismissedCheckInBannerDayKey = ""
            hasShownCheckInPromptForCurrentDay = false
        }
        .onAppear {
            if dismissedCheckInBannerDayKey != todayBannerDayKey {
                hasShownCheckInPromptForCurrentDay = false
            }
        }
        .onChange(of: todayBannerDayKey) { _ in
            hasShownCheckInPromptForCurrentDay = false
        }
        .onChange(of: shouldShowCheckInPromptModal) { isShowing in
            if isShowing {
                hasShownCheckInPromptForCurrentDay = true
            }
        }
    }

    @ViewBuilder
    private var todayRows: some View {
        if store.todayTodos.isEmpty {
            Text(L10n.t(.todayIsClear, language))
                .font(ThemeTokens.Typography.sectionTitle(for: textScale))
                .foregroundStyle(ThemeTokens.Colors.textSecondary)
                .frame(maxWidth: .infinity, minHeight: 320, alignment: .center)
                .listRowInsets(rowInsets(top: 24, bottom: 0))
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
                .listRowInsets(rowInsets(top: offset == 0 ? 24 : 0))
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
            }
        }
    }

    private var checkInPromptModal: some View {
        ZStack {
            Rectangle()
                .fill(.ultraThinMaterial)
                .overlay(Color.black.opacity(0.08))
                .ignoresSafeArea()
                .onTapGesture {
                    postponeCheckInPrompt()
                }

            JellyCard {
                VStack(spacing: 18) {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    ThemeTokens.accentSoft(for: store.settings.themeMode).opacity(store.settings.themeMode.isJelly ? 0.88 : 0.66),
                                    ThemeTokens.accent(for: store.settings.themeMode).opacity(store.settings.themeMode.isJelly ? 0.94 : 0.78)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 76, height: 76)
                        .overlay(
                            Image(systemName: "sparkles")
                                .font(.system(size: 28, weight: .black))
                                .foregroundStyle(.white)
                        )
                        .shadow(color: ThemeTokens.accent(for: store.settings.themeMode).opacity(0.2), radius: 16, x: 0, y: 10)

                    VStack(spacing: 8) {
                        Text(language == .chinese ? "恭喜你，今日的任务已全部完成" : "All of today's tasks are done")
                            .font(.system(size: 21 * textScale.typographyScale, weight: .bold, design: .rounded))
                            .foregroundStyle(ThemeTokens.Colors.textPrimary)
                            .multilineTextAlignment(.center)

                        Text(language == .chinese ? "去完成今天的打卡，留下一枚专属表情。" : "Check in now and leave today's badge.")
                            .font(ThemeTokens.Typography.caption(for: textScale))
                            .foregroundStyle(ThemeTokens.Colors.textSecondary)
                            .multilineTextAlignment(.center)
                    }

                    HStack(spacing: 12) {
                        CapsuleButton(
                            title: language == .chinese ? "待会儿再去" : "Later",
                            fill: ThemeTokens.card(for: store.settings.themeMode),
                            foreground: ThemeTokens.Colors.textPrimary,
                            minWidth: 136
                        ) {
                            postponeCheckInPrompt()
                        }

                        CapsuleButton(
                            title: language == .chinese ? "去打卡" : "Check In",
                            fill: ThemeTokens.accent(for: store.settings.themeMode),
                            foreground: .white,
                            minWidth: 136
                        ) {
                            store.presentTodayCheckIn()
                        }
                    }
                }
                .padding(22)
            }
            .frame(maxWidth: 356)
            .padding(.horizontal, 20)
        }
    }

    private var floatingActionStack: some View {
        VStack(alignment: .trailing, spacing: 10) {
            if shouldShowFloatingCheckInEntry {
                CapsuleButton(
                    title: hasCheckedInToday
                        ? (language == .chinese ? "查看打卡" : "View Check-in")
                        : (language == .chinese ? "去打卡" : "Check In"),
                    fill: ThemeTokens.accent(for: store.settings.themeMode),
                    foreground: .white,
                    minWidth: 120
                ) {
                    if hasCheckedInToday {
                        store.presentCheckInSheet(for: Date())
                    } else {
                        store.presentTodayCheckIn()
                    }
                }
                .shadow(color: .black.opacity(0.12), radius: 12, x: 0, y: 7)
            }

            CapsuleButton(title: L10n.t(.newTask, language), minWidth: 120) {
                showingNewTask = true
            }
            .shadow(color: .black.opacity(0.12), radius: 12, x: 0, y: 7)
        }
    }

    private var hasCompletedAllTodayTasks: Bool {
        let summary = store.todayCheckInSummary()
        return summary.total > 0 && summary.completed == summary.total
    }

    private var hasCheckedInToday: Bool {
        store.hasCheckedIn(on: Date())
    }

    private var shouldShowCheckInBanner: Bool {
        hasCompletedAllTodayTasks
    }

    private var todayBannerDayKey: String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar.current
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Calendar.current.startOfDay(for: Date()))
    }

    private var shouldShowCheckInPromptModal: Bool {
        shouldShowCheckInBanner
            && !hasCheckedInToday
            && dismissedCheckInBannerDayKey != todayBannerDayKey
            && !store.isCheckInSheetPresented
    }

    private var shouldShowFloatingCheckInEntry: Bool {
        shouldShowCheckInBanner
    }

    private func postponeCheckInPrompt() {
        dismissedCheckInBannerDayKey = todayBannerDayKey
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
        bottom: CGFloat = 0
    ) -> EdgeInsets {
        EdgeInsets(
            top: top,
            leading: ThemeTokens.Metrics.horizontalPadding(for: textScale),
            bottom: bottom == 0 ? ThemeTokens.Metrics.cardSpacing(for: textScale) : bottom,
            trailing: ThemeTokens.Metrics.horizontalPadding(for: textScale)
        )
    }
}

private struct CheckInSheet: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.appThemeMode) private var themeMode
    @Environment(\.appLanguage) private var language
    @Environment(\.appTextScale) private var textScale
    @Environment(\.dismiss) private var dismiss

    let date: Date
    @State private var displayMonth: Date = Date()
    @State private var showingSharePreview = false
    @State private var shareImage: UIImage?

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 7)

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 18) {
                checkInCalendarCard
                heroCheckInCard
                statsRow
                actionRow
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 28)
        }
        .background(ThemeTokens.background(for: themeMode).ignoresSafeArea())
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .onAppear {
            displayMonth = date
        }
        .sheet(
            isPresented: Binding(
                get: { shareImage != nil },
                set: { isPresented in
                    if !isPresented {
                        shareImage = nil
                    }
                }
            )
        ) {
            if let shareImage {
                ActivityShareSheet(items: [shareImage])
            }
        }
        .sheet(isPresented: $showingSharePreview) {
            CheckInSharePreviewSheet(
                themeMode: themeMode,
                language: language,
                textScale: textScale,
                shareCardView: { shareCardView(exportMode: false) },
                onShare: { prepareShareCard() }
            )
        }
    }

    private var record: DailyCheckInRecord? {
        store.checkInRecord(on: date)
    }

    private var checkInCalendarCard: some View {
        JellyCard {
            VStack(spacing: 16) {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(L10n.t(.monthlyCheckIn, language))
                            .font(ThemeTokens.Typography.sectionTitle(for: textScale))
                            .foregroundStyle(ThemeTokens.Colors.textPrimary)

                        Text(monthTitle)
                            .font(.system(size: 16 * textScale.typographyScale, weight: .bold, design: .rounded))
                            .foregroundStyle(ThemeTokens.Colors.textSecondary)
                    }

                    Spacer()

                    HStack(spacing: 10) {
                        monthSwitchButton(systemName: "chevron.left", offset: -1)
                        Text("\(monthSummaryCount)")
                            .font(.system(size: 14 * textScale.typographyScale, weight: .bold, design: .rounded))
                            .foregroundStyle(ThemeTokens.accent(for: themeMode))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .background(
                                Capsule(style: .continuous)
                                    .fill(ThemeTokens.accentSoft(for: themeMode).opacity(themeMode.isJelly ? 0.38 : 0.2))
                            )
                        monthSwitchButton(systemName: "chevron.right", offset: 1)
                    }
                }

                LazyVGrid(columns: columns, spacing: 10) {
                    ForEach(weekdaySymbols, id: \.self) { symbol in
                        Text(symbol)
                            .font(.system(size: 12 * textScale.typographyScale, weight: .bold, design: .rounded))
                            .foregroundStyle(ThemeTokens.Colors.textSecondary)
                            .frame(maxWidth: .infinity)
                    }

                    ForEach(monthDays) { day in
                        checkInDayCell(day)
                    }
                }
            }
            .padding(18)
        }
    }

    private var heroCheckInCard: some View {
        JellyCard {
            VStack(spacing: 16) {
                Text(record == nil ? (language == .chinese ? "今天待打卡" : "Ready to Check In") : L10n.t(.checkedInToday, language))
                    .font(.system(size: 18 * textScale.typographyScale, weight: .bold, design: .rounded))
                    .foregroundStyle(ThemeTokens.Colors.textSecondary)

                ZStack {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    .white.opacity(themeMode.isJelly ? 0.95 : 0.8),
                                    ThemeTokens.accentSoft(for: themeMode).opacity(themeMode.isJelly ? 0.82 : 0.58),
                                    ThemeTokens.accent(for: themeMode).opacity(themeMode.isJelly ? 0.96 : 0.8)
                                ],
                                center: .topLeading,
                                startRadius: 12,
                                endRadius: 94
                            )
                        )
                        .frame(width: 156, height: 156)
                        .overlay(
                            Circle()
                                .strokeBorder(.white.opacity(0.8), lineWidth: 2.5)
                                .padding(4)
                        )
                        .shadow(color: ThemeTokens.accent(for: themeMode).opacity(0.26), radius: 18, x: 0, y: 16)

                    Circle()
                        .fill(.white.opacity(themeMode.isJelly ? 0.38 : 0.18))
                        .frame(width: 88, height: 88)
                        .blur(radius: 10)
                        .offset(x: -18, y: -26)

                    checkInIconImage(for: date, size: 124)
                        .clipShape(Circle())
                        .opacity(record == nil ? 0.52 : 1)
                        .overlay(
                            Circle()
                                .stroke(.white.opacity(0.18), lineWidth: 1)
                        )
                }

                VStack(spacing: 8) {
                    Text(record == nil ? "\(daySummary.completed)/\(daySummary.total)" : "\(store.currentCheckInStreak)")
                        .font(.system(size: 48 * textScale.typographyScale, weight: .bold, design: .rounded))
                        .foregroundStyle(ThemeTokens.Colors.textPrimary)
                        .contentTransition(.numericText())

                    Text(record == nil ? (language == .chinese ? "已完成任务" : "Tasks done") : L10n.t(.checkInDays, language))
                        .font(ThemeTokens.Typography.caption(for: textScale))
                        .foregroundStyle(ThemeTokens.Colors.textSecondary)
                        .multilineTextAlignment(.center)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 18)
            .padding(.vertical, 24)
        }
    }

    private var statsRow: some View {
        HStack(spacing: 12) {
            statCard(title: L10n.t(.completed, language), value: "\(daySummary.completed)")
            statCard(title: L10n.t(.totalTasks, language), value: "\(daySummary.total)")
            statCard(title: L10n.t(.focusTime, language), value: daySummary.focusSeconds.formattedMinutesText())
        }
    }

    private var actionRow: some View {
        HStack(spacing: 12) {
            if record == nil {
                CapsuleButton(
                    title: language == .chinese ? "待会儿再去" : "Later"
                ) {
                    dismiss()
                    store.dismissCheckInCelebration()
                }

                CapsuleButton(
                    title: language == .chinese ? "完成打卡" : "Complete Check-in",
                    fill: ThemeTokens.accent(for: themeMode),
                    foreground: .white
                ) {
                    store.completeCheckIn(on: date, isMakeUp: false, triggerPresentation: true)
                }
            } else {
                CapsuleButton(title: L10n.t(.checkedInToday, language)) {
                    dismiss()
                    store.dismissCheckInCelebration()
                }

                if store.latestMakeUpCandidate != nil {
                    CapsuleButton(
                        title: L10n.t(.makeUpCheckIn, language),
                        fill: ThemeTokens.accent(for: themeMode),
                        foreground: .white
                    ) {
                        store.makeUpLatestMissedDay()
                    }
                } else {
                    CapsuleButton(
                        title: L10n.t(.shareCard, language),
                        fill: ThemeTokens.accent(for: themeMode),
                        foreground: .white
                    ) {
                        showingSharePreview = true
                    }
                }
            }
        }
    }

    private func statCard(title: String, value: String) -> some View {
        JellyCard {
            VStack(spacing: 8) {
                Text(value)
                    .font(.system(size: 24 * textScale.typographyScale, weight: .bold, design: .rounded))
                    .foregroundStyle(ThemeTokens.Colors.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text(title)
                    .font(ThemeTokens.Typography.caption(for: textScale))
                    .foregroundStyle(ThemeTokens.Colors.textSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
        }
    }

    @ViewBuilder
    private func checkInDayCell(_ day: CheckInCalendarDay) -> some View {
        if let date = day.date {
            let isChecked = day.record != nil
            VStack(spacing: 4) {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(isChecked ? cellGradient : uncheckedCellFill)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(day.isToday ? ThemeTokens.accent(for: themeMode) : .white.opacity(themeMode.isJelly ? 0.4 : 0), lineWidth: day.isToday ? 1.8 : 0.8)
                    )
                    .overlay(alignment: .topLeading) {
                        if isChecked {
                            Circle()
                                .fill(.white.opacity(themeMode.isJelly ? 0.55 : 0.2))
                                .frame(width: 12, height: 12)
                                .blur(radius: 1.2)
                                .offset(x: 8, y: 6)
                        }
                    }
                    .overlay {
                        if isChecked {
                            checkInIconImage(for: date, size: 32)
                                .clipShape(Circle())
                                .padding(4)
                        } else {
                            VStack(spacing: 2) {
                                Text("\(Calendar.current.component(.day, from: date))")
                                    .font(.system(size: 14 * textScale.typographyScale, weight: .heavy, design: .rounded))
                                    .foregroundStyle(ThemeTokens.Colors.textSecondary)

                                if day.isMakeUpAvailable {
                                    Image(systemName: "plus")
                                        .font(.system(size: 9, weight: .black))
                                        .foregroundStyle(ThemeTokens.Colors.textSecondary)
                                }
                            }
                        }
                    }
            }
            .frame(height: 46)
        } else {
            Color.clear.frame(height: 46)
        }
    }

    private func monthSwitchButton(systemName: String, offset: Int) -> some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.9)) {
                displayMonth = Calendar.current.date(byAdding: .month, value: offset, to: displayMonth) ?? displayMonth
            }
        } label: {
            Image(systemName: systemName)
                .font(.system(size: 14, weight: .black))
                .foregroundStyle(ThemeTokens.Colors.textPrimary)
                .frame(width: 36, height: 36)
                .background(
                    Circle()
                        .fill(ThemeTokens.card(for: themeMode))
                        .overlay(
                            Circle()
                                .stroke(.white.opacity(themeMode.isJelly ? 0.46 : 0), lineWidth: 1)
                        )
                )
        }
        .buttonStyle(.plain)
    }

    private var monthTitle: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: language.localeIdentifier)
        formatter.dateFormat = language == .english ? "MMMM yyyy" : "yyyy年M月"
        return formatter.string(from: displayMonth)
    }

    private var monthDays: [CheckInCalendarDay] {
        store.monthCheckInDays(for: displayMonth)
    }

    private var monthSummaryCount: String {
        let checkedCount = monthDays.filter { $0.record != nil }.count
        let totalCount = monthDays.compactMap(\.date).count
        if language == .english {
            return "\(checkedCount)/\(totalCount) days"
        }
        return "\(checkedCount)/\(totalCount)天"
    }

    private var daySummary: (completed: Int, total: Int, focusSeconds: Int) {
        store.todayCheckInSummary(for: date)
    }

    private func prepareShareCard() {
#if canImport(UIKit)
        let renderer = ImageRenderer(content: shareCardView(exportMode: true))
        renderer.scale = UIScreen.main.scale
        renderer.proposedSize = .init(width: 1080, height: 1600)
        shareImage = renderer.uiImage
#endif
    }

    @ViewBuilder
    private func shareCardView(exportMode: Bool) -> some View {
        let cardWidth: CGFloat = exportMode ? 1080 : 320
        let innerPadding: CGFloat = exportMode ? 52 : 20
        let crownSize: CGFloat = exportMode ? 168 : 92
        let dateFont: CGFloat = exportMode ? 28 : 14
        let titleFont: CGFloat = exportMode ? 86 : 26
        let bigNumber: CGFloat = exportMode ? 148 : 40
        let smallLabel: CGFloat = exportMode ? 28 : 12
        let statValue: CGFloat = exportMode ? 42 : 18
        let statLabel: CGFloat = exportMode ? 22 : 10
        let spacing: CGFloat = exportMode ? 26 : 12
        let compactDays = monthDays.filter { $0.date != nil }
        let cardMonthDays = Array(compactDays.prefix(35))

        ZStack {
            RoundedRectangle(cornerRadius: exportMode ? 72 : 32, style: .continuous)
                .fill(cardBackgroundGradient)
                .overlay(
                    RoundedRectangle(cornerRadius: exportMode ? 72 : 32, style: .continuous)
                        .stroke(.white.opacity(themeMode.isJelly ? 0.72 : 0.24), lineWidth: exportMode ? 3 : 1.2)
                )
                .shadow(color: .white.opacity(themeMode.isJelly ? 0.88 : 0.24), radius: exportMode ? 12 : 5, x: -3, y: -3)
                .shadow(color: ThemeTokens.accent(for: themeMode).opacity(themeMode.isJelly ? 0.18 : 0.08), radius: exportMode ? 28 : 14, x: 0, y: 20)
                .shadow(color: .black.opacity(themeMode.isJelly ? 0.08 : 0.06), radius: exportMode ? 24 : 12, x: 0, y: 16)

            Circle()
                .fill(.white.opacity(themeMode.isJelly ? 0.32 : 0.14))
                .frame(width: exportMode ? 340 : 120, height: exportMode ? 340 : 120)
                .blur(radius: exportMode ? 24 : 10)
                .offset(x: exportMode ? -220 : -70, y: exportMode ? -250 : -84)

            Circle()
                .fill(ThemeTokens.accentSoft(for: themeMode).opacity(themeMode.isJelly ? 0.5 : 0.18))
                .frame(width: exportMode ? 420 : 140, height: exportMode ? 420 : 140)
                .blur(radius: exportMode ? 30 : 14)
                .offset(x: exportMode ? 240 : 84, y: exportMode ? 260 : 100)

            VStack(alignment: .leading, spacing: spacing) {
                VStack(alignment: .leading, spacing: exportMode ? 12 : 6) {
                    Text(shareCardDateTitle)
                        .font(.system(size: dateFont, weight: .bold, design: .rounded))
                        .foregroundStyle(ThemeTokens.Colors.textSecondary)

                    Text(L10n.t(.checkedInToday, language))
                        .font(.system(size: titleFont, weight: .black, design: .rounded))
                        .foregroundStyle(ThemeTokens.Colors.textPrimary)
                }

                HStack(alignment: .center, spacing: exportMode ? 36 : 16) {
                    ZStack {
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [
                                        .white.opacity(themeMode.isJelly ? 0.94 : 0.76),
                                        ThemeTokens.accentSoft(for: themeMode).opacity(themeMode.isJelly ? 0.84 : 0.56),
                                        ThemeTokens.accent(for: themeMode).opacity(themeMode.isJelly ? 0.96 : 0.76)
                                    ],
                                    center: .topLeading,
                                    startRadius: exportMode ? 14 : 6,
                                    endRadius: exportMode ? 108 : 54
                                )
                            )
                            .frame(width: crownSize, height: crownSize)
                        Circle()
                            .stroke(.white.opacity(0.82), lineWidth: exportMode ? 4 : 1.8)
                            .padding(exportMode ? 6 : 3)
                            .frame(width: crownSize, height: crownSize)
                        checkInIconImage(for: date, size: exportMode ? 136 : 74)
                            .clipShape(Circle())
                    }

                    VStack(alignment: .leading, spacing: exportMode ? 10 : 4) {
                        Text("\(store.currentCheckInStreak)")
                            .font(.system(size: bigNumber, weight: .black, design: .rounded))
                            .foregroundStyle(ThemeTokens.Colors.textPrimary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.65)
                        Text(L10n.t(.checkInDays, language))
                            .font(.system(size: smallLabel, weight: .bold, design: .rounded))
                            .foregroundStyle(ThemeTokens.Colors.textSecondary)
                    }
                    Spacer(minLength: 0)
                }

                VStack(alignment: .leading, spacing: exportMode ? 18 : 8) {
                    Text(monthTitle)
                        .font(.system(size: exportMode ? 34 : 15, weight: .bold, design: .rounded))
                        .foregroundStyle(ThemeTokens.Colors.textPrimary)

                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: exportMode ? 12 : 6), count: 7), spacing: exportMode ? 12 : 6) {
                        ForEach(weekdaySymbols, id: \.self) { symbol in
                            Text(symbol)
                                .font(.system(size: exportMode ? 18 : 9, weight: .bold, design: .rounded))
                                .foregroundStyle(ThemeTokens.Colors.textSecondary)
                                .frame(maxWidth: .infinity)
                        }

                        ForEach(cardMonthDays) { day in
                            shareCardDayCell(day: day, exportMode: exportMode)
                        }
                    }
                }

                HStack(spacing: exportMode ? 18 : 8) {
                    shareStatCard(value: "\(daySummary.completed)", title: L10n.t(.completed, language), valueFont: statValue, titleFont: statLabel, exportMode: exportMode)
                    shareStatCard(value: "\(daySummary.total)", title: L10n.t(.totalTasks, language), valueFont: statValue, titleFont: statLabel, exportMode: exportMode)
                    shareStatCard(value: daySummary.focusSeconds.formattedMinutesText(), title: L10n.t(.focusTime, language), valueFont: statValue, titleFont: statLabel, exportMode: exportMode)
                }

                Text("JellyTodo")
                    .font(.system(size: exportMode ? 26 : 11, weight: .bold, design: .rounded))
                    .foregroundStyle(ThemeTokens.Colors.textSecondary.opacity(exportMode ? 0.92 : 0.72))
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .padding(innerPadding)
        }
        .frame(width: cardWidth)
        .aspectRatio(exportMode ? 0.72 : 0.74, contentMode: .fit)
    }

    private func shareCardDayCell(day: CheckInCalendarDay, exportMode: Bool) -> some View {
        let cellSize: CGFloat = exportMode ? 54 : 24
        return ZStack {
            RoundedRectangle(cornerRadius: exportMode ? 18 : 10, style: .continuous)
                .fill(day.record != nil ? AnyShapeStyle(cellGradient) : AnyShapeStyle(ThemeTokens.card(for: themeMode).opacity(themeMode.isJelly ? 0.88 : 1)))
                .overlay(
                    RoundedRectangle(cornerRadius: exportMode ? 18 : 10, style: .continuous)
                        .stroke(day.isToday ? ThemeTokens.accent(for: themeMode) : .white.opacity(themeMode.isJelly ? 0.2 : 0), lineWidth: day.isToday ? (exportMode ? 2.5 : 1.2) : 0.8)
                )

            if let date = day.date {
                if day.record != nil {
                    checkInIconImage(for: date, size: exportMode ? 42 : 18)
                        .clipShape(Circle())
                        .padding(exportMode ? 5 : 2)
                } else {
                    Text("\(Calendar.current.component(.day, from: date))")
                        .font(.system(size: exportMode ? 16 : 8, weight: .heavy, design: .rounded))
                        .foregroundStyle(ThemeTokens.Colors.textSecondary)
                }
            }
        }
        .frame(width: cellSize, height: cellSize)
    }

    private func shareStatCard(value: String, title: String, valueFont: CGFloat, titleFont: CGFloat, exportMode: Bool) -> some View {
        VStack(alignment: .leading, spacing: exportMode ? 10 : 4) {
            Text(value)
                .font(.system(size: valueFont, weight: .black, design: .rounded))
                .foregroundStyle(ThemeTokens.Colors.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.65)
            Text(title)
                .font(.system(size: titleFont, weight: .bold, design: .rounded))
                .foregroundStyle(ThemeTokens.Colors.textSecondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, exportMode ? 24 : 12)
        .padding(.vertical, exportMode ? 22 : 12)
        .background(
            RoundedRectangle(cornerRadius: exportMode ? 28 : 16, style: .continuous)
                .fill(.white.opacity(themeMode.isJelly ? 0.44 : 0.92))
                .overlay(
                    RoundedRectangle(cornerRadius: exportMode ? 28 : 16, style: .continuous)
                        .stroke(.white.opacity(themeMode.isJelly ? 0.58 : 0), lineWidth: exportMode ? 2 : 0)
                )
        )
    }

    private var cardBackgroundGradient: LinearGradient {
        LinearGradient(
            colors: themeMode.isJelly ? [
                .white.opacity(0.95),
                ThemeTokens.accentSoft(for: themeMode).opacity(0.44),
                ThemeTokens.accent(for: themeMode).opacity(0.24)
            ] : [
                ThemeTokens.background(for: themeMode),
                ThemeTokens.card(for: themeMode),
                ThemeTokens.accentSoft(for: themeMode).opacity(0.1)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var shareCardDateTitle: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: language.localeIdentifier)
        formatter.dateFormat = language == .english ? "EEEE, MMM d" : "M月d日 EEEE"
        return formatter.string(from: date)
    }

    private var selectedCheckInPack: CheckInIconPackOption {
        CheckInIconCatalog.packOption(for: store.settings.checkInIconSelection)
    }

    private func checkInIconImage(for date: Date, size: CGFloat) -> some View {
        Image(checkInIconAssetName(for: date))
            .resizable()
            .interpolation(.high)
            .aspectRatio(1, contentMode: .fit)
            .frame(width: size, height: size)
    }

    private func checkInIconAssetName(for date: Date) -> String {
        let icons = selectedCheckInPack.iconAssetNames
        guard !icons.isEmpty else { return "CheckInDoodle01_1" }
        let calendar = Calendar.current
        let dayIndex = (calendar.ordinality(of: .day, in: .year, for: date) ?? calendar.component(.day, from: date)) - 1
        let normalizedIndex = ((dayIndex % icons.count) + icons.count) % icons.count
        return icons[normalizedIndex]
    }

    private var cellGradient: AnyShapeStyle {
        AnyShapeStyle(LinearGradient(
            colors: [
                .white.opacity(themeMode.isJelly ? 0.9 : 0.36),
                ThemeTokens.accentSoft(for: themeMode).opacity(themeMode.isJelly ? 0.84 : 0.28),
                ThemeTokens.accent(for: themeMode).opacity(themeMode.isJelly ? 0.94 : 0.46)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        ))
    }

    private var uncheckedCellFill: AnyShapeStyle {
        AnyShapeStyle(ThemeTokens.card(for: themeMode))
    }

    private var weekdaySymbols: [String] {
        switch language {
        case .english:
            return ["M", "T", "W", "T", "F", "S", "S"]
        case .chinese:
            return ["一", "二", "三", "四", "五", "六", "日"]
        }
    }
}

private struct CheckInSharePreviewSheet<Content: View>: View {
    let themeMode: AppThemeMode
    let language: AppLanguage
    let textScale: AppTextScale
    @ViewBuilder let shareCardView: () -> Content
    let onShare: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    Text(language == .chinese ? "分享卡片预览" : "Share Card Preview")
                        .font(ThemeTokens.Typography.pageTitle(for: textScale))
                        .foregroundStyle(ThemeTokens.Colors.textPrimary)
                    Spacer()
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 13, weight: .black))
                            .foregroundStyle(ThemeTokens.Colors.textSecondary)
                            .frame(width: 30, height: 30)
                            .background(ThemeTokens.card(for: themeMode))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                }

                Text(language == .chinese ? "先预览，再决定是否分享到系统。" : "Preview first, then share through the system sheet.")
                    .font(ThemeTokens.Typography.caption(for: textScale))
                    .foregroundStyle(ThemeTokens.Colors.textSecondary)

                shareCardView()

                HStack(spacing: 12) {
                    CapsuleButton(title: L10n.t(.cancel, language)) {
                        dismiss()
                    }

                    CapsuleButton(
                        title: L10n.t(.shareCard, language),
                        fill: ThemeTokens.accent(for: themeMode),
                        foreground: .white
                    ) {
                        dismiss()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                            onShare()
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 18)
            .padding(.bottom, 28)
        }
        .background(ThemeTokens.background(for: themeMode).ignoresSafeArea())
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }
}

#if canImport(UIKit)
private struct ActivityShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
#endif
