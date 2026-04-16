import SwiftUI

private struct ProfileEditorSheet: View {
    let profile: UserProfile
    let onSave: (UserProfile) -> Void

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
        BottomSheetContainer(title: "Edit Profile") {
            VStack(spacing: 16) {
                TextField("Nickname", text: $nickname)
                    .font(ThemeTokens.Typography.body)
                    .padding(.horizontal, 20)
                    .frame(height: ThemeTokens.Metrics.controlHeight)
                    .background(ThemeTokens.Colors.card)
                    .clipShape(Capsule())

                TextField("Signature", text: $signature)
                    .font(ThemeTokens.Typography.body)
                    .padding(.horizontal, 20)
                    .frame(height: ThemeTokens.Metrics.controlHeight)
                    .background(ThemeTokens.Colors.card)
                    .clipShape(Capsule())

                HStack {
                    Text("Daily Goal")
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
                .background(ThemeTokens.Colors.card)
                .clipShape(Capsule())

                HStack(spacing: 16) {
                    CapsuleButton(title: "Cancel") {
                        dismiss()
                    }

                    CapsuleButton(title: "Save") {
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
    @State private var showingProfileEditor = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: ThemeTokens.Metrics.sectionSpacing) {
                profileSection
                themeSection
                preferenceSection
                aboutSection
            }
            .padding(.horizontal, ThemeTokens.Metrics.horizontalPadding)
            .padding(.top, 24)
            .padding(.bottom, 32)
        }
        .background(ThemeTokens.background(for: store.settings.themeMode).ignoresSafeArea())
        .navigationTitle("Set")
        .navigationBarTitleDisplayMode(.large)
        .sheet(isPresented: $showingProfileEditor) {
            ProfileEditorSheet(profile: store.profile) { profile in
                store.updateProfile(profile)
            }
        }
    }

    private var profileSection: some View {
        SectionCard(title: "Profile") {
            HStack(spacing: 18) {
                Circle()
                    .fill(ThemeTokens.Colors.backgroundPrimary)
                    .frame(width: 78, height: 78)
                    .overlay(
                        Text(initials)
                            .font(ThemeTokens.Typography.sectionTitle)
                            .foregroundStyle(ThemeTokens.Colors.textPrimary)
                    )

                VStack(alignment: .leading, spacing: 8) {
                    Text(store.profile.nickname.isEmpty ? "Jelly User" : store.profile.nickname)
                        .font(ThemeTokens.Typography.sectionTitle)
                        .foregroundStyle(ThemeTokens.Colors.textPrimary)

                    Text(store.profile.signature.isEmpty ? "Focus on less, do more" : store.profile.signature)
                        .font(ThemeTokens.Typography.body)
                        .foregroundStyle(ThemeTokens.Colors.textSecondary)
                        .lineLimit(2)

                    Text("Daily Goal \(store.profile.dailyGoal)")
                        .font(ThemeTokens.Typography.body)
                        .foregroundStyle(ThemeTokens.Colors.textSecondary)
                }

                Spacer(minLength: 12)
            }

            CapsuleButton(title: "Edit Profile") {
                showingProfileEditor = true
            }
        }
    }

    private var themeSection: some View {
        SectionCard(title: "Theme") {
            ForEach(AppThemeMode.allCases) { mode in
                Button {
                    var updated = store.settings
                    updated.themeMode = mode
                    store.updateSettings(updated)
                } label: {
                    HStack {
                        Text(mode.title)
                            .font(ThemeTokens.Typography.body)
                            .foregroundStyle(ThemeTokens.Colors.textPrimary)

                        Spacer()

                        if store.settings.themeMode == mode {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(ThemeTokens.Colors.textPrimary)
                        }
                    }
                    .padding(.vertical, 8)
                }
                .buttonStyle(.plain)

                if mode != AppThemeMode.allCases.last {
                    Divider()
                        .overlay(ThemeTokens.Colors.subtleLine)
                }
            }

            Divider()
                .overlay(ThemeTokens.Colors.subtleLine)
                .padding(.vertical, 4)

            Toggle(isOn: Binding(
                get: { store.settings.useLargeText },
                set: { newValue in
                    var updated = store.settings
                    updated.useLargeText = newValue
                    store.updateSettings(updated)
                }
            )) {
                Text("Large Text")
                    .font(ThemeTokens.Typography.body)
                    .foregroundStyle(ThemeTokens.Colors.textPrimary)
            }
            .tint(ThemeTokens.Colors.textSecondary)
        }
    }

    private var preferenceSection: some View {
        SectionCard(title: "Preferences") {
            Toggle(isOn: Binding(
                get: { store.settings.hapticsEnabled },
                set: { newValue in
                    var updated = store.settings
                    updated.hapticsEnabled = newValue
                    store.updateSettings(updated)
                }
            )) {
                Text("Haptics")
                    .font(ThemeTokens.Typography.body)
                    .foregroundStyle(ThemeTokens.Colors.textPrimary)
            }
            .tint(ThemeTokens.Colors.textSecondary)

            Divider()
                .overlay(ThemeTokens.Colors.subtleLine)
                .padding(.vertical, 4)

            HStack {
                Text("Pomodoro Goal")
                    .font(ThemeTokens.Typography.body)
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
                        .font(ThemeTokens.Typography.sectionTitle)
                        .frame(minWidth: 28)

                    Button {
                        var updated = store.settings
                        updated.pomodoroGoalPerDay = min(12, updated.pomodoroGoalPerDay + 1)
                        store.updateSettings(updated)
                    } label: {
                        Image(systemName: "plus")
                    }
                    .buttonStyle(.plain)
                }
                .foregroundStyle(ThemeTokens.Colors.textPrimary)
            }
        }
    }

    private var aboutSection: some View {
        SectionCard(title: "About") {
            StatRow(title: "Version", value: "1.0")
            Divider()
                .overlay(ThemeTokens.Colors.subtleLine)
                .padding(.vertical, 4)
            Text("Pure white, big type, soft jelly cards, and only the essentials.")
                .font(ThemeTokens.Typography.body)
                .foregroundStyle(ThemeTokens.Colors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var initials: String {
        let trimmed = store.profile.nickname.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "JT" : String(trimmed.prefix(2)).uppercased()
    }
}
