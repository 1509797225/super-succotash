import SwiftUI

private struct ProfileEditorSheet: View {
    let profile: UserProfile
    let onSave: (UserProfile) -> Void

    @Environment(\.appThemeMode) private var themeMode
    @Environment(\.appLanguage) private var language
    @Environment(\.dismiss) private var dismiss
    @State private var nickname: String
    @State private var signature: String
    @State private var dailyGoal: Int

    init(profile: UserProfile, onSave: @escaping (UserProfile) -> Void) {
        self.profile = profile
        self.onSave = onSave
        _nickname = State(initialValue: profile.nickname)
        _signature = State(initialValue: profile.signature)
        _dailyGoal = State(initialValue: profile.dailyGoal)
    }

    var body: some View {
        BottomSheetContainer(title: L10n.t(.editProfile, language)) {
            VStack(spacing: 16) {
                TextField("Nickname", text: $nickname)
                    .font(ThemeTokens.Typography.body)
                    .padding(.horizontal, 20)
                    .frame(height: ThemeTokens.Metrics.controlHeight)
                    .background(ThemeTokens.card(for: themeMode))
                    .clipShape(Capsule())

                TextField("Signature", text: $signature)
                    .font(ThemeTokens.Typography.body)
                    .padding(.horizontal, 20)
                    .frame(height: ThemeTokens.Metrics.controlHeight)
                    .background(ThemeTokens.card(for: themeMode))
                    .clipShape(Capsule())

                HStack {
                    Text(L10n.t(.dailyGoal, language))
                        .font(ThemeTokens.Typography.body)
                        .foregroundStyle(ThemeTokens.Colors.textSecondary)
                    Spacer()
                    HStack(spacing: 12) {
                        Button {
                            dailyGoal = max(1, dailyGoal - 1)
                        } label: {
                            Image(systemName: "minus")
                                .frame(width: 34, height: 34)
                        }
                        .buttonStyle(.plain)

                        Text("\(dailyGoal)")
                            .font(ThemeTokens.Typography.sectionTitle)
                            .frame(minWidth: 32)

                        Button {
                            dailyGoal = min(12, dailyGoal + 1)
                        } label: {
                            Image(systemName: "plus")
                                .frame(width: 34, height: 34)
                        }
                        .buttonStyle(.plain)
                    }
                    .foregroundStyle(ThemeTokens.Colors.textPrimary)
                }
                .padding(.horizontal, 20)
                .frame(height: ThemeTokens.Metrics.controlHeight)
                .background(ThemeTokens.card(for: themeMode))
                .clipShape(Capsule())

                HStack(spacing: 16) {
                    CapsuleButton(title: L10n.t(.cancel, language)) {
                        dismiss()
                    }

                    CapsuleButton(title: L10n.t(.save, language)) {
                        onSave(
                            UserProfile(
                                nickname: nickname.trimmingCharacters(in: .whitespacesAndNewlines),
                                signature: signature.trimmingCharacters(in: .whitespacesAndNewlines),
                                dailyGoal: dailyGoal
                            )
                        )
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.height(360)])
        .presentationDragIndicator(.hidden)
    }
}

struct SetView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.appLanguage) private var language
    @State private var showingProfileEditor = false
    @State private var showingThemePicker = false
    @State private var showingLanguagePicker = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                Text(L10n.t(.settings, language))
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundStyle(ThemeTokens.Colors.textPrimary)
                    .padding(.top, 26)

                plusCard

                settingsLabel(L10n.t(.profile, language))
                profileRow

                settingsLabel(L10n.t(.preferences, language))
                baseSettingsGroup

                settingsLabel(L10n.t(.about, language))
                aboutGroup
            }
            .padding(.horizontal, ThemeTokens.Metrics.horizontalPadding)
            .padding(.bottom, 40)
        }
        .background(settingsBackground.ignoresSafeArea())
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingProfileEditor) {
            ProfileEditorSheet(profile: store.profile) { profile in
                store.updateProfile(profile)
            }
        }
        .confirmationDialog(L10n.t(.theme, language), isPresented: $showingThemePicker, titleVisibility: .visible) {
            ForEach(AppThemeMode.allCases) { mode in
                Button(mode.title(language: language)) {
                    var updated = store.settings
                    updated.themeMode = mode
                    store.updateSettings(updated)
                }
            }
        }
        .confirmationDialog(L10n.t(.language, language), isPresented: $showingLanguagePicker, titleVisibility: .visible) {
            ForEach(AppLanguage.allCases) { item in
                Button(item.title) {
                    var updated = store.settings
                    updated.language = item
                    store.updateSettings(updated)
                }
            }
        }
    }

    private var settingsBackground: Color {
        store.settings.themeMode == .blackWhite ? ThemeTokens.Colors.backgroundSoft : ThemeTokens.background(for: store.settings.themeMode)
    }

    private var groupBackground: Color {
        store.settings.themeMode == .blackWhite ? ThemeTokens.Colors.backgroundPrimary : ThemeTokens.card(for: store.settings.themeMode)
    }

    private var controlBackground: Color {
        store.settings.themeMode == .blackWhite ? ThemeTokens.Colors.card : ThemeTokens.accentSoft(for: store.settings.themeMode)
    }

    private var iconBackground: Color {
        store.settings.themeMode == .blackWhite ? ThemeTokens.Colors.subtleLine : ThemeTokens.accentSoft(for: store.settings.themeMode)
    }

    private var currentAccent: Color {
        ThemeTokens.accent(for: store.settings.themeMode)
    }

    private var plusCard: some View {
        Button {
            showingProfileEditor = true
        } label: {
            HStack(spacing: 18) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("JellyTodo PLUS")
                        .font(.system(size: 18, weight: .black, design: .rounded))
                        .foregroundStyle(ThemeTokens.Colors.textPrimary)

                    Text(L10n.t(.plusDescription, language))
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(ThemeTokens.Colors.textSecondary)
                }

                Spacer()

                Circle()
                    .fill(iconBackground)
                    .frame(width: 48, height: 48)
                    .overlay(
                        Image(systemName: "chevron.right")
                            .font(.system(size: 16, weight: .black))
                            .foregroundStyle(currentAccent)
                    )
            }
            .padding(.horizontal, 20)
            .frame(height: 86)
            .background(groupBackground)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var profileRow: some View {
        Button {
            showingProfileEditor = true
        } label: {
            HStack(spacing: 14) {
                settingIcon(systemName: "person.crop.circle.fill")

                VStack(alignment: .leading, spacing: 4) {
                    Text(store.profile.nickname.isEmpty ? "Jelly User" : store.profile.nickname)
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(ThemeTokens.Colors.textPrimary)
                        .lineLimit(1)

                    if !store.profile.signature.isEmpty {
                        Text(store.profile.signature)
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundStyle(ThemeTokens.Colors.textSecondary)
                            .lineLimit(1)
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(ThemeTokens.Colors.textSecondary)
            }
            .padding(.horizontal, 14)
            .frame(height: 66)
            .background(groupBackground)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var baseSettingsGroup: some View {
        VStack(spacing: 0) {
            HStack(spacing: 14) {
                settingIcon(systemName: "circle.lefthalf.filled")
                Text(L10n.t(.appearance, language))
                    .font(settingFont)
                    .foregroundStyle(ThemeTokens.Colors.textPrimary)

                Spacer()

                HStack(spacing: 4) {
                    ForEach([AppThemeMode.blackWhite, .pink, .blue, .green], id: \.id) { mode in
                        Button {
                            var updated = store.settings
                            updated.themeMode = mode
                            store.updateSettings(updated)
                        } label: {
                            Circle()
                                .fill(ThemeTokens.accent(for: mode))
                                .frame(width: 24, height: 24)
                                .overlay(
                                    Circle()
                                        .stroke(store.settings.themeMode == mode ? currentAccent : Color.clear, lineWidth: 2)
                                )
                                .frame(width: 36, height: 28)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 8)
                .frame(height: 34)
                .background(controlBackground)
                .clipShape(Capsule())
            }
            .settingRowFrame()

            settingDivider

            Button {
                showingThemePicker = true
            } label: {
                settingLine(
                    icon: "target",
                    title: L10n.t(.theme, language),
                    value: store.settings.themeMode.title(language: language),
                    showsChevron: true
                )
            }
            .buttonStyle(.plain)

            settingDivider

            settingLine(icon: "app.badge.fill", title: L10n.t(.appIcon, language), badge: "PLUS", showsChevron: true)

            settingDivider

            HStack(spacing: 14) {
                settingIcon(systemName: "waveform.path")

                Text(L10n.t(.haptics, language))
                    .font(settingFont)
                    .foregroundStyle(ThemeTokens.Colors.textPrimary)

                Spacer()

                Toggle("", isOn: Binding(
                    get: { store.settings.hapticsEnabled },
                    set: { newValue in
                        var updated = store.settings
                        updated.hapticsEnabled = newValue
                        store.updateSettings(updated)
                    }
                ))
                .labelsHidden()
                .tint(currentAccent)
            }
            .settingRowFrame()

            settingDivider

            Button {
                showingLanguagePicker = true
            } label: {
                settingLine(icon: "globe", title: L10n.t(.language, language), value: store.settings.language.title, showsChevron: true)
            }
            .buttonStyle(.plain)

            settingDivider

            HStack(spacing: 14) {
                settingIcon(systemName: "timer")

                Text(L10n.t(.pomodoroGoal, language))
                    .font(settingFont)
                    .foregroundStyle(ThemeTokens.Colors.textPrimary)

                Spacer()

                HStack(spacing: 12) {
                    Button {
                        var updated = store.settings
                        updated.pomodoroGoalPerDay = max(1, updated.pomodoroGoalPerDay - 1)
                        store.updateSettings(updated)
                    } label: {
                        Image(systemName: "minus")
                    }
                    .buttonStyle(.plain)

                    Text("\(store.settings.pomodoroGoalPerDay)")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .frame(minWidth: 26)

                    Button {
                        var updated = store.settings
                        updated.pomodoroGoalPerDay = min(12, updated.pomodoroGoalPerDay + 1)
                        store.updateSettings(updated)
                    } label: {
                        Image(systemName: "plus")
                    }
                    .buttonStyle(.plain)
                }
                .foregroundStyle(currentAccent)
            }
            .settingRowFrame()

            settingDivider

            HStack(spacing: 14) {
                settingIcon(systemName: "textformat.size")

                Text(L10n.t(.largeText, language))
                    .font(settingFont)
                    .foregroundStyle(ThemeTokens.Colors.textPrimary)

                Spacer()

                Toggle("", isOn: Binding(
                    get: { store.settings.useLargeText },
                    set: { newValue in
                        var updated = store.settings
                        updated.useLargeText = newValue
                        store.updateSettings(updated)
                    }
                ))
                .labelsHidden()
                .tint(currentAccent)
            }
            .settingRowFrame()
        }
        .background(groupBackground)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private var aboutGroup: some View {
        VStack(spacing: 0) {
            settingLine(icon: "sparkles", title: L10n.t(.designConcept, language), value: L10n.t(.bigJelly, language))
            settingDivider
            settingLine(icon: "number", title: L10n.t(.version, language), value: "1.0")
        }
        .background(groupBackground)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private var settingFont: Font {
        .system(size: 18, weight: .bold, design: .rounded)
    }

    private var settingDivider: some View {
        Rectangle()
            .fill(iconBackground.opacity(0.75))
            .frame(height: 1)
            .padding(.leading, 62)
    }

    private func settingsLabel(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 14, weight: .bold, design: .rounded))
            .foregroundStyle(ThemeTokens.Colors.textSecondary)
            .padding(.leading, 2)
            .padding(.bottom, -14)
    }

    private func settingLine(
        icon: String,
        title: String,
        value: String? = nil,
        badge: String? = nil,
        showsChevron: Bool = false
    ) -> some View {
        HStack(spacing: 14) {
            settingIcon(systemName: icon)

            Text(title)
                .font(settingFont)
                .foregroundStyle(ThemeTokens.Colors.textPrimary)

            if let badge {
                Text(badge)
                    .font(.system(size: 11, weight: .black, design: .rounded))
                    .foregroundStyle(ThemeTokens.Colors.backgroundPrimary)
                    .padding(.horizontal, 8)
                    .frame(height: 18)
                    .background(currentAccent)
                    .clipShape(Capsule())
            }

            Spacer()

            if let value {
                Text(value)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(ThemeTokens.Colors.textSecondary)
                    .lineLimit(1)
            }

            if showsChevron {
                Image(systemName: "chevron.right")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(ThemeTokens.Colors.textSecondary)
            }
        }
        .settingRowFrame()
    }

    private func settingIcon(systemName: String) -> some View {
        Circle()
            .fill(iconBackground)
            .frame(width: 36, height: 36)
            .overlay(
                Image(systemName: systemName)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(currentAccent)
            )
    }

    private var initials: String {
        let trimmed = store.profile.nickname.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "JT" : String(trimmed.prefix(2)).uppercased()
    }
}

private extension View {
    func settingRowFrame() -> some View {
        self
            .padding(.horizontal, 14)
            .frame(height: 58)
    }
}
