import SwiftUI

struct TodoEditorResult {
    let title: String
    let cycle: TodoTaskCycle
    let dailyDurationMinutes: Int
    let focusTimerDirection: FocusTimerDirection
}

struct TodoEditorSheet: View {
    let title: String
    let initialText: String
    let confirmTitle: String
    let showsFocusSettings: Bool
    let onConfirm: (TodoEditorResult) -> Void

    @Environment(\.appThemeMode) private var themeMode
    @Environment(\.dismiss) private var dismiss
    @State private var text: String
    @State private var cycle: TodoTaskCycle
    @State private var durationText: String
    @State private var focusTimerDirection: FocusTimerDirection

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
    }

    var body: some View {
        BottomSheetContainer(title: title) {
            VStack(spacing: 18) {
                TextField("Enter task title", text: $text)
                    .font(ThemeTokens.Typography.taskTitle)
                    .foregroundStyle(ThemeTokens.Colors.textPrimary)
                    .padding(.horizontal, 20)
                    .frame(height: ThemeTokens.Metrics.controlHeight)
                    .background(ThemeTokens.card(for: themeMode))
                    .clipShape(Capsule())

                if showsFocusSettings {
                    cyclePicker
                    durationField
                    directionPicker
                }

                HStack(spacing: 16) {
                    CapsuleButton(title: "Cancel") {
                        dismiss()
                    }

                    CapsuleButton(title: confirmTitle) {
                        onConfirm(editorResult)
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([showsFocusSettings ? .height(620) : .height(280)])
        .presentationDragIndicator(.hidden)
    }

    private var cyclePicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Task Cycle")
                .font(ThemeTokens.Typography.caption)
                .foregroundStyle(ThemeTokens.Colors.textSecondary)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                ForEach(TodoTaskCycle.allCases) { item in
                    optionButton(title: item.title, isSelected: cycle == item) {
                        cycle = item
                    }
                }
            }
        }
    }

    private var durationField: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Daily Duration")
                .font(ThemeTokens.Typography.caption)
                .foregroundStyle(ThemeTokens.Colors.textSecondary)

            HStack(spacing: 12) {
                TextField("25", text: $durationText)
                    .keyboardType(.numberPad)
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundStyle(ThemeTokens.Colors.textPrimary)
                    .multilineTextAlignment(.center)
                    .frame(height: ThemeTokens.Metrics.controlHeight)
                    .background(ThemeTokens.card(for: themeMode))
                    .clipShape(Capsule())
                    .onChange(of: durationText) { newValue in
                        durationText = String(newValue.filter(\.isNumber).prefix(3))
                    }

                Text("min / day")
                    .font(ThemeTokens.Typography.body)
                    .foregroundStyle(ThemeTokens.Colors.textSecondary)
            }
        }
    }

    private var directionPicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Timer Direction")
                .font(ThemeTokens.Typography.caption)
                .foregroundStyle(ThemeTokens.Colors.textSecondary)

            HStack(spacing: 10) {
                ForEach(FocusTimerDirection.allCases) { item in
                    optionButton(title: item.title, isSelected: focusTimerDirection == item) {
                        focusTimerDirection = item
                    }
                }
            }
        }
    }

    private func optionButton(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(ThemeTokens.Typography.caption)
                .foregroundStyle(isSelected ? ThemeTokens.Colors.backgroundPrimary : ThemeTokens.Colors.textPrimary)
                .frame(maxWidth: .infinity)
                .frame(height: 48)
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
            focusTimerDirection: focusTimerDirection
        )
    }
}
