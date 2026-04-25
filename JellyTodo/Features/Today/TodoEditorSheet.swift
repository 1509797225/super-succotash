import SwiftUI

struct TodoEditorResult {
    let title: String
    let cycle: TodoTaskCycle
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
    @State private var cycle: TodoTaskCycle
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
        _cycle = State(initialValue: .daily)
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
        _cycle = State(initialValue: .daily)
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
        _text = State(initialValue: todo.title)
        _cycle = State(initialValue: todo.cycle)
        _durationText = State(initialValue: "\(todo.dailyDurationMinutes)")
        _focusTimerDirection = State(initialValue: todo.focusTimerDirection)
        _note = State(initialValue: todo.note)
    }

    var body: some View {
        BottomSheetContainer(title: title) {
            VStack(spacing: 18) {
                TextField(L10n.t(.enterTaskTitle, language), text: $text)
                    .font(ThemeTokens.Typography.taskTitle(for: textScale))
                    .foregroundStyle(ThemeTokens.Colors.textPrimary)
                    .padding(.horizontal, 20)
                    .frame(height: ThemeTokens.Metrics.controlHeight(for: textScale))
                    .background(ThemeTokens.card(for: themeMode))
                    .clipShape(Capsule())

                if showsFocusSettings {
                    cyclePicker
                    durationField
                    directionPicker
                    noteField
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
        .presentationDetents([showsFocusSettings ? .height(720) : .height(280)])
        .presentationDragIndicator(.hidden)
    }

    private var cyclePicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(L10n.t(.taskCycle, language))
                .font(ThemeTokens.Typography.caption(for: textScale))
                .foregroundStyle(ThemeTokens.Colors.textSecondary)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                ForEach(TodoTaskCycle.allCases) { item in
                    optionButton(title: item.title(language: language), isSelected: cycle == item) {
                        cycle = item
                    }
                }
            }
        }
    }

    private var durationField: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(L10n.t(.dailyDuration, language))
                .font(ThemeTokens.Typography.caption(for: textScale))
                .foregroundStyle(ThemeTokens.Colors.textSecondary)

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
        VStack(alignment: .leading, spacing: 10) {
            Text(L10n.t(.timerDirection, language))
                .font(ThemeTokens.Typography.caption(for: textScale))
                .foregroundStyle(ThemeTokens.Colors.textSecondary)

            HStack(spacing: 10) {
                ForEach(FocusTimerDirection.allCases) { item in
                    optionButton(title: item.title(language: language), isSelected: focusTimerDirection == item) {
                        focusTimerDirection = item
                    }
                }
            }
        }
    }

    private var noteField: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(language == .english ? "Body" : "正文")
                .font(ThemeTokens.Typography.caption(for: textScale))
                .foregroundStyle(ThemeTokens.Colors.textSecondary)

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

    private func optionButton(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(ThemeTokens.Typography.caption(for: textScale))
                .foregroundStyle(isSelected ? ThemeTokens.Colors.backgroundPrimary : ThemeTokens.Colors.textPrimary)
                .frame(maxWidth: .infinity)
                .frame(height: ThemeTokens.Metrics.controlHeight(for: textScale) - 12)
                .background(isSelected ? ThemeTokens.accent(for: themeMode) : ThemeTokens.card(for: themeMode))
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private var editorResult: TodoEditorResult {
        TodoEditorResult(
            title: text,
            cycle: cycle,
            dailyDurationMinutes: min(max(Int(durationText) ?? 25, 5), 480),
            focusTimerDirection: focusTimerDirection,
            note: note
        )
    }
}
