import SwiftUI

struct PomodoroStatsView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.appLanguage) private var language
    @Environment(\.appTextScale) private var textScale
    let initialRelatedTodoID: UUID?

    @State private var range: PomodoroStatsRange = .today
    @State private var chartMode: PomodoroChartMode = .pie

    init(initialRelatedTodoID: UUID? = nil) {
        self.initialRelatedTodoID = initialRelatedTodoID
    }

    var body: some View {
        let stats = store.stats(for: range)
        let segments = store.focusSegments(for: range)
        let buckets = store.focusTimeBuckets(for: range)

        ScrollView {
            VStack(alignment: .leading, spacing: ThemeTokens.Metrics.sectionSpacing(for: textScale)) {
                Text(L10n.t(.pomodoroStats, language))
                    .font(ThemeTokens.Typography.pageTitle(for: textScale))
                    .foregroundStyle(ThemeTokens.Colors.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.76)

                chartFlipCard(segments: segments, buckets: buckets)

                fixedStatsGrid(stats: stats, planCount: segments.count)

                statsRangeSelector
                    .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, ThemeTokens.Metrics.horizontalPadding(for: textScale))
            .padding(.top, 24)
            .padding(.bottom, 32)
        }
        .background(ThemeTokens.background(for: store.settings.themeMode).ignoresSafeArea())
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func chartFlipCard(segments: [PlanFocusSegment], buckets: [FocusTimeBucket]) -> some View {
        JellyCard {
            ZStack {
                if chartMode == .pie {
                    Pie3DChartView(
                        segments: segments,
                        themeMode: store.settings.themeMode,
                        emptyTitle: L10n.t(.noPomodoroData, language),
                        emptyGuide: L10n.t(.noPomodoroGuide, language)
                    )
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .scale(scale: 0.96)),
                        removal: .opacity.combined(with: .scale(scale: 0.98))
                    ))
                } else {
                    FocusBarChartView(
                        buckets: buckets,
                        range: range,
                        themeMode: store.settings.themeMode,
                        language: language,
                        emptyTitle: L10n.t(.noPomodoroData, language),
                        emptyGuide: L10n.t(.noPomodoroGuide, language)
                    )
                    .rotation3DEffect(.degrees(-180), axis: (x: 0, y: 1, z: 0), perspective: 0.72)
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .scale(scale: 0.96)),
                        removal: .opacity.combined(with: .scale(scale: 0.98))
                    ))
                }
            }
            .padding(24)
            .frame(maxWidth: .infinity)
            .rotation3DEffect(
                .degrees(chartMode == .pie ? 0 : -180),
                axis: (x: 0, y: 1, z: 0),
                perspective: 0.72
            )
            .scaleEffect(chartMode == .pie ? 1 : 0.985)
            .animation(.spring(response: 0.48, dampingFraction: 0.78), value: chartMode)
        }
        .gesture(
            DragGesture(minimumDistance: 24)
                .onEnded { value in
                    guard abs(value.translation.width) > abs(value.translation.height) else { return }
                    if value.translation.width < -48 {
                        chartMode = .bar
                    } else if value.translation.width > 48 {
                        chartMode = .pie
                    }
                }
        )
    }

    private func fixedStatsGrid(stats: PomodoroStats, planCount: Int) -> some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            statTile(title: L10n.t(.focusTime, language), value: stats.focusSeconds.formattedMinutesText())
            statTile(title: L10n.t(.focusPlans, language), value: "\(planCount)")
            statTile(title: L10n.t(.completed, language), value: "\(stats.completedPomodoros)")
            statTile(title: L10n.t(.goalRate, language), value: "\(Int(stats.goalRate * 100))%")
        }
    }

    private func statTile(title: String, value: String) -> some View {
        JellyCard {
            VStack(alignment: .leading, spacing: 8) {
                Text(value)
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundStyle(ThemeTokens.Colors.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)

                Text(title)
                    .font(ThemeTokens.Typography.caption(for: textScale))
                    .foregroundStyle(ThemeTokens.Colors.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: 84)
            .padding(.horizontal, 18)
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
                        .font(ThemeTokens.Typography.body(for: textScale))
                        .foregroundStyle(range == item ? ThemeTokens.Colors.backgroundPrimary : ThemeTokens.Colors.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.76)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(range == item ? ThemeTokens.accent(for: store.settings.themeMode) : ThemeTokens.card(for: store.settings.themeMode))
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
    }

}

private enum PomodoroChartMode {
    case pie
    case bar
}
