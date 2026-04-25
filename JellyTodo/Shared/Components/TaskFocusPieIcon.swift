import SwiftUI

struct TaskFocusPieIcon: View {
    let summaries: [TaskFocusSummary]
    let themeMode: AppThemeMode
    @Environment(\.appLanguage) private var language

    private var totalSeconds: Int {
        summaries.reduce(0) { $0 + $1.seconds }
    }

    var body: some View {
        ZStack {
            Ellipse()
                .fill(ThemeTokens.Colors.textPrimary.opacity(0.16))
                .frame(width: 35, height: 13)
                .offset(y: 10)
                .blur(radius: 1.6)

            ZStack {
                Circle()
                    .fill(ThemeTokens.card(for: themeMode))

                if totalSeconds > 0 {
                    ForEach(Array(pieSlices.enumerated()), id: \.offset) { offset, slice in
                        PieSliceShape(startAngle: slice.startAngle, endAngle: slice.endAngle)
                            .fill(sliceStyle(for: offset))
                    }
                } else {
                    Circle()
                        .strokeBorder(ThemeTokens.Colors.textSecondary.opacity(0.42), lineWidth: 5)
                }
            }
            .frame(width: 32, height: 32)
            .scaleEffect(x: 1, y: 0.78, anchor: .center)
            .overlay(alignment: .bottom) {
                Ellipse()
                    .fill(ThemeTokens.Colors.textPrimary.opacity(0.16))
                    .frame(width: 32, height: 10)
                    .offset(y: 6)
            }
            .shadow(color: .white.opacity(0.85), radius: 2, x: -1, y: -1)
            .shadow(color: .black.opacity(0.14), radius: 4, x: 1, y: 3)
        }
        .frame(width: 42, height: 36)
        .accessibilityLabel(totalSeconds > 0 ? L10n.t(.todayFocusChart, language) : L10n.t(.noFocusDataToday, language))
    }

    private var pieSlices: [(startAngle: Angle, endAngle: Angle)] {
        var start = -90.0

        return summaries.map { summary in
            let degrees = Double(summary.seconds) / Double(max(totalSeconds, 1)) * 360
            let slice = (startAngle: Angle(degrees: start), endAngle: Angle(degrees: start + degrees))
            start += degrees
            return slice
        }
    }

    private func sliceStyle(for index: Int) -> AnyShapeStyle {
        let base = ThemeTokens.accent(for: themeMode)
        let palette: [Double] = [1.0, 0.78, 0.58, 0.4, 0.26]
        return AnyShapeStyle(base.opacity(palette[index % palette.count]))
    }
}

private struct PieSliceShape: Shape {
    let startAngle: Angle
    let endAngle: Angle

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2

        path.move(to: center)
        path.addArc(center: center, radius: radius, startAngle: startAngle, endAngle: endAngle, clockwise: false)
        path.closeSubpath()

        return path
    }
}
