import SwiftUI

struct TodoEditorSheet: View {
    let title: String
    let initialText: String
    let confirmTitle: String
    let onConfirm: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var text: String

    init(title: String, initialText: String = "", confirmTitle: String, onConfirm: @escaping (String) -> Void) {
        self.title = title
        self.initialText = initialText
        self.confirmTitle = confirmTitle
        self.onConfirm = onConfirm
        _text = State(initialValue: initialText)
    }

    var body: some View {
        BottomSheetContainer(title: title) {
            VStack(spacing: 20) {
                TextField("Enter task title", text: $text)
                    .font(ThemeTokens.Typography.taskTitle)
                    .foregroundStyle(ThemeTokens.Colors.textPrimary)
                    .padding(.horizontal, 20)
                    .frame(height: ThemeTokens.Metrics.controlHeight)
                    .background(ThemeTokens.Colors.card)
                    .clipShape(Capsule())

                HStack(spacing: 16) {
                    CapsuleButton(title: "Cancel") {
                        dismiss()
                    }

                    CapsuleButton(title: confirmTitle) {
                        onConfirm(text)
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.height(280)])
        .presentationDragIndicator(.hidden)
    }
}
