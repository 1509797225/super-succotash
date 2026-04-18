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
                VStack(spacing: 10) {
                    ForEach(Array(segments.prefix(4).enumerated()), id: \.element.id) { index, segment in
                        HStack(spacing: 10) {
                            RoundedRectangle(cornerRadius: 5, style: .continuous)
                                .fill(color(for: index))
                                .frame(width: 22, height: 12)

                            Text(segment.title)
                                .font(ThemeTokens.Typography.caption)
                                .foregroundStyle(ThemeTokens.Colors.textPrimary)
                                .lineLimit(1)

                            Spacer()

                            Text(segment.seconds.formattedMinutesText())
                                .font(ThemeTokens.Typography.caption)
                                .foregroundStyle(ThemeTokens.Colors.textSecondary)
                                .lineLimit(1)
                        }
                    }
                }
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
                ForEach(Array(segments.enumerated()), id: \.element.id) { index, segment in
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
        let startValue = Double(segments.prefix(index).reduce(0) { $0 + $1.seconds }) / total
        let endValue = Double(segments.prefix(index + 1).reduce(0) { $0 + $1.seconds }) / total
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
        let startValue = Double(segments.prefix(index).reduce(0) { $0 + $1.seconds }) / total
        let endValue = Double(segments.prefix(index + 1).reduce(0) { $0 + $1.seconds }) / total
        return ((startValue + endValue) / 2) * 360 - 90
    }

    private func color(for index: Int) -> Color {
        ChartPalette.colors(for: themeMode)[index % ChartPalette.colors(for: themeMode).count]
    }
}

struct FocusBarChartView: View {
    let segments: [PlanFocusSegment]
    let themeMode: AppThemeMode
    let emptyTitle: String
    let emptyGuide: String

    private var maxSeconds: Int {
        max(segments.map(\.seconds).max() ?? 1, 1)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                VStack(alignment: .leading, spacing: 5) {
                    Text("Focus Bars")
                        .font(ThemeTokens.Typography.sectionTitle)
                        .foregroundStyle(ThemeTokens.Colors.textPrimary)

                    Text("Swipe right to return")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(ThemeTokens.Colors.textSecondary)
                }

                Spacer()

                Image(systemName: "chart.bar.xaxis")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(ThemeTokens.accent(for: themeMode))
                    .frame(width: 48, height: 48)
                    .background(ThemeTokens.background(for: themeMode).opacity(0.78))
                    .clipShape(Circle())
            }

            if segments.isEmpty {
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
                HStack(alignment: .bottom, spacing: 12) {
                    ForEach(Array(segments.prefix(6).enumerated()), id: \.element.id) { index, segment in
                        barColumn(segment: segment, index: index)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 220, alignment: .bottom)
                .padding(.top, 8)
                .overlay(alignment: .bottom) {
                    Rectangle()
                        .fill(ThemeTokens.Colors.textSecondary.opacity(0.18))
                        .frame(height: 1)
                        .offset(y: 2)
                }
            }
        }
        .frame(height: 318)
    }

    private func barColumn(segment: PlanFocusSegment, index: Int) -> some View {
        let ratio = CGFloat(segment.seconds) / CGFloat(maxSeconds)
        let height = max(42, ratio * 168)
        let color = ChartPalette.colors(for: themeMode)[index % ChartPalette.colors(for: themeMode).count]

        return VStack(spacing: 8) {
            Text(segment.seconds.formattedMinutesText())
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(ThemeTokens.Colors.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.68)

            ZStack(alignment: .top) {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(color.opacity(0.32))
                    .frame(height: height)
                    .offset(x: 5, y: 7)
                    .blur(radius: 0.3)

                RoundedRectangle(cornerRadius: 18, style: .continuous)
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
                    .overlay(alignment: .topLeading) {
                        Capsule()
                            .fill(.white.opacity(0.55))
                            .frame(width: 12, height: max(24, height * 0.48))
                            .padding(.top, 10)
                            .padding(.leading, 9)
                    }
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(.white.opacity(0.66), lineWidth: 1)
                    )
                    .shadow(color: .white.opacity(0.42), radius: 2, x: -1, y: -1)
                    .shadow(color: .black.opacity(0.13), radius: 8, x: 3, y: 8)
            }
            .frame(maxHeight: 178, alignment: .bottom)

            Text(shortLabel(segment.title))
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(ThemeTokens.Colors.textPrimary)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.72)
                .frame(height: 32)
        }
        .frame(maxWidth: .infinity)
    }

    private func shortLabel(_ title: String) -> String {
        if title.count <= 5 { return title }
        return String(title.prefix(5))
    }
}

private enum ChartPalette {
    static func colors(for themeMode: AppThemeMode) -> [Color] {
        switch themeMode {
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
        case .rainbow:
            return [
                Color(hex: "#FF7A4F"),
                Color(hex: "#FF9E68"),
                Color(hex: "#FFC36D"),
                Color(hex: "#FFDD9B"),
                Color(hex: "#FFE8C7"),
                Color(hex: "#80614D")
            ]
        }
    }
}
