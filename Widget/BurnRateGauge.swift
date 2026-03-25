import SwiftUI

/// Real-time burn rate gauge showing tokens consumed per minute
public struct BurnRateGauge: View {
    let burnRate: Double // tokens per minute
    let safeRate: Double // safe consumption rate
    @State private var animatedRate: Double = 0

    public init(burnRate: Double, safeRate: Double = 200) {
        self.burnRate = burnRate
        self.safeRate = safeRate
    }

    public var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                gaugeSection(geometry: geometry)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                statsBar
                    .padding(.horizontal, 12)
                    .padding(.bottom, 12)
            }
            .padding(.top, 8)
        }
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(backgroundGradient)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.15),
                            Color.white.opacity(0.05)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .shadow(color: Color.black.opacity(0.3), radius: 15, x: 0, y: 8)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.0)) {
                animatedRate = min(burnRate, maxDisplayRate)
            }
        }
        .onChange(of: burnRate) { newRate in
            withAnimation(.easeInOut(duration: 0.5)) {
                animatedRate = min(newRate, maxDisplayRate)
            }
        }
    }

    private var maxDisplayRate: Double {
        safeRate * 2.5
    }

    private var percentage: Double {
        guard maxDisplayRate > 0 else { return 0 }
        return animatedRate / maxDisplayRate
    }

    private var backgroundGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(hex: "#1E293B"),
                Color(hex: "#0F172A")
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private func gaugeSection(geometry: GeometryProxy) -> some View {
        let availableHeight = geometry.size.height - 50 // leave room for stats bar
        let gaugeSize = min(geometry.size.width - 24, availableHeight) * 0.85

        return ZStack {
            gaugeArc(gaugeSize: gaugeSize)
            needle(gaugeSize: gaugeSize)
            centerDisplay(gaugeSize: gaugeSize)
        }
        .frame(width: gaugeSize, height: gaugeSize)
    }

    private func gaugeArc(gaugeSize: CGFloat) -> some View {
        let strokeWidth = gaugeSize * 0.07
        let radius = gaugeSize * 0.375

        return ZStack {
            // Background arc
            Circle()
                .trim(from: 0.125, to: 0.875)
                .stroke(
                    Color.white.opacity(0.1),
                    style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round)
                )
                .frame(width: gaugeSize * 0.75, height: gaugeSize * 0.75)
                .rotationEffect(.degrees(90))

            // Colored arc
            Circle()
                .trim(from: 0.125, to: 0.125 + (0.75 * percentage))
                .stroke(
                    AngularGradient(
                        gradient: Gradient(stops: [
                            .init(color: Color(hex: "#10B981"), location: 0.0),
                            .init(color: Color(hex: "#10B981"), location: 0.3),
                            .init(color: Color(hex: "#F59E0B"), location: 0.5),
                            .init(color: Color(hex: "#EF4444"), location: 0.7),
                            .init(color: Color(hex: "#DC2626"), location: 1.0)
                        ]),
                        center: .center,
                        startAngle: .degrees(45),
                        endAngle: .degrees(315)
                    ),
                    style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round)
                )
                .frame(width: gaugeSize * 0.75, height: gaugeSize * 0.75)
                .rotationEffect(.degrees(90))
                .shadow(color: currentColor.opacity(0.5), radius: strokeWidth / 2)

            // Safe rate indicator
            safeRateMark(gaugeSize: gaugeSize, radius: radius)

            tickMarks(gaugeSize: gaugeSize, radius: radius)
        }
    }

    private func safeRateMark(gaugeSize: CGFloat, radius: CGFloat) -> some View {
        let safePercentage = safeRate / maxDisplayRate
        let angle = (safePercentage * 270) - 135

        return Rectangle()
            .fill(Color.green)
            .frame(width: 2.5, height: gaugeSize * 0.08)
            .offset(y: -radius + gaugeSize * 0.04)
            .rotationEffect(.degrees(angle))
    }

    private func tickMarks(gaugeSize: CGFloat, radius: CGFloat) -> some View {
        ZStack {
            // Major tick marks
            ForEach(0..<9) { index in
                Rectangle()
                    .fill(Color.white.opacity(0.3))
                    .frame(width: 1.5, height: gaugeSize * 0.04)
                    .offset(y: -radius + gaugeSize * 0.06)
                    .rotationEffect(.degrees(Double(index) * 30 - 135))
            }

            // Rate labels
            ForEach(rateLabels, id: \.0) { rate, label in
                Text(label)
                    .font(.system(size: gaugeSize * 0.04, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.5))
                    .offset(y: -radius - gaugeSize * 0.06)
                    .rotationEffect(.degrees((rate / maxDisplayRate) * 270 - 135))
            }
        }
    }

    private var rateLabels: [(Double, String)] {
        let max = Int(maxDisplayRate)
        let step = max / 4
        guard step > 0 else { return [(0, "0")] }
        return [
            (0, "0"),
            (Double(step), "\(step)"),
            (Double(step * 2), "\(step * 2)"),
            (Double(step * 3), "\(step * 3)"),
            (Double(max), "\(max)")
        ]
    }

    private func needle(gaugeSize: CGFloat) -> some View {
        let needleLength = gaugeSize * 0.3

        return ZStack {
            Capsule()
                .fill(LinearGradient(
                    colors: [Color.white, Color.white.opacity(0.8)],
                    startPoint: .top,
                    endPoint: .bottom
                ))
                .frame(width: 3, height: needleLength)
                .offset(y: -needleLength / 2)
                .rotationEffect(.degrees(percentage * 270 - 135))
                .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 2)

            Circle()
                .fill(Color.white)
                .frame(width: gaugeSize * 0.05, height: gaugeSize * 0.05)
                .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 2)
        }
    }

    private func centerDisplay(gaugeSize: CGFloat) -> some View {
        VStack(spacing: 2) {
            Text("\(Int(animatedRate))")
                .font(.system(size: gaugeSize * 0.1, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .minimumScaleFactor(0.5)
                .lineLimit(1)

            Text("tokens/min")
                .font(.system(size: gaugeSize * 0.045, weight: .medium, design: .rounded))
                .foregroundColor(.white.opacity(0.6))
                .minimumScaleFactor(0.5)
                .lineLimit(1)

            Text("burn rate")
                .font(.system(size: gaugeSize * 0.035, weight: .regular, design: .rounded))
                .foregroundColor(.white.opacity(0.4))
        }
        .offset(y: gaugeSize * 0.1)
    }

    private var statsBar: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Safe")
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.5))
                Text("\(Int(safeRate))/m")
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .foregroundColor(.green)
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .center, spacing: 2) {
                Text("Status")
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.5))
                Text(statusText)
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .foregroundColor(currentColor)
            }
            .frame(maxWidth: .infinity)

            VStack(alignment: .trailing, spacing: 2) {
                Text("Max")
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.5))
                Text("\(Int(maxDisplayRate))/m")
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .foregroundColor(.white.opacity(0.6))
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.white.opacity(0.03))
        )
    }

    private var statusText: String {
        guard safeRate > 0 else { return "---" }
        let ratio = burnRate / safeRate
        if ratio <= 1.2 {
            return "SAFE"
        } else if ratio <= 2.0 {
            return "HIGH"
        } else {
            return "CRITICAL"
        }
    }

    private var currentColor: Color {
        guard safeRate > 0 else { return Color(hex: "#10B981") }
        let ratio = burnRate / safeRate
        if ratio <= 1.2 {
            return Color(hex: "#10B981")
        } else if ratio <= 2.0 {
            return Color(hex: "#F59E0B")
        } else {
            return Color(hex: "#EF4444")
        }
    }
}
