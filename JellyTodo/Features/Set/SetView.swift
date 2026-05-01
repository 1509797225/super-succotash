import SwiftUI
#if canImport(UIKit)
import UIKit
#endif
#if APPLE_SIGN_IN_ENABLED
import AuthenticationServices
#endif

private struct JellyAppIconOption: Identifiable, Equatable {
    let id: String
    let alternateIconName: String?
    let previewAssetName: String
    let englishTitle: String
    let chineseTitle: String

    func title(language: AppLanguage) -> String {
        language == .chinese ? chineseTitle : englishTitle
    }

    static let `default` = JellyAppIconOption(
        id: "default",
        alternateIconName: nil,
        previewAssetName: "IconPreviewDefault",
        englishTitle: "Classic Jelly",
        chineseTitle: "经典果冻"
    )

    static let all: [JellyAppIconOption] = [
        .default,
        JellyAppIconOption(
            id: "blush",
            alternateIconName: "AppIconBlush",
            previewAssetName: "IconPreviewBlush",
            englishTitle: "Blush Jelly",
            chineseTitle: "粉雾果冻"
        ),
        JellyAppIconOption(
            id: "orbit",
            alternateIconName: "AppIconOrbit",
            previewAssetName: "IconPreviewOrbit",
            englishTitle: "Blue Orbit",
            chineseTitle: "蓝轨果冻"
        ),
        JellyAppIconOption(
            id: "meadow",
            alternateIconName: "AppIconMeadow",
            previewAssetName: "IconPreviewMeadow",
            englishTitle: "Green Meadow",
            chineseTitle: "青野果冻"
        ),
        JellyAppIconOption(
            id: "graphite",
            alternateIconName: "AppIconGraphite",
            previewAssetName: "IconPreviewGraphite",
            englishTitle: "Graphite Stamp",
            chineseTitle: "石墨印章"
        ),
        JellyAppIconOption(
            id: "pebble",
            alternateIconName: "AppIconPebble",
            previewAssetName: "IconPreviewPebble",
            englishTitle: "Pebble Mono",
            chineseTitle: "卵石黑白"
        ),
    ]

    static func current(alternateIconName: String?) -> JellyAppIconOption {
        all.first(where: { $0.alternateIconName == alternateIconName }) ?? .default
    }
}

private struct AppIconPickerSheet: View {
    let selectedIconID: String
    let onSelect: (JellyAppIconOption) -> Void

    @Environment(\.appThemeMode) private var themeMode
    @Environment(\.appLanguage) private var language
    @Environment(\.dismiss) private var dismiss

    private let columns = [
        GridItem(.flexible(), spacing: 14),
        GridItem(.flexible(), spacing: 14)
    ]

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                Text(language == .chinese ? "应用图标" : "App Icons")
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundStyle(ThemeTokens.Colors.textPrimary)
                    .padding(.top, 10)

                Text(language == .chinese ? "新增 5 套图标，点击后立即应用。" : "Five new icon styles are ready. Tap to apply instantly.")
                    .font(ThemeTokens.Typography.caption)
                    .foregroundStyle(ThemeTokens.Colors.textSecondary)

                LazyVGrid(columns: columns, spacing: 14) {
                    ForEach(JellyAppIconOption.all) { option in
                        Button {
                            onSelect(option)
                            dismiss()
                        } label: {
                            JellyCard {
                                VStack(alignment: .leading, spacing: 12) {
                                    Image(option.previewAssetName)
                                        .resizable()
                                        .aspectRatio(1, contentMode: .fit)
                                        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))

                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(option.title(language: language))
                                            .font(.system(size: 16, weight: .bold, design: .rounded))
                                            .foregroundStyle(ThemeTokens.Colors.textPrimary)
                                            .lineLimit(1)

                                        Text(option.alternateIconName == nil ? localized("Default", "默认") : localized("Alternate", "替换"))
                                            .font(.system(size: 12, weight: .bold, design: .rounded))
                                            .foregroundStyle(ThemeTokens.Colors.textSecondary)
                                    }

                                    HStack {
                                        Spacer()
                                        Text(option.id == selectedIconID ? localized("Current", "当前") : localized("Use", "使用"))
                                            .font(.system(size: 12, weight: .bold, design: .rounded))
                                            .foregroundStyle(option.id == selectedIconID ? ThemeTokens.Colors.backgroundPrimary : ThemeTokens.Colors.textPrimary)
                                            .padding(.horizontal, 10)
                                            .frame(height: 28)
                                            .background(option.id == selectedIconID ? ThemeTokens.accent(for: themeMode) : ThemeTokens.card(for: themeMode))
                                            .clipShape(Capsule())
                                    }
                                }
                                .padding(16)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }

                CapsuleButton(title: L10n.t(.cancel, language)) {
                    dismiss()
                }
            }
            .padding(24)
        }
        .background(ThemeTokens.background(for: themeMode).ignoresSafeArea())
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    private func localized(_ english: String, _ chinese: String) -> String {
        language == .chinese ? chinese : english
    }
}

private struct CheckInIconPickerSheet: View {
    let selectedSelection: CheckInIconSelection
    let onSelect: (CheckInIconSelection) -> Void

    @Environment(\.appThemeMode) private var themeMode
    @Environment(\.appLanguage) private var language
    @Environment(\.dismiss) private var dismiss

    private let columns = [
        GridItem(.flexible(), spacing: 14),
        GridItem(.flexible(), spacing: 14)
    ]

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {
                Text(language == .chinese ? "打卡 Icon" : "Check-in Icons")
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundStyle(ThemeTokens.Colors.textPrimary)
                    .padding(.top, 10)

                Text(language == .chinese ? "当前先支持涂鸦 Emoji 系列，后续可以继续扩展更多系列。" : "Doodle Emoji is ready first. More icon families can be added later.")
                    .font(ThemeTokens.Typography.caption)
                    .foregroundStyle(ThemeTokens.Colors.textSecondary)

                ForEach(CheckInIconCatalog.series) { series in
                    VStack(alignment: .leading, spacing: 14) {
                        Text(series.title(language: language))
                            .font(.system(size: 18, weight: .black, design: .rounded))
                            .foregroundStyle(ThemeTokens.Colors.textPrimary)

                        LazyVGrid(columns: columns, spacing: 14) {
                            ForEach(series.packs) { pack in
                                Button {
                                    onSelect(CheckInIconSelection(seriesID: series.id, packID: pack.id))
                                    dismiss()
                                } label: {
                                    JellyCard {
                                        VStack(alignment: .leading, spacing: 12) {
                                            Image(pack.previewAssetName)
                                                .resizable()
                                                .aspectRatio(1, contentMode: .fill)
                                                .frame(height: 138)
                                                .clipped()
                                                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

                                            Text(pack.title(language: language))
                                                .font(.system(size: 15, weight: .bold, design: .rounded))
                                                .foregroundStyle(ThemeTokens.Colors.textPrimary)
                                                .lineLimit(1)

                                            HStack {
                                                Spacer()
                                                Text(isCurrent(pack) ? localized("Current", "当前") : localized("Use", "使用"))
                                                    .font(.system(size: 12, weight: .bold, design: .rounded))
                                                    .foregroundStyle(isCurrent(pack) ? ThemeTokens.Colors.backgroundPrimary : ThemeTokens.Colors.textPrimary)
                                                    .padding(.horizontal, 10)
                                                    .frame(height: 28)
                                                    .background(isCurrent(pack) ? ThemeTokens.accent(for: themeMode) : ThemeTokens.card(for: themeMode))
                                                    .clipShape(Capsule())
                                            }
                                        }
                                        .padding(16)
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }

                CapsuleButton(title: L10n.t(.cancel, language)) {
                    dismiss()
                }
            }
            .padding(24)
        }
        .background(ThemeTokens.background(for: themeMode).ignoresSafeArea())
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    private func isCurrent(_ pack: CheckInIconPackOption) -> Bool {
        selectedSelection.seriesID == pack.seriesID && selectedSelection.packID == pack.id
    }

    private func localized(_ english: String, _ chinese: String) -> String {
        language == .chinese ? chinese : english
    }
}

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

#if DEBUG
private struct MockStagingLoginSheet: View {
    let onLogin: (String, String, String) -> Void

    @Environment(\.appThemeMode) private var themeMode
    @Environment(\.appLanguage) private var language
    @Environment(\.dismiss) private var dismiss
    @State private var nickname = "Zhang Dev"
    @State private var email = "dev@jellytodo.local"
    @State private var debugSecret = ""

    var body: some View {
        BottomSheetContainer(title: language == .chinese ? "开发账号登录" : "Mock Staging Login") {
            VStack(spacing: 16) {
                TextField("Nickname", text: $nickname)
                    .textInputAutocapitalization(.words)
                    .font(ThemeTokens.Typography.body)
                    .padding(.horizontal, 20)
                    .frame(height: ThemeTokens.Metrics.controlHeight)
                    .background(ThemeTokens.card(for: themeMode))
                    .clipShape(Capsule())

                TextField("Email", text: $email)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .font(ThemeTokens.Typography.body)
                    .padding(.horizontal, 20)
                    .frame(height: ThemeTokens.Metrics.controlHeight)
                    .background(ThemeTokens.card(for: themeMode))
                    .clipShape(Capsule())

                SecureField("Debug Secret", text: $debugSecret)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .font(ThemeTokens.Typography.body)
                    .padding(.horizontal, 20)
                    .frame(height: ThemeTokens.Metrics.controlHeight)
                    .background(ThemeTokens.card(for: themeMode))
                    .clipShape(Capsule())

                Text(language == .chinese ? "仅 DEBUG/staging 使用，用来绕过免费开发者账号无法调起 Apple 登录的问题。" : "DEBUG/staging only. This lets us test account flow before Apple capability is available.")
                    .font(ThemeTokens.Typography.caption)
                    .foregroundStyle(ThemeTokens.Colors.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                HStack(spacing: 16) {
                    CapsuleButton(title: L10n.t(.cancel, language)) {
                        dismiss()
                    }

                    CapsuleButton(title: language == .chinese ? "登录" : "Login") {
                        onLogin(nickname, email, debugSecret)
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.height(430)])
        .presentationDragIndicator(.hidden)
    }
}
#endif

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
    @Environment(\.appTextScale) private var textScale
    @State private var showingProfileEditor = false
    @State private var showingThemePicker = false
    @State private var showingLanguagePicker = false
    @State private var showingAppIconPicker = false
    @State private var showingCheckInIconPicker = false
    @State private var showingBackupPoints = false
    @State private var showingCloudBackupPoints = false
    @State private var backupPendingRestore: LocalBackupSnapshot?
    @State private var cloudBackupPendingRestore: CloudBackupSnapshot?
    @State private var selectedAppIconID = JellyAppIconOption.default.id
#if DEBUG
    @State private var showingMockStagingLogin = false
#endif

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                Text(L10n.t(.settings, language))
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundStyle(ThemeTokens.Colors.textPrimary)
                    .padding(.top, 26)

                plusCard

                settingsLabel(backupText(english: "Account", chinese: "账号"))
                accountGroup

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
        .onAppear {
            selectedAppIconID = currentAppIcon.id
        }
        .sheet(isPresented: $showingProfileEditor) {
            ProfileEditorSheet(profile: store.profile) { profile in
                store.updateProfile(profile)
            }
        }
        .sheet(isPresented: $showingAppIconPicker) {
            AppIconPickerSheet(selectedIconID: selectedAppIconID) { option in
                applyAppIcon(option)
            }
        }
        .sheet(isPresented: $showingCheckInIconPicker) {
            CheckInIconPickerSheet(selectedSelection: store.settings.checkInIconSelection) { selection in
                var updated = store.settings
                updated.checkInIconSelection = selection
                store.updateSettings(updated)
            }
        }
        .confirmationDialog(L10n.t(.theme, language), isPresented: $showingThemePicker, titleVisibility: .visible) {
            ForEach(AppThemeStyle.allCases) { style in
                Button(style.title(language: language)) {
                    var updated = store.settings
                    updated.themeMode = AppThemeMode.make(color: updated.themeMode.color, style: style)
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
#if DEBUG
        .sheet(isPresented: $showingMockStagingLogin) {
            MockStagingLoginSheet { nickname, email, debugSecret in
                Task {
                    await store.mockStagingAccountLogin(
                        nickname: nickname,
                        email: email,
                        debugSecret: debugSecret
                    )
                }
            }
        }
#endif
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

    @ViewBuilder
    private var settingsBackground: some View {
        if store.settings.themeMode.isJelly {
            let accent = ThemeTokens.accent(for: store.settings.themeMode)
            let soft = ThemeTokens.accentSoft(for: store.settings.themeMode)

            ZStack {
                LinearGradient(
                    colors: [
                        ThemeTokens.background(for: store.settings.themeMode),
                        .white,
                        soft.opacity(0.32)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                Circle()
                    .fill(accent.opacity(0.16))
                    .blur(radius: 72)
                    .frame(width: 240, height: 240)
                    .offset(x: 160, y: -220)

                Circle()
                    .fill(.white.opacity(0.94))
                    .blur(radius: 52)
                    .frame(width: 220, height: 220)
                    .offset(x: -130, y: -110)

                RoundedRectangle(cornerRadius: 160, style: .continuous)
                    .fill(soft.opacity(0.24))
                    .blur(radius: 48)
                    .frame(width: 360, height: 260)
                    .offset(x: -120, y: 240)
            }
        } else {
            store.settings.themeMode.color == .blackWhite && !store.settings.themeMode.isJelly ? ThemeTokens.Colors.backgroundSoft : ThemeTokens.background(for: store.settings.themeMode)
        }
    }

    private var groupBackground: Color {
        ThemeTokens.groupBackground(for: store.settings.themeMode)
    }

    private var controlBackground: Color {
        ThemeTokens.controlBackground(for: store.settings.themeMode)
    }

    private var iconBackground: Color {
        ThemeTokens.iconBackground(for: store.settings.themeMode)
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
            .glassPanel(themeMode: store.settings.themeMode, cornerRadius: 24)
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
            .glassPanel(themeMode: store.settings.themeMode, cornerRadius: 24)
        }
        .buttonStyle(.plain)
    }

    private var accountGroup: some View {
        VStack(spacing: 0) {
            settingLine(
                icon: store.accountState.isSignedIn ? "person.crop.circle.badge.checkmark" : "person.crop.circle.badge.plus",
                title: backupText(english: "Apple Account", chinese: "Apple 账号"),
                value: accountStatusValue
            )

            if let user = store.accountState.user {
                settingDivider

                settingLine(
                    icon: "number.circle.fill",
                    title: backupText(english: "UID", chinese: "用户 ID"),
                    value: user.shortID
                )

                if let email = user.email, !email.isEmpty {
                    settingDivider

                    settingLine(
                        icon: "envelope.fill",
                        title: backupText(english: "Email", chinese: "邮箱"),
                        value: String(email.prefix(22))
                    )
                }
            }

            if !store.accountState.message.isEmpty {
                settingDivider

                settingLine(
                    icon: "text.bubble.fill",
                    title: backupText(english: "Status", chinese: "状态"),
                    value: store.accountState.message
                )
            }

            settingDivider

            if store.accountState.isSignedIn {
                Button {
                    Task {
                        await store.logoutAccount()
                    }
                } label: {
                    settingLine(
                        icon: "rectangle.portrait.and.arrow.right.fill",
                        title: backupText(english: "Sign Out", chinese: "退出登录"),
                        value: backupText(english: "Keep Local", chinese: "保留本地"),
                        showsChevron: true
                    )
                }
                .buttonStyle(.plain)
            } else {
#if APPLE_SIGN_IN_ENABLED
                SignInWithAppleButton(.signIn) { request in
                    request.requestedScopes = [.fullName, .email]
                } onCompletion: { result in
                    handleAppleSignIn(result)
                }
                .signInWithAppleButtonStyle(.black)
                .frame(height: 54)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
#else
                settingLine(
                    icon: "apple.logo",
                    title: backupText(english: "Apple Sign In", chinese: "Apple 登录"),
                    value: backupText(english: "Developer Required", chinese: "需付费账号")
                )
#endif

#if DEBUG
                settingDivider

                Button {
                    showingMockStagingLogin = true
                } label: {
                    settingLine(
                        icon: "hammer.circle.fill",
                        title: backupText(english: "Mock Staging Login", chinese: "开发账号登录"),
                        value: backupText(english: "DEBUG", chinese: "调试"),
                        showsChevron: true
                    )
                }
                .buttonStyle(.plain)
#endif
            }
        }
        .glassPanel(themeMode: store.settings.themeMode, cornerRadius: 24)
    }

    private var baseSettingsGroup: some View {
        VStack(spacing: 0) {
            HStack(spacing: 14) {
                settingIcon(systemName: "circle.lefthalf.filled")
                Text(backupText(english: "Color", chinese: "色彩"))
                    .font(settingFont)
                    .foregroundStyle(ThemeTokens.Colors.textPrimary)

                Spacer()

                HStack(spacing: 4) {
                    ForEach(AppThemeColor.allCases) { color in
                        Button {
                            var updated = store.settings
                            updated.themeMode = AppThemeMode.make(color: color, style: updated.themeMode.style)
                            store.updateSettings(updated)
                        } label: {
                            Circle()
                                .fill(ThemeTokens.accent(for: AppThemeMode.make(color: color, style: .solid)))
                                .frame(width: 24, height: 24)
                                .overlay(
                                    Circle()
                                        .stroke(store.settings.themeMode.color == color ? currentAccent : Color.clear, lineWidth: 2)
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
                    value: store.settings.themeMode.style.title(language: language),
                    showsChevron: true
                )
            }
            .buttonStyle(.plain)

            settingDivider

            HStack(spacing: 14) {
                settingIcon(systemName: "squareshape.split.2x2")

                VStack(alignment: .leading, spacing: 3) {
                    Text(backupText(english: "Edge Detail", chinese: "边缘质感"))
                        .font(settingFont)
                        .foregroundStyle(ThemeTokens.Colors.textPrimary)

                    Text(backupText(english: "Subtle highlight for item edges", chinese: "给 item 增加轻微高光描边"))
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(ThemeTokens.Colors.textSecondary)
                        .lineLimit(1)
                }

                Spacer()

                Toggle("", isOn: Binding(
                    get: { store.settings.itemEdgeEffectEnabled },
                    set: { newValue in
                        var updated = store.settings
                        updated.itemEdgeEffectEnabled = newValue
                        store.updateSettings(updated)
                    }
                ))
                .labelsHidden()
                .tint(currentAccent)
            }
            .settingRowFrame()

            settingDivider

            Button {
                showingAppIconPicker = true
            } label: {
                settingLine(
                    icon: "app.badge.fill",
                    title: L10n.t(.appIcon, language),
                    value: currentAppIcon.title(language: language),
                    badge: "NEW",
                    showsChevron: true
                )
            }
            .buttonStyle(.plain)

            settingDivider

            Button {
                showingCheckInIconPicker = true
            } label: {
                settingLine(
                    icon: "face.smiling.fill",
                    title: backupText(english: "Check-in Icons", chinese: "打卡 Icon"),
                    value: currentCheckInSeries.title(language: language),
                    showsChevron: true
                )
            }
            .buttonStyle(.plain)

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

                Text(backupText(english: "Text Size", chinese: "字体大小"))
                    .font(settingFont)
                    .foregroundStyle(ThemeTokens.Colors.textPrimary)

                Spacer()

                HStack(spacing: 4) {
                    ForEach(AppTextScale.allCases) { scale in
                        Button {
                            var updated = store.settings
                            updated.textScale = scale
                            store.updateSettings(updated)
                        } label: {
                            Text(scale.title(language: language))
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .foregroundStyle(store.settings.textScale == scale ? ThemeTokens.Colors.backgroundPrimary : ThemeTokens.Colors.textPrimary)
                                .frame(width: 34, height: 28)
                                .background(store.settings.textScale == scale ? currentAccent : Color.clear)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 6)
                .frame(height: 34)
                .background(controlBackground)
                .clipShape(Capsule())
            }
            .settingRowFrame()
        }
        .glassPanel(themeMode: store.settings.themeMode, cornerRadius: 24)
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
        .glassPanel(themeMode: store.settings.themeMode, cornerRadius: 24)
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
        .glassPanel(themeMode: store.settings.themeMode, cornerRadius: 24)
    }

    private var aboutGroup: some View {
        VStack(spacing: 0) {
            settingLine(icon: "sparkles", title: L10n.t(.designConcept, language), value: L10n.t(.bigJelly, language))
            settingDivider
            settingLine(icon: "number", title: L10n.t(.version, language), value: "1.0")
        }
        .glassPanel(themeMode: store.settings.themeMode, cornerRadius: 24)
    }

    private var settingFont: Font {
        ThemeTokens.Typography.body(for: textScale)
    }

    private var accountStatusValue: String {
        switch store.accountState.status {
        case .signedIn:
            return store.accountState.user?.nickname.isEmpty == false
                ? store.accountState.user?.nickname ?? backupText(english: "Signed In", chinese: "已登录")
                : backupText(english: "Signed In", chinese: "已登录")
        case .signingIn:
            return backupText(english: "Signing In", chinese: "登录中")
        case .failed:
            return backupText(english: "Failed", chinese: "失败")
        case .signedOut:
            return backupText(english: "Not Signed In", chinese: "未登录")
        }
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

    private var currentAppIcon: JellyAppIconOption {
#if canImport(UIKit)
        JellyAppIconOption.current(alternateIconName: UIApplication.shared.alternateIconName)
#else
        .default
#endif
    }

    private var currentCheckInPack: CheckInIconPackOption {
        CheckInIconCatalog.packOption(for: store.settings.checkInIconSelection)
    }

    private var currentCheckInSeries: CheckInIconSeriesOption {
        CheckInIconCatalog.seriesOption(for: currentCheckInPack.seriesID)
    }

    private var settingDivider: some View {
        Rectangle()
            .fill(store.settings.themeMode.isJelly ? .white.opacity(0.54) : iconBackground.opacity(0.75))
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

#if APPLE_SIGN_IN_ENABLED
    private func handleAppleSignIn(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case let .success(authorization):
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                  let identityTokenData = credential.identityToken,
                  let identityToken = String(data: identityTokenData, encoding: .utf8)
            else { return }

            let authorizationCode = credential.authorizationCode.flatMap {
                String(data: $0, encoding: .utf8)
            }
            let displayName = [credential.fullName?.givenName, credential.fullName?.familyName]
                .compactMap { $0 }
                .joined(separator: " ")
            let normalizedName = displayName.isEmpty ? nil : displayName

            Task {
                await store.signInWithApple(
                    identityToken: identityToken,
                    authorizationCode: authorizationCode,
                    displayName: normalizedName,
                    email: credential.email
                )
            }

        case .failure:
            break
        }
    }
#endif

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
            .fill(store.settings.themeMode.isJelly ? .white.opacity(0.68) : iconBackground)
            .frame(width: 38, height: 38)
            .overlay(
                Image(systemName: systemName)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(currentAccent)
            )
            .overlay(
                Circle()
                    .stroke(.white.opacity(store.settings.themeMode.isJelly ? 0.9 : 0), lineWidth: 1.4)
            )
            .shadow(color: .white.opacity(store.settings.themeMode.isJelly ? 0.78 : 0), radius: 4, x: -1, y: -1)
            .shadow(color: .black.opacity(store.settings.themeMode.isJelly ? 0.05 : 0), radius: 10, x: 0, y: 6)
    }

    private var initials: String {
        let trimmed = store.profile.nickname.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "JT" : String(trimmed.prefix(2)).uppercased()
    }

    private func backupText(english: String, chinese: String) -> String {
        language == .chinese ? chinese : english
    }

    private func applyAppIcon(_ option: JellyAppIconOption) {
#if canImport(UIKit)
        guard UIApplication.shared.supportsAlternateIcons else { return }
        UIApplication.shared.setAlternateIconName(option.alternateIconName) { _ in
            selectedAppIconID = JellyAppIconOption.current(alternateIconName: UIApplication.shared.alternateIconName).id
        }
#endif
    }
}

private extension View {
    func settingRowFrame() -> some View {
        self
            .padding(.horizontal, 14)
            .frame(height: 58)
    }

    @ViewBuilder
    func glassPanel(themeMode: AppThemeMode, cornerRadius: CGFloat) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)

        if themeMode.isJelly {
            self
                .background(
                    shape
                        .fill(.white.opacity(0.58))
                        .background(
                            shape.fill(
                                LinearGradient(
                                    colors: [
                                        .white.opacity(0.74),
                                        ThemeTokens.accentSoft(for: themeMode).opacity(0.38)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                        )
                        .overlay(
                            shape.stroke(
                                LinearGradient(
                                    colors: [
                                        .white.opacity(0.98),
                                        ThemeTokens.accent(for: themeMode).opacity(0.14)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1.15
                            )
                        )
                        .overlay(alignment: .top) {
                            Capsule(style: .continuous)
                                .fill(.white.opacity(0.84))
                                .frame(height: 12)
                                .padding(.horizontal, 26)
                                .padding(.top, 10)
                                .blur(radius: 6)
                        }
                        .shadow(color: .white.opacity(0.9), radius: 6, x: -2, y: -2)
                        .shadow(color: ThemeTokens.accent(for: themeMode).opacity(0.08), radius: 16, x: 0, y: 8)
                        .shadow(color: .black.opacity(0.05), radius: 18, x: 0, y: 12)
                )
                .clipShape(shape)
        } else {
            self
                .background(ThemeTokens.groupBackground(for: themeMode))
                .clipShape(shape)
        }
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
