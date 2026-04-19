import SwiftUI

#if DEBUG
private enum DebugPanel: Identifiable {
    case seed
    case cloud
    case database

    var id: String {
        switch self {
        case .seed:
            return "seed"
        case .cloud:
            return "cloud"
        case .database:
            return "database"
        }
    }
}

struct DebugPomodoroSeedOverlay: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.appThemeMode) private var themeMode

    @AppStorage("debug.floatingMenu.isVisible") private var isVisible = true
    @State private var isExpanded = false
    @State private var activePanel: DebugPanel?
    @State private var position = CGPoint(x: 330, y: 92)
    @GestureState private var dragTranslation: CGSize = .zero

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .topLeading) {
                if isVisible {
                    if isExpanded {
                        debugMenu
                            .position(menuPosition(in: proxy.size))
                            .zIndex(999)
                            .transition(.asymmetric(
                                insertion: .scale(scale: 0.82, anchor: .top).combined(with: .opacity),
                                removal: .scale(scale: 0.92, anchor: .top).combined(with: .opacity)
                            ))
                    }

                    floatingButton(in: proxy.size)
                        .position(currentButtonPosition(in: proxy.size))
                        .zIndex(1_000)
                        .transition(.scale(scale: 0.86).combined(with: .opacity))
                } else {
                    restoreButton
                        .position(x: max(proxy.size.width - 42, 42), y: 92)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .ignoresSafeArea(.keyboard)
        .animation(.spring(response: 0.28, dampingFraction: 0.78), value: isVisible)
        .animation(.spring(response: 0.28, dampingFraction: 0.78), value: isExpanded)
        .sheet(item: $activePanel) { panel in
            switch panel {
            case .seed:
                DebugPomodoroSeedSheet()
                    .environmentObject(store)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            case .cloud:
                DebugCloudSheet()
                    .environmentObject(store)
                    .presentationDetents([.medium])
                    .presentationDragIndicator(.visible)
            case .database:
                DebugDatabaseSheet()
                    .environmentObject(store)
                    .presentationDetents([.medium])
                    .presentationDragIndicator(.visible)
            }
        }
    }

    private var debugMenu: some View {
        VStack(spacing: 10) {
            debugActionButton(title: "统计", systemImage: "chart.pie.fill") {
                activePanel = .seed
                isExpanded = false
            }

            debugActionButton(title: "云测", systemImage: "cloud.fill") {
                activePanel = .cloud
                isExpanded = false
            }

            debugActionButton(title: "数据", systemImage: "externaldrive.fill") {
                activePanel = .database
                isExpanded = false
            }

            debugActionButton(title: "关闭", systemImage: "xmark") {
                withAnimation(.spring(response: 0.28, dampingFraction: 0.78)) {
                    isExpanded = false
                    isVisible = false
                }
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 7)
        .background(ThemeTokens.card(for: themeMode).opacity(0.96))
        .clipShape(Capsule())
        .modifier(JellyCardModifier(shadowStyle: .standard))
        .contentShape(Capsule())
    }

    private func floatingButton(in size: CGSize) -> some View {
        Image(systemName: "gearshape.fill")
            .font(.system(size: 20, weight: .bold))
            .foregroundStyle(ThemeTokens.Colors.backgroundPrimary)
            .frame(width: 72, height: 72)
            .background(ThemeTokens.accent(for: themeMode))
            .clipShape(Circle())
            .shadow(color: .white.opacity(0.45), radius: 3, x: -1, y: -1)
            .shadow(color: .black.opacity(0.18), radius: 12, x: 0, y: 8)
        .frame(width: 72, height: 72)
        .contentShape(Circle())
        .onTapGesture {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.78)) {
                isExpanded.toggle()
            }
        }
        .highPriorityGesture(
            DragGesture(minimumDistance: 8, coordinateSpace: .global)
                .updating($dragTranslation) { value, state, transaction in
                    transaction.disablesAnimations = true
                    state = value.translation
                }
                .onEnded { value in
                    let finalPosition = clamped(
                        CGPoint(
                            x: position.x + value.translation.width,
                            y: position.y + value.translation.height
                        ),
                        in: size
                    )

                    var transaction = Transaction()
                    transaction.disablesAnimations = true
                    withTransaction(transaction) {
                        position = finalPosition
                    }
                }
        )
        .accessibilityLabel("调试菜单")
    }

    private var restoreButton: some View {
        Button {
        } label: {
            Image(systemName: "gearshape.fill")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(ThemeTokens.accent(for: themeMode))
                .frame(width: 76, height: 76)
                .background(ThemeTokens.card(for: themeMode).opacity(0.9))
                .clipShape(Circle())
                .opacity(0.72)
                .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 5)
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
        .highPriorityGesture(LongPressGesture(minimumDuration: 0.45).onEnded { _ in
            withAnimation(.spring(response: 0.28, dampingFraction: 0.78)) {
                isVisible = true
                isExpanded = true
            }
        })
        .accessibilityLabel("长按恢复调试菜单")
    }

    private func debugActionButton(title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: systemImage)
                    .font(.system(size: 18, weight: .bold))

                Text(title)
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .lineLimit(1)
            }
            .foregroundStyle(ThemeTokens.Colors.textPrimary)
            .frame(width: 56, height: 56)
            .background(ThemeTokens.background(for: themeMode).opacity(0.72))
            .clipShape(Circle())
        }
        .buttonStyle(.plain)
    }

    private func menuPosition(in size: CGSize) -> CGPoint {
        let buttonPosition = currentButtonPosition(in: size)
        let menuHeight: CGFloat = 292
        let buttonRadius: CGFloat = 36
        let gap: CGFloat = 14
        let lowerLimit = menuHeight / 2 + 20
        let upperLimit = max(size.height - menuHeight / 2 - 20, lowerLimit)
        let belowY = buttonPosition.y + buttonRadius + gap + menuHeight / 2
        let aboveY = buttonPosition.y - buttonRadius - gap - menuHeight / 2
        let preferredY = belowY <= upperLimit ? belowY : aboveY
        let y = min(max(preferredY, lowerLimit), upperLimit)
        return CGPoint(x: buttonPosition.x, y: y)
    }

    private func currentButtonPosition(in size: CGSize) -> CGPoint {
        return clamped(
            CGPoint(
                x: position.x + dragTranslation.width,
                y: position.y + dragTranslation.height
            ),
            in: size
        )
    }

    private func clamped(_ point: CGPoint, in size: CGSize) -> CGPoint {
        let x = min(max(point.x, 54), max(size.width - 54, 54))
        let y = min(max(point.y, 70), max(size.height - 96, 70))
        return CGPoint(x: x, y: y)
    }
}

private struct DebugPomodoroSeedSheet: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.appThemeMode) private var themeMode
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        let summary = store.debugPomodoroSeedSummary

        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {
                Text("任务计时桩数据")
                    .font(ThemeTokens.Typography.pageTitle)
                    .foregroundStyle(ThemeTokens.Colors.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)

                JellyCard {
                    VStack(spacing: 0) {
                        debugRow(title: "Plan 数", value: "\(summary.plans)")
                        Divider().overlay(ThemeTokens.Colors.subtleLine)
                        debugRow(title: "任务总数", value: "\(summary.todos)")
                        Divider().overlay(ThemeTokens.Colors.subtleLine)
                        debugRow(title: "Today 任务", value: "\(summary.todayTodos)")
                        Divider().overlay(ThemeTokens.Colors.subtleLine)
                        debugRow(title: "Focus Session", value: "\(summary.sessions)")
                        Divider().overlay(ThemeTokens.Colors.subtleLine)
                        debugRow(title: "今日学习时长", value: summary.todaySeconds.formattedMinutesText())
                    }
                    .padding(20)
                }

                Text("用于测试 Plan、Today 和 Pomodoro Stats。桩数据会混合学习、项目、健康、阅读、生活等场景，并覆盖 Today / Week / Month 三档统计。")
                    .font(ThemeTokens.Typography.caption)
                    .foregroundStyle(ThemeTokens.Colors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                VStack(spacing: 12) {
                    HStack(spacing: 12) {
                        CapsuleButton(
                            title: "基础 24",
                            fill: ThemeTokens.accent(for: themeMode),
                            foreground: ThemeTokens.Colors.backgroundPrimary
                        ) {
                            store.seedPomodoroChartDebugData()
                        }

                        CapsuleButton(title: "清理桩数据") {
                            store.clearPomodoroChartDebugData()
                        }
                    }

                    HStack(spacing: 12) {
                        CapsuleButton(
                            title: "中压 50",
                            fill: ThemeTokens.accentSoft(for: themeMode),
                            minWidth: 100
                        ) {
                            store.seedPomodoroChartPressureDebugData()
                        }

                        CapsuleButton(
                            title: "中高 120",
                            fill: ThemeTokens.accentSoft(for: themeMode),
                            minWidth: 108
                        ) {
                            store.seedPlanTodayMediumPressureDebugData()
                        }
                    }

                    CapsuleButton(
                        title: "高压 300",
                        fill: ThemeTokens.accentSoft(for: themeMode),
                        minWidth: 220
                    ) {
                        store.seedPlanTodayHeavyPressureDebugData()
                    }
                }

                CapsuleButton(title: "关闭") {
                    dismiss()
                }

                Spacer(minLength: 0)
            }
            .padding(24)
        }
        .background(ThemeTokens.background(for: themeMode).ignoresSafeArea())
    }
}

private struct DebugCloudSheet: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.appThemeMode) private var themeMode
    @Environment(\.dismiss) private var dismiss

    private var cloudDebugCard: some View {
        JellyCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("云测接口")
                            .font(ThemeTokens.Typography.body)
                            .foregroundStyle(ThemeTokens.Colors.textPrimary)

                        Text("101.43.104.105")
                            .font(ThemeTokens.Typography.caption)
                            .foregroundStyle(ThemeTokens.Colors.textSecondary)
                    }

                    Spacer()

                    cloudStateBadge
                }

                Text(store.cloudDebugState.message)
                    .font(ThemeTokens.Typography.caption)
                    .foregroundStyle(ThemeTokens.Colors.textSecondary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)

                HStack(spacing: 12) {
                    CapsuleButton(
                        title: "检查云端",
                        fill: ThemeTokens.accentSoft(for: themeMode),
                        minWidth: 104
                    ) {
                        Task {
                            await store.checkCloudHealth()
                        }
                    }

                    CapsuleButton(
                        title: "拉取云测数据",
                        fill: ThemeTokens.accent(for: themeMode),
                        foreground: ThemeTokens.Colors.backgroundPrimary,
                        minWidth: 132
                    ) {
                        Task {
                            await store.importCloudStagingData()
                        }
                    }
                }
            }
            .padding(18)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("云测调试")
                .font(ThemeTokens.Typography.pageTitle)
                .foregroundStyle(ThemeTokens.Colors.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.72)

            Text("用于检查 staging 服务连通性，并拉取云测数据到本地。这里不做正式同步，也不接生产账号。")
                .font(ThemeTokens.Typography.caption)
                .foregroundStyle(ThemeTokens.Colors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            cloudDebugCard

            CapsuleButton(title: "关闭") {
                dismiss()
            }

            Spacer(minLength: 0)
        }
        .padding(24)
        .background(ThemeTokens.background(for: themeMode).ignoresSafeArea())
    }

    private var cloudStateBadge: some View {
        let title: String
        let opacity: Double

        switch store.cloudDebugState {
        case .idle:
            title = "Ready"
            opacity = 0.58
        case .loading:
            title = "Loading"
            opacity = 0.72
        case .success:
            title = "OK"
            opacity = 1
        case .failure:
            title = "Error"
            opacity = 0.86
        }

        return Text(title)
            .font(.system(size: 13, weight: .bold, design: .rounded))
            .foregroundStyle(ThemeTokens.Colors.backgroundPrimary)
            .padding(.horizontal, 14)
            .frame(height: 32)
            .background(ThemeTokens.accent(for: themeMode).opacity(opacity))
            .clipShape(Capsule())
    }
}

private struct DebugDatabaseSheet: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.appThemeMode) private var themeMode
    @Environment(\.dismiss) private var dismiss

    private var databaseDebugCard: some View {
        let summary = store.databaseDebugSummary
        let entitlement = summary.entitlement

        return JellyCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("本地数据库")
                            .font(ThemeTokens.Typography.body)
                            .foregroundStyle(ThemeTokens.Colors.textPrimary)

                        Text("SQLite · entitlement_state 可手动 mock")
                            .font(ThemeTokens.Typography.caption)
                            .foregroundStyle(ThemeTokens.Colors.textSecondary)
                    }

                    Spacer()

                    Text(entitlement.tier.title)
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(ThemeTokens.Colors.backgroundPrimary)
                        .padding(.horizontal, 14)
                        .frame(height: 32)
                        .background(ThemeTokens.accent(for: themeMode).opacity(entitlement.tier == .pro ? 1 : 0.58))
                        .clipShape(Capsule())
                }

                VStack(spacing: 0) {
                    debugRow(title: "plans", value: "\(summary.plans)")
                    Divider().overlay(ThemeTokens.Colors.subtleLine)
                    debugRow(title: "todo_items", value: "\(summary.todos)")
                    Divider().overlay(ThemeTokens.Colors.subtleLine)
                    debugRow(title: "today items", value: "\(summary.todayTodos)")
                    Divider().overlay(ThemeTokens.Colors.subtleLine)
                    debugRow(title: "pomodoro_sessions", value: "\(summary.sessions)")
                    Divider().overlay(ThemeTokens.Colors.subtleLine)
                    debugRow(title: "cloud sync", value: entitlement.isCloudSyncAvailable ? "ON" : "OFF")
                }

                Text("这个入口用于开发期模拟订阅状态：Free 默认只保留本地数据；Pro 会打开云同步资格。")
                    .font(ThemeTokens.Typography.caption)
                    .foregroundStyle(ThemeTokens.Colors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 12) {
                    CapsuleButton(
                        title: "Mock Free",
                        fill: ThemeTokens.accentSoft(for: themeMode),
                        minWidth: 112
                    ) {
                        store.mockEntitlement(.free)
                    }

                    CapsuleButton(
                        title: "Mock Pro",
                        fill: ThemeTokens.accent(for: themeMode),
                        foreground: ThemeTokens.Colors.backgroundPrimary,
                        minWidth: 112
                    ) {
                        store.mockEntitlement(.pro)
                    }
                }
            }
            .padding(18)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("数据与订阅")
                .font(ThemeTokens.Typography.pageTitle)
                .foregroundStyle(ThemeTokens.Colors.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.72)

            Text("用于查看本地 SQLite 摘要，并模拟 Free / Pro 权益。后续订阅联调、云同步闸口都可以从这里扩展。")
                .font(ThemeTokens.Typography.caption)
                .foregroundStyle(ThemeTokens.Colors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            databaseDebugCard

            CapsuleButton(title: "关闭") {
                dismiss()
            }

            Spacer(minLength: 0)
        }
        .padding(24)
        .background(ThemeTokens.background(for: themeMode).ignoresSafeArea())
    }
}

private func debugRow(title: String, value: String) -> some View {
    HStack {
        Text(title)
            .font(ThemeTokens.Typography.body)
            .foregroundStyle(ThemeTokens.Colors.textSecondary)

        Spacer()

        Text(value)
            .font(ThemeTokens.Typography.body)
            .foregroundStyle(ThemeTokens.Colors.textPrimary)
    }
    .padding(.vertical, 10)
}
#endif
