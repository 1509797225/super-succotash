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

private struct BackupPointsSheet: View {
    let backups: [LocalBackupSnapshot]
    let onRestore: (LocalBackupSnapshot) -> Void

    @Environment(\.appThemeMode) private var themeMode
    @Environment(\.appLanguage) private var language
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                Text(language == .chinese ? "恢复点" : "Backup Points")
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundStyle(ThemeTokens.Colors.textPrimary)
                    .padding(.top, 10)

                if backups.isEmpty {
                    emptyState
                } else {
                    VStack(spacing: 12) {
                        ForEach(backups) { backup in
                            backupRow(backup)
                        }
                    }
                }

                CapsuleButton(title: L10n.t(.cancel, language)) {
                    dismiss()
                }

                Spacer(minLength: 0)
            }
            .padding(24)
        }
        .background(ThemeTokens.background(for: themeMode).ignoresSafeArea())
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private var emptyState: some View {
        JellyCard {
            VStack(alignment: .leading, spacing: 8) {
                Text(language == .chinese ? "暂无本地恢复点" : "No local backups")
                    .font(ThemeTokens.Typography.sectionTitle)
                    .foregroundStyle(ThemeTokens.Colors.textPrimary)

                Text(language == .chinese ? "先点击创建本地恢复点，再从这里回退。" : "Create a local backup first, then restore from here.")
                    .font(ThemeTokens.Typography.caption)
                    .foregroundStyle(ThemeTokens.Colors.textSecondary)
            }
            .padding(20)
        }
    }

    private func backupRow(_ backup: LocalBackupSnapshot) -> some View {
        JellyCard {
            HStack(spacing: 14) {
                Circle()
                    .fill(ThemeTokens.accentSoft(for: themeMode))
                    .frame(width: 42, height: 42)
                    .overlay(
                        Image(systemName: "archivebox.fill")
                            .font(.system(size: 17, weight: .bold))
                            .foregroundStyle(ThemeTokens.accent(for: themeMode))
                    )

                VStack(alignment: .leading, spacing: 5) {
                    Text(backup.createdAt.formattedShortDateTime())
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(ThemeTokens.Colors.textPrimary)

                    Text("\(backup.reason) · \(backup.todosCount) todo · \(backup.sessionsCount) focus")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(ThemeTokens.Colors.textSecondary)
                        .lineLimit(1)
                }

                Spacer()

                Button {
                    onRestore(backup)
                    dismiss()
                } label: {
                    Text(language == .chinese ? "恢复" : "Restore")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(ThemeTokens.Colors.backgroundPrimary)
                        .padding(.horizontal, 14)
                        .frame(height: 34)
                        .background(ThemeTokens.accent(for: themeMode))
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
            .padding(16)
        }
    }
}

private struct CloudBackupPointsSheet: View {
    let backups: [CloudBackupSnapshot]
    let onRestore: (CloudBackupSnapshot) -> Void
    let onRefresh: () -> Void

    @Environment(\.appThemeMode) private var themeMode
    @Environment(\.appLanguage) private var language
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    Text(language == .chinese ? "云端恢复点" : "Cloud Backups")
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .foregroundStyle(ThemeTokens.Colors.textPrimary)

                    Spacer()

                    Button(action: onRefresh) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 17, weight: .bold))
                            .foregroundStyle(ThemeTokens.accent(for: themeMode))
                            .frame(width: 42, height: 42)
                            .background(ThemeTokens.accentSoft(for: themeMode))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                }
                .padding(.top, 10)

                if backups.isEmpty {
                    emptyState
                } else {
                    VStack(spacing: 12) {
                        ForEach(backups) { backup in
                            backupRow(backup)
                        }
                    }
                }

                CapsuleButton(title: L10n.t(.cancel, language)) {
                    dismiss()
                }

                Spacer(minLength: 0)
            }
            .padding(24)
        }
        .background(ThemeTokens.background(for: themeMode).ignoresSafeArea())
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private var emptyState: some View {
        JellyCard {
            VStack(alignment: .leading, spacing: 8) {
                Text(language == .chinese ? "暂无云端恢复点" : "No cloud backups")
                    .font(ThemeTokens.Typography.sectionTitle)
                    .foregroundStyle(ThemeTokens.Colors.textPrimary)

                Text(language == .chinese ? "创建云端恢复点后，可以从这里回到某个时间节点。" : "Create a cloud backup, then restore a previous time point here.")
                    .font(ThemeTokens.Typography.caption)
                    .foregroundStyle(ThemeTokens.Colors.textSecondary)
            }
            .padding(20)
        }
    }

    private func backupRow(_ backup: CloudBackupSnapshot) -> some View {
        JellyCard {
            HStack(spacing: 14) {
                Circle()
                    .fill(ThemeTokens.accentSoft(for: themeMode))
                    .frame(width: 42, height: 42)
                    .overlay(
                        Image(systemName: "icloud.fill")
                            .font(.system(size: 17, weight: .bold))
                            .foregroundStyle(ThemeTokens.accent(for: themeMode))
                    )

                VStack(alignment: .leading, spacing: 5) {
                    Text(backup.createdAt.formattedShortDateTime())
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(ThemeTokens.Colors.textPrimary)

                    Text("\(backup.reason) · \(backup.todosCount) todo · \(backup.sessionsCount) focus")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(ThemeTokens.Colors.textSecondary)
                        .lineLimit(1)
                }

                Spacer()

                Button {
                    onRestore(backup)
                    dismiss()
                } label: {
                    Text(language == .chinese ? "恢复" : "Restore")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(ThemeTokens.Colors.backgroundPrimary)
                        .padding(.horizontal, 14)
                        .frame(height: 34)
                        .background(ThemeTokens.accent(for: themeMode))
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
            .padding(16)
        }
    }
}

struct SetView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.appLanguage) private var language
    @State private var showingProfileEditor = false
    @State private var showingThemePicker = false
    @State private var showingLanguagePicker = false
    @State private var showingBackupPoints = false
    @State private var showingCloudBackupPoints = false
    @State private var backupPendingRestore: LocalBackupSnapshot?
    @State private var cloudBackupPendingRestore: CloudBackupSnapshot?

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

                settingsLabel(backupText(english: "Pro Subscription", chinese: "Pro 订阅"))
                subscriptionGroup

                settingsLabel(backupText(english: "Backup & Sync", chinese: "备份与同步"))
                backupSyncGroup

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
        .sheet(isPresented: $showingBackupPoints) {
            BackupPointsSheet(backups: store.localBackups) { backup in
                backupPendingRestore = backup
            }
        }
        .sheet(isPresented: $showingCloudBackupPoints) {
            CloudBackupPointsSheet(
                backups: store.cloudBackups,
                onRestore: { backup in
                    cloudBackupPendingRestore = backup
                },
                onRefresh: {
                    Task {
                        await store.refreshCloudBackups()
                    }
                }
            )
        }
        .confirmationDialog(
            backupText(english: "Restore Backup?", chinese: "恢复这个备份？"),
            isPresented: Binding(
                get: { backupPendingRestore != nil },
                set: { if !$0 { backupPendingRestore = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button(backupText(english: "Restore", chinese: "恢复"), role: .destructive) {
                if let backup = backupPendingRestore {
                    store.restoreLocalBackup(backup)
                    backupPendingRestore = nil
                }
            }

            Button(L10n.t(.cancel, language), role: .cancel) {
                backupPendingRestore = nil
            }
        } message: {
            Text(backupText(
                english: "A protective backup will be created before restore.",
                chinese: "恢复前会自动创建一个保护性备份。"
            ))
        }
        .confirmationDialog(
            backupText(english: "Restore Cloud Backup?", chinese: "恢复这个云端备份？"),
            isPresented: Binding(
                get: { cloudBackupPendingRestore != nil },
                set: { if !$0 { cloudBackupPendingRestore = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button(backupText(english: "Restore", chinese: "恢复"), role: .destructive) {
                if let backup = cloudBackupPendingRestore {
                    Task {
                        await store.restoreCloudBackup(backup)
                    }
                    cloudBackupPendingRestore = nil
                }
            }

            Button(L10n.t(.cancel, language), role: .cancel) {
                cloudBackupPendingRestore = nil
            }
        } message: {
            Text(backupText(
                english: "A local protective backup will be created before cloud restore.",
                chinese: "云端恢复前会自动创建本地保护性备份。"
            ))
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

    private var backupSyncGroup: some View {
        VStack(spacing: 0) {
            settingLine(
                icon: "icloud.and.arrow.up.fill",
                title: backupText(english: "Cloud Sync", chinese: "云同步"),
                value: cloudSyncValue
            )

            settingDivider

            settingLine(
                icon: "person.crop.circle.badge.checkmark",
                title: backupText(english: "Cloud ID", chinese: "云身份"),
                value: cloudIdentityValue
            )

            settingDivider

            Button {
                Task {
                    await store.performManualSync()
                }
            } label: {
                settingLine(
                    icon: "arrow.triangle.2.circlepath",
                    title: backupText(english: "Sync Now", chinese: "立即同步"),
                    value: backupText(english: "Safe", chinese: "安全模式"),
                    showsChevron: true
                )
            }
            .buttonStyle(.plain)

            settingDivider

            settingLine(
                icon: "clock.arrow.circlepath",
                title: backupText(english: "Last Sync", chinese: "上次同步"),
                value: lastSyncValue
            )

            settingDivider

            settingLine(
                icon: "tray.and.arrow.up.fill",
                title: backupText(english: "Pending Uploads", chinese: "待上传"),
                value: "\(store.pendingUploadCount)"
            )

            settingDivider

            Button {
                Task {
                    await store.refreshCloudBackups()
                    showingCloudBackupPoints = true
                }
            } label: {
                settingLine(
                    icon: "icloud.fill",
                    title: backupText(english: "Cloud Backup Points", chinese: "云端恢复点"),
                    value: "\(store.cloudBackups.count)",
                    showsChevron: true
                )
            }
            .buttonStyle(.plain)

            settingDivider

            Button {
                Task {
                    await store.createCloudBackup(reason: "manual_cloud_backup")
                }
            } label: {
                settingLine(
                    icon: "icloud.and.arrow.up.fill",
                    title: backupText(english: "Create Cloud Backup", chinese: "创建云端恢复点"),
                    value: cloudBackupValue,
                    showsChevron: true
                )
            }
            .buttonStyle(.plain)

            settingDivider

            Button {
                showingBackupPoints = true
            } label: {
                settingLine(
                    icon: "archivebox.fill",
                    title: backupText(english: "Local Backup Points", chinese: "本地恢复点"),
                    value: "\(store.localBackups.count)",
                    showsChevron: true
                )
            }
            .buttonStyle(.plain)

            settingDivider

            Button {
                store.createLocalBackup(reason: "manual_set_backup")
            } label: {
                settingLine(
                    icon: "plus.square.on.square",
                    title: backupText(english: "Create Local Backup", chinese: "创建本地恢复点"),
                    value: latestBackupValue,
                    showsChevron: true
                )
            }
            .buttonStyle(.plain)

            settingDivider

            settingLine(
                icon: "list.bullet.rectangle.fill",
                title: backupText(english: "Sync History", chinese: "同步记录"),
                value: latestHistoryValue
            )
        }
        .background(groupBackground)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private var subscriptionGroup: some View {
        VStack(spacing: 0) {
            settingLine(
                icon: "crown.fill",
                title: backupText(english: "StoreKit", chinese: "订阅状态"),
                value: storeKitStatusValue
            )

            settingDivider

            Button {
                Task {
                    await store.refreshStoreKitEntitlement()
                }
            } label: {
                settingLine(
                    icon: "arrow.clockwise.circle.fill",
                    title: backupText(english: "Refresh Status", chinese: "刷新订阅状态"),
                    value: storeKitProductValue,
                    showsChevron: true
                )
            }
            .buttonStyle(.plain)

            settingDivider

            Button {
                Task {
                    await store.purchaseProSubscription()
                }
            } label: {
                settingLine(
                    icon: "sparkle.magnifyingglass",
                    title: backupText(english: "Try Pro Purchase", chinese: "尝试购买 Pro"),
                    value: backupText(english: "Sandbox", chinese: "沙盒"),
                    showsChevron: true
                )
            }
            .buttonStyle(.plain)
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

    private var cloudSyncValue: String {
        if store.entitlement.isCloudSyncAvailable {
            return backupText(english: "Pro On", chinese: "Pro 已开启")
        }

        if store.entitlement.tier == .pro {
            return backupText(english: "Pro Off", chinese: "Pro 未开启")
        }

        return backupText(english: "Free Local", chinese: "Free 本地")
    }

    private var cloudIdentityValue: String {
        guard let identity = store.cloudIdentity else {
            return backupText(english: "Not Created", chinese: "未创建")
        }
        return identity.shortUserID
    }

    private var storeKitStatusValue: String {
        switch store.storeKitEntitlement.state {
        case .active:
            return backupText(english: "Active", chinese: "已激活")
        case .loading:
            return backupText(english: "Checking", chinese: "检查中")
        case .productsUnavailable:
            return backupText(english: "No Product", chinese: "商品未配置")
        case .pending:
            return backupText(english: "Pending", chinese: "待处理")
        case .failed:
            return backupText(english: "Failed", chinese: "失败")
        case .notSubscribed:
            return backupText(english: "Free", chinese: "未订阅")
        case .idle:
            return backupText(english: "Not Loaded", chinese: "未加载")
        }
    }

    private var storeKitProductValue: String {
        if let activeProductID = store.storeKitEntitlement.activeProductID {
            return String(activeProductID.prefix(18))
        }

        guard !store.storeKitEntitlement.availableProductIDs.isEmpty else {
            return backupText(english: "Product", chinese: "商品")
        }

        return "\(store.storeKitEntitlement.availableProductIDs.count)"
    }

    private var lastSyncValue: String {
        guard let entry = store.syncHistory.first(where: { $0.direction != .backup }) else {
            return backupText(english: "Never", chinese: "暂无")
        }
        return entry.createdAt.formattedShortDateTime()
    }

    private var latestBackupValue: String {
        guard let backup = store.localBackups.first else {
            return backupText(english: "Now", chinese: "现在")
        }
        return backup.createdAt.formattedShortDateTime()
    }

    private var cloudBackupValue: String {
        guard let backup = store.cloudBackups.first else {
            return backupText(english: "Cloud", chinese: "云端")
        }
        return backup.createdAt.formattedShortDateTime()
    }

    private var latestHistoryValue: String {
        guard let entry = store.syncHistory.first else {
            return backupText(english: "Empty", chinese: "暂无")
        }
        return "\(entry.direction.title) · \(entry.status.title)"
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

    private func backupText(english: String, chinese: String) -> String {
        language == .chinese ? chinese : english
    }
}

private extension View {
    func settingRowFrame() -> some View {
        self
            .padding(.horizontal, 14)
            .frame(height: 58)
    }
}

private extension Date {
    func formattedShortDateTime() -> String {
        DateFormatter.setShortDateTime.string(from: self)
    }
}

private extension DateFormatter {
    static let setShortDateTime: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM-dd HH:mm"
        return formatter
    }()
}
