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
            VStack(spacing: 12) {
                Spacer()

                ZStack {
                    gaugeArc(geometry: geometry)
                    needle(geometry: geometry)
                    centerDisplay(geometry: geometry)
                }
                .frame(height: geometry.size.height * 0.7)

                statsBar
                    .padding(.horizontal, 8)

                Spacer()
            }
        }
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
        safeRate * 2.5 // Show up to 2.5x the safe rate
    }

    private var percentage: Double {
        animatedRate / maxDisplayRate
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


    private func gaugeArc(geometry: GeometryProxy) -> some View {
        let width = min(geometry.size.width, geometry.size.height) * 0.8
        let strokeWidth = width * 0.08

        return ZStack {
            // Background arc
            Circle()
                .trim(from: 0.125, to: 0.875)
                .stroke(
                    Color.white.opacity(0.1),
                    style: StrokeStyle(
                        lineWidth: strokeWidth,
                        lineCap: .round
                    )
                )
                .frame(width: width, height: width)
                .rotationEffect(.degrees(90))

            // Colored arc showing burn rate
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
                    style: StrokeStyle(
                        lineWidth: strokeWidth,
                        lineCap: .round
                    )
                )
                .frame(width: width, height: width)
                .rotationEffect(.degrees(90))
                .shadow(color: currentColor.opacity(0.5), radius: strokeWidth / 2)

            // Safe rate indicator
            safeRateMark(width: width)

            tickMarks(width: width)
        }
    }

    private func safeRateMark(width: CGFloat) -> some View {
        let safePercentage = safeRate / maxDisplayRate
        let angle = (safePercentage * 270) - 135

        return Rectangle()
            .fill(Color.green)
            .frame(width: 3, height: width * 0.1)
            .offset(y: -width / 2 + width * 0.05)
            .rotationEffect(.degrees(angle))
    }

    private func tickMarks(width: CGFloat) -> some View {
        ZStack {
            // Major tick marks
            ForEach(0..<9) { index in
                Rectangle()
                    .fill(Color.white.opacity(0.3))
                    .frame(width: 2, height: width * 0.05)
                    .offset(y: -width / 2 + width * 0.08)
                    .rotationEffect(.degrees(Double(index) * 30 - 135))
            }

            // Rate labels
            ForEach(rateLabels, id: \.0) { rate, label in
                VStack {
                    Text(label)
                        .font(.system(size: width * 0.04, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.6))
                }
                .offset(y: -width / 2 - width * 0.12)
                .rotationEffect(.degrees((rate / maxDisplayRate) * 270 - 135))
            }
        }
    }

    private var rateLabels: [(Double, String)] {
        let max = Int(maxDisplayRate)
        let step = max / 4
        return [
            (0, "0"),
            (Double(step), "\(step)"),
            (Double(step * 2), "\(step * 2)"),
            (Double(step * 3), "\(step * 3)"),
            (Double(max), "\(max)")
        ]
    }

    private func needle(geometry: GeometryProxy) -> some View {
        let width = min(geometry.size.width, geometry.size.height) * 0.8
        let needleLength = width * 0.35

        return ZStack {
            Capsule()
                .fill(LinearGradient(
                    colors: [Color.white, Color.white.opacity(0.8)],
                    startPoint: .top,
                    endPoint: .bottom
                ))
                .frame(width: 4, height: needleLength)
                .offset(y: -needleLength / 2)
                .rotationEffect(.degrees(percentage * 270 - 135))
                .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 2)

            Circle()
                .fill(Color.white)
                .frame(width: width * 0.06, height: width * 0.06)
                .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 2)
        }
    }

    private func centerDisplay(geometry: GeometryProxy) -> some View {
        let width = min(geometry.size.width, geometry.size.height) * 0.8

        return VStack(spacing: 4) {
            Text("\(Int(animatedRate))")
                .font(.system(size: width * 0.12, weight: .bold, design: .rounded))
                .foregroundColor(.white)

            Text("tokens/min")
                .font(.system(size: width * 0.05, weight: .medium, design: .rounded))
                .foregroundColor(.white.opacity(0.6))

            Text("burn rate")
                .font(.system(size: width * 0.04, weight: .regular, design: .rounded))
                .foregroundColor(.white.opacity(0.4))

            Text("(30s window)")
                .font(.system(size: width * 0.035, weight: .regular, design: .rounded))
                .foregroundColor(.white.opacity(0.3))
        }
        .offset(y: width * 0.15)
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
