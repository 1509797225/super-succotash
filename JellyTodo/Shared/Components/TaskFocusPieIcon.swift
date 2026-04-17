import SwiftUI

struct TaskFocusPieIcon: View {
    let summaries: [TaskFocusSummary]
    let themeMode: AppThemeMode

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
        .accessibilityLabel(totalSeconds > 0 ? "Today focus chart" : "No focus data today")
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
        if themeMode == .rainbow {
            let palette = rainbowPalette
            return AnyShapeStyle(palette[index % palette.count])
        }

        let base = ThemeTokens.accent(for: themeMode)
        let palette: [Double] = [1.0, 0.78, 0.58, 0.4, 0.26]
        return AnyShapeStyle(base.opacity(palette[index % palette.count]))
    }

    private var rainbowPalette: [LinearGradient] {
        [
            LinearGradient(colors: [Color(hex: "#FF5A7A"), Color(hex: "#FFB15E")], startPoint: .topLeading, endPoint: .bottomTrailing),
            LinearGradient(colors: [Color(hex: "#FFE66D"), Color(hex: "#7BD88F")], startPoint: .topLeading, endPoint: .bottomTrailing),
            LinearGradient(colors: [Color(hex: "#5BCBFF"), Color(hex: "#7B61FF")], startPoint: .topLeading, endPoint: .bottomTrailing),
            LinearGradient(colors: [Color(hex: "#B56CFF"), Color(hex: "#FF7AD9")], startPoint: .topLeading, endPoint: .bottomTrailing),
            LinearGradient(colors: [Color(hex: "#4DE3C1"), Color(hex: "#6FA8FF")], startPoint: .topLeading, endPoint: .bottomTrailing)
        ]
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
