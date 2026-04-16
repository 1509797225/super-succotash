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
