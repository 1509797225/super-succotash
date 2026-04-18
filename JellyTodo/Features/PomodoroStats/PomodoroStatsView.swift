import SwiftUI

struct PomodoroStatsView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.appLanguage) private var language
    let initialRelatedTodoID: UUID?

    @State private var range: PomodoroStatsRange = .today
    @State private var selectedMode: PomodoroTimerMode = .focus

    init(initialRelatedTodoID: UUID? = nil) {
        self.initialRelatedTodoID = initialRelatedTodoID
    }

    var body: some View {
        let stats = store.stats(for: range)
        let segments = store.chartSegments(for: range)

        ScrollView {
            VStack(alignment: .leading, spacing: ThemeTokens.Metrics.sectionSpacing) {
                timerCard
                statsRangeSelector

                JellyCard {
                    VStack(spacing: 24) {
                        DonutChartView(
                            segments: segments,
                            centerTitle: stats.completedPomodoros == 0 ? "0%" : "\(Int(stats.goalRate * 100))%",
                            centerSubtitle: stats.completedPomodoros == 0 ? L10n.t(.noPomodoroData, language) : L10n.t(.goalRate, language)
                        )

                        VStack(spacing: 12) {
                            legendRow(title: PomodoroTimerMode.focus.title(language: language), opacity: 1.0)
                            legendRow(title: PomodoroTimerMode.shortBreak.title(language: language), opacity: 0.72)
                            legendRow(title: PomodoroTimerMode.longBreak.title(language: language), opacity: 0.44)
                        }
                    }
                    .padding(24)
                    .frame(maxWidth: .infinity)
                }

                SectionCard(title: L10n.t(.stats, language)) {
                    StatRow(title: L10n.t(.focusTime, language), value: stats.focusSeconds.formattedMinutesText())
                    Divider().overlay(ThemeTokens.Colors.subtleLine)
                    StatRow(title: L10n.t(.breakTime, language), value: stats.breakSeconds.formattedMinutesText())
                    Divider().overlay(ThemeTokens.Colors.subtleLine)
                    StatRow(title: L10n.t(.completed, language), value: "\(stats.completedPomodoros)")
                    Divider().overlay(ThemeTokens.Colors.subtleLine)
                    StatRow(title: L10n.t(.goalRate, language), value: "\(Int(stats.goalRate * 100))%")
                }
            }
            .padding(.horizontal, ThemeTokens.Metrics.horizontalPadding)
            .padding(.top, 24)
            .padding(.bottom, 32)
        }
        .background(ThemeTokens.background(for: store.settings.themeMode).ignoresSafeArea())
        .navigationTitle(L10n.t(.pomodoroStats, language))
        .navigationBarTitleDisplayMode(.large)
        .onAppear {
            selectedMode = store.timerState.mode
        }
        .onChange(of: store.timerState.mode) { newValue in
            if !store.timerState.isRunning && !store.timerState.isPaused {
                selectedMode = newValue
            }
        }
    }

    private var timerCard: some View {
        JellyCard {
            VStack(alignment: .leading, spacing: 20) {
                Text(L10n.t(.timer, language))
                    .font(ThemeTokens.Typography.sectionTitle)
                    .foregroundStyle(ThemeTokens.Colors.textPrimary)

                if let relatedTitle {
                    Text("\(L10n.t(.linkedTask, language)): \(relatedTitle)")
                        .font(ThemeTokens.Typography.caption)
                        .foregroundStyle(ThemeTokens.Colors.textSecondary)
                        .lineLimit(1)
                }

                modeSelector

                VStack(spacing: 10) {
                    Text(displayMode.title(language: language))
                        .font(ThemeTokens.Typography.body)
                        .foregroundStyle(ThemeTokens.Colors.textSecondary)

                    Text(displayRemainingSeconds.formattedClock())
                        .font(.system(size: 52, weight: .bold, design: .rounded))
                        .foregroundStyle(ThemeTokens.Colors.textPrimary)

                    Text(timerStatusText)
                        .font(ThemeTokens.Typography.caption)
                        .foregroundStyle(ThemeTokens.Colors.textSecondary)
                }
                .frame(maxWidth: .infinity)

                HStack(spacing: 12) {
                    if store.timerState.isRunning {
                        CapsuleButton(title: L10n.t(.pause, language)) {
                            store.pausePomodoro()
                        }

                        CapsuleButton(title: L10n.t(.discard, language)) {
                            store.stopPomodoro(discard: true)
                        }
                    } else if store.timerState.isPaused {
                        CapsuleButton(title: L10n.t(.resume, language)) {
                            store.resumePomodoro()
                        }

                        CapsuleButton(title: L10n.t(.discard, language)) {
                            store.stopPomodoro(discard: true)
                        }
                    } else {
                        CapsuleButton(title: L10n.t(.start, language)) {
                            store.startPomodoro(mode: selectedMode, relatedTodoID: initialRelatedTodoID)
                        }

                        CapsuleButton(title: L10n.t(.reset, language)) {
                            selectedMode = .focus
                        }
                    }
                }
            }
            .padding(24)
        }
    }

    private var statsRangeSelector: some View {
        HStack(spacing: 10) {
            ForEach(PomodoroStatsRange.allCases) { item in
                Button {
                    range = item
                } label: {
                    Text(item.title(language: language))
                        .font(ThemeTokens.Typography.body)
                        .foregroundStyle(range == item ? ThemeTokens.Colors.backgroundPrimary : ThemeTokens.Colors.textPrimary)
                        .padding(.horizontal, 18)
                        .frame(height: 42)
                        .background(range == item ? ThemeTokens.accent(for: store.settings.themeMode) : ThemeTokens.card(for: store.settings.themeMode))
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var modeSelector: some View {
        HStack(spacing: 10) {
            ForEach(PomodoroTimerMode.allCases) { mode in
                Button {
                    selectedMode = mode
                } label: {
                    Text(mode.title(language: language))
                        .font(ThemeTokens.Typography.caption)
                        .foregroundStyle(selectedMode == mode ? ThemeTokens.Colors.backgroundPrimary : ThemeTokens.Colors.textPrimary)
                        .padding(.horizontal, 14)
                        .frame(height: 40)
                        .background(selectedMode == mode ? ThemeTokens.accent(for: store.settings.themeMode) : ThemeTokens.background(for: store.settings.themeMode))
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .disabled(store.timerState.isRunning || store.timerState.isPaused)
                .opacity((store.timerState.isRunning || store.timerState.isPaused) && selectedMode != mode ? 0.6 : 1)
            }
        }
    }

    private var timerStatusText: String {
        if store.timerState.isRunning {
            return L10n.t(.running, language)
        }
        if store.timerState.isPaused {
            return L10n.t(.paused, language)
        }
        switch language {
        case .english:
            return "Ready for \(displayMode.title(language: language))"
        case .chinese:
            return "准备\(displayMode.title(language: language))"
        }
    }

    private var displayMode: PomodoroTimerMode {
        if store.timerState.isRunning || store.timerState.isPaused {
            return store.timerState.mode
        }
        return selectedMode
    }

    private var displayRemainingSeconds: Int {
        if store.timerState.isRunning || store.timerState.isPaused {
            return store.timerState.displaySeconds
        }
        return selectedMode.defaultDuration
    }

    private var relatedTitle: String? {
        guard let initialRelatedTodoID else { return nil }
        return store.todos.first { $0.id == initialRelatedTodoID }?.title
    }

    private func legendRow(title: String, opacity: Double) -> some View {
        HStack(spacing: 12) {
            Circle()
                .fill(ThemeTokens.Colors.textPrimary.opacity(opacity))
                .frame(width: 12, height: 12)

            Text(title)
                .font(ThemeTokens.Typography.caption)
                .foregroundStyle(ThemeTokens.Colors.textSecondary)

            Spacer()
        }
    }
}
