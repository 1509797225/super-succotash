import SwiftUI

struct TodoEditorResult {
    let title: String
    let scheduleMode: TodoScheduleMode
    let recurrenceValue: Int?
    let scheduledDates: [Date]
    let dailyDurationMinutes: Int
    let focusTimerDirection: FocusTimerDirection
    let note: String
}

struct TodoEditorSheet: View {
    let title: String
    let initialText: String
    let confirmTitle: String
    let showsFocusSettings: Bool
    let onConfirm: (TodoEditorResult) -> Void

    @Environment(\.appThemeMode) private var themeMode
    @Environment(\.appLanguage) private var language
    @Environment(\.appTextScale) private var textScale
    @Environment(\.dismiss) private var dismiss
    @State private var text: String
    @State private var scheduledDates: [Date]
    @State private var monthPageOffset: Int
    @GestureState private var calendarDragOffset: CGFloat
    @State private var recurrenceMode: RecurrenceMode
    @State private var weeklyValue: Int
    @State private var monthlyValue: Int
    @State private var durationText: String
    @State private var focusTimerDirection: FocusTimerDirection
    @State private var note: String

    init(title: String, initialText: String = "", confirmTitle: String, onConfirm: @escaping (String) -> Void) {
        self.title = title
        self.initialText = initialText
        self.confirmTitle = confirmTitle
        self.showsFocusSettings = false
        self.onConfirm = { result in
            onConfirm(result.title)
        }
        _text = State(initialValue: initialText)
        _scheduledDates = State(initialValue: [])
        _monthPageOffset = State(initialValue: 0)
        _calendarDragOffset = GestureState(initialValue: 0)
        _recurrenceMode = State(initialValue: .custom)
        _weeklyValue = State(initialValue: 1)
        _monthlyValue = State(initialValue: Calendar.current.component(.day, from: Date()))
        _durationText = State(initialValue: "25")
        _focusTimerDirection = State(initialValue: .countDown)
        _note = State(initialValue: "")
    }

    init(
        title: String,
        initialText: String = "",
        confirmTitle: String,
        showsFocusSettings: Bool,
        onConfirm: @escaping (TodoEditorResult) -> Void
    ) {
        self.title = title
        self.initialText = initialText
        self.confirmTitle = confirmTitle
        self.showsFocusSettings = showsFocusSettings
        self.onConfirm = onConfirm
        _text = State(initialValue: initialText)
        _scheduledDates = State(initialValue: [Calendar.current.startOfDay(for: Date())])
        _monthPageOffset = State(initialValue: 0)
        _calendarDragOffset = GestureState(initialValue: 0)
        _recurrenceMode = State(initialValue: .daily)
        _weeklyValue = State(initialValue: Calendar.current.component(.weekday, from: Date()))
        _monthlyValue = State(initialValue: Calendar.current.component(.day, from: Date()))
        _durationText = State(initialValue: "25")
        _focusTimerDirection = State(initialValue: .countDown)
        _note = State(initialValue: "")
    }

    init(title: String, todo: TodoItem, confirmTitle: String, onConfirm: @escaping (TodoEditorResult) -> Void) {
        self.title = title
        self.initialText = todo.title
        self.confirmTitle = confirmTitle
        self.showsFocusSettings = true
        self.onConfirm = onConfirm
        let previewDates = todo.editorPreviewDates()
        let resolvedMode = RecurrenceMode(todo.scheduleMode)
        _text = State(initialValue: todo.title)
        _scheduledDates = State(initialValue: previewDates.isEmpty ? [Calendar.current.startOfDay(for: todo.taskDate)] : previewDates)
        _monthPageOffset = State(initialValue: 0)
        _calendarDragOffset = GestureState(initialValue: 0)
        _recurrenceMode = State(initialValue: resolvedMode)
        _weeklyValue = State(initialValue: todo.recurrenceValue ?? Calendar.current.component(.weekday, from: todo.taskDate))
        _monthlyValue = State(initialValue: todo.recurrenceValue ?? Calendar.current.component(.day, from: todo.taskDate))
        _durationText = State(initialValue: "\(todo.dailyDurationMinutes)")
        _focusTimerDirection = State(initialValue: todo.focusTimerDirection)
        _note = State(initialValue: todo.note)
    }

    var body: some View {
        BottomSheetContainer(title: title) {
            VStack(spacing: 16) {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {
                        TextField(L10n.t(.enterTaskTitle, language), text: $text)
                            .font(ThemeTokens.Typography.taskTitle(for: textScale))
                            .foregroundStyle(ThemeTokens.Colors.textPrimary)
                            .padding(.horizontal, 20)
                            .frame(height: ThemeTokens.Metrics.controlHeight(for: textScale))
                            .background(ThemeTokens.card(for: themeMode))
                            .clipShape(Capsule())

                        if showsFocusSettings {
                            schedulePicker
                            durationField
                            directionPicker
                            noteField
                        }
                    }
                    .padding(.bottom, showsFocusSettings ? 20 : 0)
                }

                HStack(spacing: 16) {
                    CapsuleButton(title: L10n.t(.cancel, language)) {
                        dismiss()
                    }

                    CapsuleButton(title: confirmTitle) {
                        onConfirm(editorResult)
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([showsFocusSettings ? .large : .height(280)])
        .presentationDragIndicator(.hidden)
    }

    private var schedulePicker: some View {
        formSection(title: language == .english ? "Focus Dates" : "专注日期") {
            VStack(alignment: .leading, spacing: 12) {
                recurrencePicker
                scheduleCalendar
            }
        }
    }

    private var recurrencePicker: some View {
        VStack(spacing: 12) {
            HStack(spacing: 10) {
                recurrenceChip(title: language == .english ? "Daily" : "每天", mode: .daily)
                recurrenceChip(
                    title: language == .english ? "Weekly" : "每周",
                    detail: recurrenceMode == .weekly ? "(\(displayValue(mode: .weekly, value: weeklyValue)))" : nil,
                    mode: .weekly
                )
                recurrenceChip(
                    title: language == .english ? "Monthly" : "每月",
                    detail: recurrenceMode == .monthly ? "(\(displayValue(mode: .monthly, value: monthlyValue)))" : nil,
                    mode: .monthly
                )
            }

            if recurrenceMode == .weekly || recurrenceMode == .monthly {
                recurrenceWheelPanel
            }
        }
    }

    private func recurrenceChip(title: String, detail: String? = nil, mode: RecurrenceMode) -> some View {
        let isSelected = recurrenceMode == mode
        return Button {
            recurrenceMode = mode
            applyRecurrence(mode)
        } label: {
            HStack(spacing: 4) {
                Text(title)
                    .font(.system(size: 19 * textScale.typographyScale, weight: .bold, design: .rounded))
                if let detail {
                    Text(detail)
                        .font(.system(size: 14 * textScale.typographyScale, weight: .bold, design: .rounded))
                        .contentTransition(.numericText())
                }
            }
            .foregroundStyle(isSelected ? ThemeTokens.Colors.backgroundPrimary : ThemeTokens.Colors.textPrimary)
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(recurrenceChipBackground(isSelected: isSelected))
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(isSelected ? .clear : ThemeTokens.Colors.textSecondary.opacity(themeMode.isJelly ? 0.12 : 0.08), lineWidth: 1)
            }
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var recurrenceWheelPanel: some View {
        VStack(spacing: 10) {
            HStack {
                Text(recurrenceMode == .weekly ? (language == .english ? "Every week" : "每周重复") : (language == .english ? "Every month" : "每月重复"))
                    .font(.system(size: 13 * textScale.typographyScale, weight: .bold, design: .rounded))
                    .foregroundStyle(ThemeTokens.Colors.textSecondary)
                Spacer()
                Text(recurrenceMode == .weekly ? displayValue(mode: .weekly, value: weeklyValue) : displayValue(mode: .monthly, value: monthlyValue))
                    .font(.system(size: 15 * textScale.typographyScale, weight: .bold, design: .rounded))
                    .foregroundStyle(ThemeTokens.Colors.textPrimary)
            }

            Picker("", selection: recurrenceSelectionBinding) {
                ForEach(recurrenceOptions, id: \.self) { item in
                    Text(displayValue(mode: recurrenceMode, value: item)).tag(item)
                }
            }
            .pickerStyle(.wheel)
            .compositingGroup()
            .frame(height: 84)
            .clipped()
            .mask {
                LinearGradient(
                    colors: [.clear, .black.opacity(0.88), .black.opacity(0.88), .clear],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(ThemeTokens.Colors.backgroundPrimary.opacity(themeMode.isJelly ? 0.42 : 0.78))
        )
    }

    private var scheduleCalendar: some View {
        GeometryReader { proxy in
            let width = max(proxy.size.width, 1)

            HStack(spacing: 0) {
                ForEach([-1, 0, 1], id: \.self) { delta in
                    monthGridSection(for: monthPageOffset + delta)
                        .padding(.top, 2)
                        .frame(width: width)
                }
            }
            .offset(x: -width + calendarDragOffset)
            .gesture(calendarSwipeGesture(pageWidth: width))
            .clipped()
        }
        .frame(height: calendarPageHeight)
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private func monthGridSection(for offset: Int) -> some View {
        if let section = monthSection(for: offset) {
            VStack(spacing: 12) {
                HStack {
                    Text(section.title)
                        .font(.system(size: 19 * textScale.typographyScale, weight: .bold, design: .rounded))
                        .foregroundStyle(ThemeTokens.Colors.textPrimary)
                    Spacer()
                    Text(language == .english ? "\(selectedDatesInMonth(section.anchorDate)) selected" : "已选 \(selectedDatesInMonth(section.anchorDate)) 天")
                        .font(.system(size: 11 * textScale.typographyScale, weight: .bold, design: .rounded))
                        .foregroundStyle(ThemeTokens.Colors.textSecondary)
                        .padding(.horizontal, 10)
                        .frame(height: 24)
                        .background(ThemeTokens.Colors.backgroundPrimary.opacity(themeMode.isJelly ? 0.5 : 0.78))
                        .clipShape(Capsule())
                }

                LazyVGrid(columns: weekdayColumns, spacing: 8) {
                    ForEach(weekdaySymbols, id: \.self) { symbol in
                        Text(symbol)
                            .font(.system(size: 12 * textScale.typographyScale, weight: .bold, design: .rounded))
                            .foregroundStyle(ThemeTokens.Colors.textSecondary)
                            .frame(maxWidth: .infinity)
                    }

                    ForEach(section.cells) { cell in
                        if let date = cell.date {
                            calendarDayCell(date: date)
                        } else {
                            Color.clear
                                .frame(height: dayCellHeight)
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .fill(ThemeTokens.card(for: themeMode))
                    .overlay(
                        RoundedRectangle(cornerRadius: 30, style: .continuous)
                            .stroke(ThemeTokens.Colors.textSecondary.opacity(themeMode.isJelly ? 0.08 : 0.05), lineWidth: 1)
                    )
            )
        }
    }

    private func formSection<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(ThemeTokens.Typography.caption(for: textScale))
                .foregroundStyle(ThemeTokens.Colors.textSecondary)

            JellyCard(shadowStyle: .listItem) {
                VStack(alignment: .leading, spacing: 12) {
                    content()
                }
                .padding(16)
            }
        }
    }

    private var durationField: some View {
        formSection(title: L10n.t(.dailyDuration, language)) {
            HStack(spacing: 12) {
                TextField("25", text: $durationText)
                    .keyboardType(.numberPad)
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundStyle(ThemeTokens.Colors.textPrimary)
                    .multilineTextAlignment(.center)
                    .frame(height: ThemeTokens.Metrics.controlHeight(for: textScale))
                    .background(ThemeTokens.card(for: themeMode))
                    .clipShape(Capsule())
                    .onChange(of: durationText) { newValue in
                        durationText = String(newValue.filter(\.isNumber).prefix(3))
                    }

                Text(L10n.t(.minDay, language))
                    .font(ThemeTokens.Typography.body(for: textScale))
                    .foregroundStyle(ThemeTokens.Colors.textSecondary)
            }
        }
    }

    private var directionPicker: some View {
        formSection(title: L10n.t(.timerDirection, language)) {
            HStack(spacing: 10) {
                ForEach(FocusTimerDirection.allCases) { item in
                    optionButton(title: item.title(language: language), isSelected: focusTimerDirection == item, fillsWidth: true) {
                        focusTimerDirection = item
                    }
                }
            }
        }
    }

    private var noteField: some View {
        formSection(title: language == .english ? "Body" : "正文") {
            TextEditor(text: $note)
                .font(ThemeTokens.Typography.body(for: textScale))
                .foregroundStyle(ThemeTokens.Colors.textPrimary)
                .scrollContentBackground(.hidden)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .frame(height: 96)
                .background(ThemeTokens.card(for: themeMode))
                .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                .onChange(of: note) { newValue in
                    note = String(newValue.prefix(1_000))
                }
        }
    }

    private func optionButton(
        title: String,
        isSelected: Bool,
        fillsWidth: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(title)
                .font(ThemeTokens.Typography.caption(for: textScale))
                .foregroundStyle(isSelected ? ThemeTokens.Colors.backgroundPrimary : ThemeTokens.Colors.textPrimary)
                .frame(maxWidth: fillsWidth ? .infinity : nil)
                .padding(.horizontal, fillsWidth ? 0 : 18)
                .frame(height: ThemeTokens.Metrics.controlHeight(for: textScale) - 12)
                .background(isSelected ? ThemeTokens.accent(for: themeMode) : ThemeTokens.card(for: themeMode))
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private var editorResult: TodoEditorResult {
        let mode = recurrenceMode.scheduleMode
        return TodoEditorResult(
            title: text,
            scheduleMode: mode,
            recurrenceValue: recurrenceValueForEditor,
            scheduledDates: mode == .custom ? normalizedScheduledDates : [],
            dailyDurationMinutes: min(max(Int(durationText) ?? 25, 5), 480),
            focusTimerDirection: focusTimerDirection,
            note: note
        )
    }

    private var calendarRangeStart: Date {
        let calendar = Calendar.current
        return calendar.startOfDay(for: Date())
    }

    private var calendarPageHeight: CGFloat {
        let rowCount = monthSection(for: monthPageOffset)?.rowCount ?? 6
        let headerHeight: CGFloat = 34
        let weekHeight: CGFloat = 24
        let gaps = CGFloat(max(rowCount - 1, 0)) * 8
        let gridHeight = CGFloat(rowCount) * dayCellHeight + gaps
        return headerHeight + weekHeight + gridHeight + 52
    }

    private func monthSection(for offset: Int) -> CalendarMonthSection? {
        let calendar = Calendar.current
        guard let monthDate = calendar.date(byAdding: .month, value: offset, to: calendarRangeStart) else {
            return nil
        }
        return buildMonthSection(for: monthDate)
    }

    private var weekdayColumns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 8), count: 7)
    }

    private var weekdaySymbols: [String] {
        let calendar = Calendar.current
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: language.localeIdentifier)
        let symbols = formatter.shortStandaloneWeekdaySymbols ?? formatter.shortWeekdaySymbols ?? []
        let firstWeekdayIndex = max(calendar.firstWeekday - 1, 0)
        guard !symbols.isEmpty else { return ["S", "M", "T", "W", "T", "F", "S"] }
        return Array(symbols[firstWeekdayIndex...] + symbols[..<firstWeekdayIndex])
    }

    private var dayCellHeight: CGFloat {
        40 * textScale.layoutScale
    }

    private var normalizedScheduledDates: [Date] {
        let calendar = Calendar.current
        let unique = Set(scheduledDates.map { calendar.startOfDay(for: $0).timeIntervalSinceReferenceDate })
        return unique.map(Date.init(timeIntervalSinceReferenceDate:)).sorted()
    }

    private var scheduleSummaryText: String {
        let dates = normalizedScheduledDates
        guard !dates.isEmpty else {
            return language == .english ? "Select one or more dates" : "请选择一个或多个日期"
        }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: language.localeIdentifier)
        formatter.dateFormat = language == .english ? "MMM d" : "M月d日"
        if dates.count <= 4 {
            return dates.map { formatter.string(from: $0) }.joined(separator: language == .english ? ", " : "、")
        }
        let head = dates.prefix(4).map { formatter.string(from: $0) }.joined(separator: language == .english ? ", " : "、")
        return language == .english ? "\(head) +\(dates.count - 4)" : "\(head) 等\(dates.count)天"
    }

    private func isDateSelected(_ date: Date) -> Bool {
        let calendar = Calendar.current
        return normalizedScheduledDates.contains { calendar.isDate($0, inSameDayAs: date) }
    }

    private func toggleDateSelection(_ date: Date) {
        let calendar = Calendar.current
        if let index = scheduledDates.firstIndex(where: { calendar.isDate($0, inSameDayAs: date) }) {
            if scheduledDates.count > 1 {
                scheduledDates.remove(at: index)
            }
        } else {
            scheduledDates.append(calendar.startOfDay(for: date))
        }
        recurrenceMode = .custom
    }

    @ViewBuilder
    private func calendarDayCell(date: Date) -> some View {
        let isSelected = isDateSelected(date)
        let isToday = Calendar.current.isDateInToday(date)

        Button {
            toggleDateSelection(date)
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(dayCellBackground(isSelected: isSelected, isToday: isToday))

                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(dayCellStroke(isSelected: isSelected, isToday: isToday), lineWidth: isSelected ? 0 : 1)

                Text(dayNumberString(for: date))
                    .font(.system(size: 16 * textScale.typographyScale, weight: .bold, design: .rounded))
                    .foregroundStyle(dayCellForeground(isSelected: isSelected))
            }
            .frame(height: dayCellHeight)
            .shadow(color: isSelected ? ThemeTokens.accent(for: themeMode).opacity(themeMode.isJelly ? 0.22 : 0.12) : .clear, radius: 10, x: 0, y: 4)
            .overlay(alignment: .topTrailing) {
                if isToday {
                    Circle()
                        .fill(isSelected ? ThemeTokens.Colors.backgroundPrimary.opacity(0.92) : ThemeTokens.accent(for: themeMode))
                        .frame(width: 6, height: 6)
                        .padding(6)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private func buildMonthSection(for monthDate: Date) -> CalendarMonthSection {
        let calendar = Calendar.current
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: language.localeIdentifier)
        formatter.dateFormat = language == .english ? "MMMM yyyy" : "yyyy年M月"

        let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: monthDate)) ?? monthDate
        let firstWeekday = calendar.component(.weekday, from: startOfMonth)
        let leading = (firstWeekday - calendar.firstWeekday + 7) % 7
        let daysInMonth = calendar.range(of: .day, in: .month, for: startOfMonth)?.count ?? 30

        var cells = Array(repeating: CalendarDayCell.empty, count: leading)
        for day in 1...daysInMonth {
            if let date = calendar.date(byAdding: .day, value: day - 1, to: startOfMonth) {
                cells.append(CalendarDayCell(date: date))
            }
        }
        while cells.count % 7 != 0 {
            cells.append(.empty)
        }

        return CalendarMonthSection(title: formatter.string(from: startOfMonth), anchorDate: startOfMonth, cells: cells)
    }

    private func dayNumberString(for date: Date) -> String {
        "\(Calendar.current.component(.day, from: date))"
    }

    private func dayCellBackground(isSelected: Bool, isToday: Bool) -> some ShapeStyle {
        if isSelected {
            return AnyShapeStyle(
                LinearGradient(
                    colors: [
                        ThemeTokens.accent(for: themeMode).opacity(themeMode.isJelly ? 0.9 : 1),
                        ThemeTokens.accentSoft(for: themeMode).opacity(themeMode.isJelly ? 0.75 : 0.92)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
        }
        if isToday {
            return AnyShapeStyle(ThemeTokens.card(for: themeMode).opacity(themeMode.isJelly ? 0.72 : 0.9))
        }
        return AnyShapeStyle(ThemeTokens.Colors.backgroundPrimary.opacity(themeMode.isJelly ? 0.48 : 0.78))
    }

    private func dayCellStroke(isSelected: Bool, isToday: Bool) -> Color {
        if isSelected {
            return .clear
        }
        if isToday {
            return ThemeTokens.accent(for: themeMode).opacity(0.5)
        }
        return ThemeTokens.Colors.textSecondary.opacity(themeMode.isJelly ? 0.12 : 0.08)
    }

    private func dayCellForeground(isSelected: Bool) -> Color {
        isSelected ? ThemeTokens.Colors.backgroundPrimary : ThemeTokens.Colors.textPrimary
    }

    private func recurrenceChipBackground(isSelected: Bool) -> some ShapeStyle {
        if isSelected {
            return AnyShapeStyle(
                LinearGradient(
                    colors: [
                        ThemeTokens.accent(for: themeMode),
                        ThemeTokens.accentSoft(for: themeMode).opacity(themeMode.isJelly ? 0.88 : 0.96)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
        }
        return AnyShapeStyle(ThemeTokens.card(for: themeMode))
    }

    private var recurrenceOptions: [Int] {
        recurrenceMode == .weekly ? Array(1...7) : Array(1...31)
    }

    private var recurrenceSelectionBinding: Binding<Int> {
        Binding(
            get: { recurrenceMode == .weekly ? weeklyValue : monthlyValue },
            set: { newValue in
                if recurrenceMode == .weekly {
                    weeklyValue = newValue
                } else {
                    monthlyValue = newValue
                }
                applyRecurrence(recurrenceMode)
            }
        )
    }

    private func calendarSwipeGesture(pageWidth: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 10, coordinateSpace: .local)
            .updating($calendarDragOffset) { value, state, _ in
                let translation = value.translation.width
                let limited = min(max(translation, -pageWidth * 0.9), pageWidth * 0.9)
                state = limited
            }
            .onEnded { value in
                let predicted = value.predictedEndTranslation.width
                let threshold = pageWidth * 0.22
                let destination: Int

                if predicted <= -threshold {
                    destination = monthPageOffset + 1
                } else if predicted >= threshold {
                    destination = monthPageOffset - 1
                } else {
                    destination = monthPageOffset
                }

                withAnimation(.interactiveSpring(response: 0.34, dampingFraction: 0.86, blendDuration: 0.18)) {
                    monthPageOffset = destination
                }
            }
    }

    private func selectedDatesInMonth(_ monthDate: Date) -> Int {
        let calendar = Calendar.current
        return normalizedScheduledDates.filter { calendar.isDate($0, equalTo: monthDate, toGranularity: .month) }.count
    }

    private func applyRecurrence(_ mode: RecurrenceMode) {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: Date())

        switch mode {
        case .custom:
            return
        case .daily:
            scheduledDates = (0..<90).compactMap { calendar.date(byAdding: .day, value: $0, to: start) }
        case .weekly:
            scheduledDates = nextWeeklyDates(weekday: weeklyValue, from: start, count: 16)
        case .monthly:
            scheduledDates = nextMonthlyDates(day: monthlyValue, from: start, count: 12)
        }
    }

    private func nextWeeklyDates(weekday: Int, from start: Date, count: Int) -> [Date] {
        let calendar = Calendar.current
        var dates: [Date] = []
        var cursor = start

        while dates.count < count {
            if calendar.component(.weekday, from: cursor) == weekday {
                dates.append(cursor)
            }
            guard let next = calendar.date(byAdding: .day, value: 1, to: cursor) else { break }
            cursor = next
        }
        return dates
    }

    private func nextMonthlyDates(day: Int, from start: Date, count: Int) -> [Date] {
        let calendar = Calendar.current
        var dates: [Date] = []

        for offset in 0..<count {
            guard let monthDate = calendar.date(byAdding: .month, value: offset, to: start),
                  let monthRange = calendar.range(of: .day, in: .month, for: monthDate),
                  let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: monthDate))
            else { continue }

            let targetDay = min(day, monthRange.count)
            if let targetDate = calendar.date(byAdding: .day, value: targetDay - 1, to: monthStart), targetDate >= start {
                dates.append(targetDate)
            }
        }
        return dates
    }

    private func displayValue(mode: RecurrenceMode, value: Int) -> String {
        switch mode {
        case .weekly:
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: language.localeIdentifier)
            let symbols = formatter.veryShortStandaloneWeekdaySymbols ?? formatter.shortWeekdaySymbols ?? []
            let index = max(min(value - 1, symbols.count - 1), 0)
            return symbols.isEmpty ? "\(value)" : symbols[index]
        case .monthly:
            return "\(value)"
        case .daily, .custom:
            return "\(value)"
        }
    }

    private var recurrenceValueForEditor: Int? {
        switch recurrenceMode {
        case .weekly:
            return weeklyValue
        case .monthly:
            return monthlyValue
        case .daily, .custom:
            return nil
        }
    }
}

private enum RecurrenceMode {
    case custom
    case daily
    case weekly
    case monthly

    init(_ mode: TodoScheduleMode) {
        switch mode {
        case .custom:
            self = .custom
        case .daily:
            self = .daily
        case .weekly:
            self = .weekly
        case .monthly:
            self = .monthly
        }
    }

    var scheduleMode: TodoScheduleMode {
        switch self {
        case .custom:
            return .custom
        case .daily:
            return .daily
        case .weekly:
            return .weekly
        case .monthly:
            return .monthly
        }
    }
}

private struct CalendarMonthSection: Identifiable {
    let id = UUID()
    let title: String
    let anchorDate: Date
    let cells: [CalendarDayCell]

    var rowCount: Int {
        max(cells.count / 7, 1)
    }
}

private struct CalendarDayCell: Identifiable {
    let id = UUID()
    let date: Date?

    static let empty = CalendarDayCell(date: nil)
}
