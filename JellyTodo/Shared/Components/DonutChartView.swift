import SwiftUI

private struct DonutSegmentShape: Shape {
    let startAngle: Angle
    let endAngle: Angle

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2
        path.addArc(
            center: center,
            radius: radius,
            startAngle: startAngle,
            endAngle: endAngle,
            clockwise: false
        )
        return path
    }
}

struct DonutChartView: View {
    let segments: [DonutChartSegment]
    let centerTitle: String
    let centerSubtitle: String

    private let lineWidth: CGFloat = 28

    var body: some View {
        ZStack {
            Circle()
                .stroke(ThemeTokens.Colors.subtleLine, lineWidth: lineWidth)

            if segments.isEmpty {
                Circle()
                    .trim(from: 0, to: 1)
                    .stroke(ThemeTokens.Colors.textSecondary.opacity(0.2), style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
            } else {
                chartSegments
            }

            VStack(spacing: 6) {
                Text(centerTitle)
                    .font(ThemeTokens.Typography.largeStat)
                    .foregroundStyle(ThemeTokens.Colors.textPrimary)
                Text(centerSubtitle)
                    .font(ThemeTokens.Typography.caption)
                    .foregroundStyle(ThemeTokens.Colors.textSecondary)
            }
        }
        .frame(width: 220, height: 220)
    }

    @ViewBuilder
    private var chartSegments: some View {
        let total = segments.reduce(0) { $0 + $1.value }

        ForEach(Array(segments.enumerated()), id: \.offset) { index, segment in
            let start = segments.prefix(index).reduce(0) { $0 + $1.value } / total
            let end = (segments.prefix(index).reduce(0) { $0 + $1.value } + segment.value) / total

            DonutSegmentShape(
                startAngle: .degrees(start * 360 - 90),
                endAngle: .degrees(end * 360 - 90)
            )
            .stroke(
                ThemeTokens.Colors.textPrimary.opacity(segment.opacity),
                style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
            )
        }
    }
}

private struct Pie3DSliceShape: Shape {
    let startAngle: Angle
    let endAngle: Angle

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2

        path.move(to: center)
        path.addArc(
            center: center,
            radius: radius,
            startAngle: startAngle,
            endAngle: endAngle,
            clockwise: false
        )
        path.closeSubpath()
        return path
    }
}

struct Pie3DChartView: View {
    let segments: [PlanFocusSegment]
    let themeMode: AppThemeMode
    let emptyTitle: String
    let emptyGuide: String

    @State private var showsAllSegments = false

    private var displaySegments: [PlanFocusSegment] {
        let sortedSegments = segments.sorted { $0.seconds > $1.seconds }
        guard !showsAllSegments else { return sortedSegments }
        guard sortedSegments.count > 5 else { return sortedSegments }

        let topSegments = Array(sortedSegments.prefix(5))
        let otherSegments = sortedSegments.dropFirst(5)
        let otherSeconds = otherSegments.reduce(0) { $0 + $1.seconds }
        let otherItemCount = otherSegments.reduce(0) { $0 + $1.itemCount }
        return topSegments + [
            PlanFocusSegment(
                id: UUID(uuidString: "00000000-0000-0000-0000-000000000999") ?? UUID(),
                title: "Other",
                seconds: otherSeconds,
                itemCount: otherItemCount
            )
        ]
    }

    private var totalSeconds: Int {
        segments.reduce(0) { $0 + $1.seconds }
    }

    var body: some View {
        VStack(spacing: 22) {
            ZStack {
                Ellipse()
                    .fill(.black.opacity(0.14))
                    .frame(width: 258, height: 42)
                    .offset(y: 88)
                    .blur(radius: 9)

                ZStack {
                    ForEach(Array((1...8).reversed()), id: \.self) { layer in
                        pieLayer(depth: layer)
                            .frame(width: 248, height: 248)
                            .scaleEffect(x: 1, y: 0.62, anchor: .center)
                            .offset(y: CGFloat(layer) * 4.5)
                            .brightness(-0.08 - Double(layer) * 0.018)
                    }

                    pieLayer(depth: 0)
                        .frame(width: 248, height: 248)
                        .scaleEffect(x: 1, y: 0.62, anchor: .center)
                        .overlay(
                            Circle()
                                .stroke(.white.opacity(0.72), lineWidth: 1.4)
                                .frame(width: 248, height: 248)
                                .scaleEffect(x: 1, y: 0.62, anchor: .center)
                        )
                        .shadow(color: .white.opacity(0.55), radius: 3, x: -2, y: -2)
                        .shadow(color: .black.opacity(0.16), radius: 10, x: 4, y: 8)
                }
                .frame(width: 282, height: 196)

                if segments.isEmpty {
                    VStack(spacing: 8) {
                        Text(emptyTitle)
                            .font(ThemeTokens.Typography.body)
                            .foregroundStyle(ThemeTokens.Colors.textPrimary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.78)

                        Text(emptyGuide)
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundStyle(ThemeTokens.Colors.textSecondary)
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                            .minimumScaleFactor(0.82)
                    }
                    .padding(.horizontal, 26)
                    .offset(y: 4)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 260)

            if !segments.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    if segments.count > 5 {
                        Button {
                            withAnimation(.spring(response: 0.32, dampingFraction: 0.84)) {
                                showsAllSegments.toggle()
                            }
                        } label: {
                            HStack(spacing: 8) {
                                Text(showsAllSegments ? "All Plans" : "Top 5")
                                    .font(ThemeTokens.Typography.caption)
                                    .foregroundStyle(ThemeTokens.Colors.textPrimary)

                                Image(systemName: showsAllSegments ? "chevron.up" : "chevron.down")
                                    .font(.system(size: 12, weight: .black))
                                    .foregroundStyle(ThemeTokens.Colors.textSecondary)
                            }
                            .padding(.horizontal, 14)
                            .frame(height: 36)
                            .background(ThemeTokens.card(for: themeMode))
                            .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }

                    ForEach(Array(displaySegments.enumerated()), id: \.element.id) { index, segment in
                        pieLegendRow(segment: segment, index: index)
                    }
                }
            }
        }
    }

    private func pieLegendRow(segment: PlanFocusSegment, index: Int) -> some View {
        let percentage = percentage(for: segment)

        return VStack(spacing: 7) {
            HStack(spacing: 10) {
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(color(for: index))
                    .frame(width: 22, height: 12)

                Text(segment.title)
                    .font(ThemeTokens.Typography.caption)
                    .foregroundStyle(ThemeTokens.Colors.textPrimary)
                    .lineLimit(1)

                Spacer()

                Text("\(percentageText(percentage)) · \(segment.seconds.formattedMinutesText())")
                    .font(ThemeTokens.Typography.caption)
                    .foregroundStyle(ThemeTokens.Colors.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.76)
            }
        }
    }

    @ViewBuilder
    private func pieLayer(depth: Int) -> some View {
        if segments.isEmpty {
            Circle()
                .fill(ThemeTokens.card(for: themeMode))
                .overlay(
                    Circle()
                        .stroke(ThemeTokens.Colors.textSecondary.opacity(0.24), lineWidth: 1)
                )
        } else {
            ZStack {
                ForEach(Array(displaySegments.enumerated()), id: \.element.id) { index, segment in
                    let angles = angleRange(for: index)
                    Pie3DSliceShape(startAngle: angles.start, endAngle: angles.end)
                        .fill(color(for: index))
                        .overlay(
                            Pie3DSliceShape(startAngle: angles.start, endAngle: angles.end)
                                .stroke(.white.opacity(depth == 0 ? 0.72 : 0.18), lineWidth: depth == 0 ? 1.2 : 0.6)
                        )
                        .offset(x: offset(for: index, depth: depth).width, y: offset(for: index, depth: depth).height)
                }
            }
        }
    }

    private func angleRange(for index: Int) -> (start: Angle, end: Angle) {
        let total = max(Double(totalSeconds), 1)
        let startValue = Double(displaySegments.prefix(index).reduce(0) { $0 + $1.seconds }) / total
        let endValue = Double(displaySegments.prefix(index + 1).reduce(0) { $0 + $1.seconds }) / total
        return (.degrees(startValue * 360 - 90), .degrees(endValue * 360 - 90))
    }

    private func offset(for index: Int, depth: Int) -> CGSize {
        let angle = middleAngle(for: index) * .pi / 180
        let baseDistance = CGFloat(index % 2 == 0 ? 4 : 7)
        let distance = depth == 0 ? baseDistance : baseDistance * 0.58
        return CGSize(width: cos(angle) * distance, height: sin(angle) * distance)
    }

    private func middleAngle(for index: Int) -> Double {
        let total = max(Double(totalSeconds), 1)
        let startValue = Double(displaySegments.prefix(index).reduce(0) { $0 + $1.seconds }) / total
        let endValue = Double(displaySegments.prefix(index + 1).reduce(0) { $0 + $1.seconds }) / total
        return ((startValue + endValue) / 2) * 360 - 90
    }

    private func percentage(for segment: PlanFocusSegment) -> CGFloat {
        guard totalSeconds > 0 else { return 0 }
        return CGFloat(segment.seconds) / CGFloat(totalSeconds)
    }

    private func percentageText(_ value: CGFloat) -> String {
        "\(Int((value * 100).rounded()))%"
    }

    private func color(for index: Int) -> Color {
        ChartPalette.colors(for: themeMode)[index % ChartPalette.colors(for: themeMode).count]
    }
}

struct FocusBarChartView: View {
    let buckets: [FocusTimeBucket]
    let range: PomodoroStatsRange
    let themeMode: AppThemeMode
    let language: AppLanguage
    let emptyTitle: String
    let emptyGuide: String

    private var totalSeconds: Int {
        buckets.reduce(0) { $0 + $1.seconds }
    }

    private var maxSeconds: Int {
        max(buckets.map(\.seconds).max() ?? 1, 1)
    }

    private var yAxisValues: [Int] {
        let maxValue = niceAxisMax(maxSeconds)
        return [maxValue, maxValue * 3 / 4, maxValue / 2, maxValue / 4, 0]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            if buckets.isEmpty || totalSeconds == 0 {
                VStack(spacing: 8) {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(ThemeTokens.card(for: themeMode))
                        .overlay(
                            RoundedRectangle(cornerRadius: 22, style: .continuous)
                                .stroke(ThemeTokens.Colors.textSecondary.opacity(0.18), lineWidth: 1)
                        )
                        .frame(height: 180)
                        .overlay {
                            VStack(spacing: 8) {
                                Text(emptyTitle)
                                    .font(ThemeTokens.Typography.body)
                                    .foregroundStyle(ThemeTokens.Colors.textPrimary)

                                Text(emptyGuide)
                                    .font(.system(size: 14, weight: .bold, design: .rounded))
                                    .foregroundStyle(ThemeTokens.Colors.textSecondary)
                                    .multilineTextAlignment(.center)
                            }
                            .padding(.horizontal, 20)
                        }
                }
            } else {
                VStack(spacing: 14) {
                    HStack(alignment: .bottom, spacing: 8) {
                        VStack(alignment: .trailing, spacing: 0) {
                            ForEach(yAxisValues, id: \.self) { value in
                                Text(axisLabel(seconds: value))
                                    .font(.system(size: 12, weight: .bold, design: .rounded))
                                    .foregroundStyle(ThemeTokens.Colors.textSecondary.opacity(0.78))
                                    .frame(height: 58, alignment: value == 0 ? .bottom : .top)
                            }
                        }
                        .frame(width: 50, height: 290)

                        ScrollView(.horizontal, showsIndicators: false) {
                            ZStack(alignment: .bottomLeading) {
                                RoundedRectangle(cornerRadius: 28, style: .continuous)
                                    .fill(ThemeTokens.background(for: themeMode).opacity(0.54))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 28, style: .continuous)
                                            .stroke(.white.opacity(0.54), lineWidth: 1)
                                    )

                                VStack(spacing: 57) {
                                    ForEach(yAxisValues, id: \.self) { value in
                                        Rectangle()
                                            .fill(ThemeTokens.Colors.textSecondary.opacity(value == 0 ? 0.2 : 0.11))
                                            .frame(height: 1)
                                    }
                                }
                                .padding(.horizontal, 14)
                                .padding(.bottom, 44)

                                HStack(alignment: .bottom, spacing: barSpacing) {
                                    ForEach(Array(buckets.enumerated()), id: \.element.id) { index, bucket in
                                        bucketColumn(bucket: bucket, index: index)
                                    }
                                }
                                .padding(.horizontal, 16)
                                .padding(.bottom, 12)
                            }
                            .frame(width: chartContentWidth, height: 290, alignment: .bottomLeading)
                        }
                        .frame(height: 290)
                    }
                }
                .padding(.top, 8)
            }
        }
        .frame(height: 374)
    }

    private func bucketColumn(bucket: FocusTimeBucket, index: Int) -> some View {
        let ratio = CGFloat(bucket.seconds) / CGFloat(maxSeconds)
        let height = bucket.seconds == 0 ? 4 : max(10, ratio * 150)
        let color = ChartPalette.colors(for: themeMode)[index % ChartPalette.colors(for: themeMode).count]

        return VStack(spacing: 6) {
            ZStack(alignment: .top) {
                RoundedRectangle(cornerRadius: barCornerRadius, style: .continuous)
                    .fill(color.opacity(0.32))
                    .frame(height: height)
                    .offset(x: min(4, barWidth / 3), y: 6)
                    .blur(radius: 0.3)

                RoundedRectangle(cornerRadius: barCornerRadius, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                color.opacity(0.98),
                                color.opacity(0.72),
                                ThemeTokens.accentSoft(for: themeMode).opacity(0.9)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(height: height)
                    .overlay(
                        RoundedRectangle(cornerRadius: barCornerRadius, style: .continuous)
                            .stroke(.white.opacity(0.66), lineWidth: 1)
                    )
                    .shadow(color: .white.opacity(0.42), radius: 2, x: -1, y: -1)
                    .shadow(color: .black.opacity(0.13), radius: 8, x: 3, y: 8)
            }
            .frame(width: barWidth, height: 230, alignment: .bottom)

            Text(visibleXAxisLabel(bucket.label, index: index))
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundStyle(ThemeTokens.Colors.textPrimary.opacity(xAxisLabelOpacity(index: index)))
                .lineLimit(1)
                .minimumScaleFactor(0.58)
                .frame(height: 24)
        }
        .frame(width: columnWidth)
    }

    private var columnWidth: CGFloat {
        switch range {
        case .today:
            return 20
        case .week:
            return 38
        case .month:
            return 18
        case .year:
            return 28
        }
    }

    private var barWidth: CGFloat {
        switch range {
        case .today:
            return 13
        case .week:
            return 28
        case .month:
            return 11
        case .year:
            return 20
        }
    }

    private var barSpacing: CGFloat {
        switch range {
        case .today:
            return 6
        case .week:
            return 12
        case .month:
            return 5
        case .year:
            return 8
        }
    }

    private var chartContentWidth: CGFloat {
        let count = CGFloat(max(buckets.count, 1))
        let totalColumnWidth = count * columnWidth
        let totalSpacing = CGFloat(max(buckets.count - 1, 0)) * barSpacing
        return max(300, totalColumnWidth + totalSpacing + 32)
    }

    private var barCornerRadius: CGFloat {
        max(2, barWidth / 2)
    }

    private func visibleXAxisLabel(_ label: String, index: Int) -> String {
        switch range {
        case .today:
            return index % 3 == 0 ? label : ""
        case .week:
            return label
        case .month:
            return index == 0 || (index + 1) % 5 == 0 ? label : ""
        case .year:
            return label
        }
    }

    private func xAxisLabelOpacity(index: Int) -> Double {
        visibleXAxisLabel(buckets[index].label, index: index).isEmpty ? 0 : 1
    }

    private func axisLabel(seconds: Int) -> String {
        seconds.formattedMinutesText()
    }

    private func niceAxisMax(_ seconds: Int) -> Int {
        guard seconds > 0 else { return 60 }
        let minutes = max(Int(ceil(Double(seconds) / 60)), 1)
        let step: Int
        if minutes <= 30 {
            step = 10
        } else if minutes <= 120 {
            step = 30
        } else if minutes <= 360 {
            step = 60
        } else {
            step = 120
        }
        return Int(ceil(Double(minutes) / Double(step))) * step * 60
    }
}

private enum ChartPalette {
    static func colors(for themeMode: AppThemeMode) -> [Color] {
        switch themeMode.color {
        case .blackWhite:
            return [
                Color(hex: "#333333"),
                Color(hex: "#55565A"),
                Color(hex: "#74767B"),
                Color(hex: "#979AA1"),
                Color(hex: "#C1C3C9"),
                Color(hex: "#E1E2E6")
            ]
        case .pink:
            return [
                Color(hex: "#F06F95"),
                Color(hex: "#F58BA8"),
                Color(hex: "#FFABC0"),
                Color(hex: "#FFC5D3"),
                Color(hex: "#FFDDE7"),
                Color(hex: "#8B5969")
            ]
        case .blue:
            return [
                Color(hex: "#4D93DD"),
                Color(hex: "#78AEEA"),
                Color(hex: "#9DC8F3"),
                Color(hex: "#C0DDF8"),
                Color(hex: "#DCEEFF"),
                Color(hex: "#526D8A")
            ]
        case .green:
            return [
                Color(hex: "#4EB96B"),
                Color(hex: "#7BCB91"),
                Color(hex: "#A5DDB3"),
                Color(hex: "#C5ECCE"),
                Color(hex: "#DDF5E4"),
                Color(hex: "#52705A")
            ]
        }
    }
}
