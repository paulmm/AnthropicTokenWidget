import SwiftUI
import WidgetKit

public struct TachometerView: View {
    let usage: TokenUsage
    let size: WidgetFamily
    @State private var animatedPercentage: Double = 0

    public init(usage: TokenUsage, size: WidgetFamily = .systemMedium) {
        self.usage = usage
        self.size = size
    }

    public var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                gaugeSection(geometry: geometry)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                if size != .systemSmall {
                    statsBar
                        .padding(.horizontal, 12)
                        .padding(.bottom, 12)
                }
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
                animatedPercentage = usage.percentageUsed
            }
        }
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
        let availableHeight = size != .systemSmall
            ? geometry.size.height - 50 // leave room for stats bar
            : geometry.size.height - 16
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
                .trim(from: 0.125, to: 0.125 + (0.75 * animatedPercentage))
                .stroke(
                    AngularGradient(
                        gradient: Gradient(stops: [
                            .init(color: Color(hex: "#10B981"), location: 0.0),
                            .init(color: Color(hex: "#10B981"), location: 0.4),
                            .init(color: Color(hex: "#F59E0B"), location: 0.6),
                            .init(color: Color(hex: "#EF4444"), location: 0.85),
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

            tickMarks(gaugeSize: gaugeSize)
        }
    }

    private func tickMarks(gaugeSize: CGFloat) -> some View {
        let radius = gaugeSize * 0.375 // half of 0.75

        return ZStack {
            // Major tick marks (inside the arc)
            ForEach(0..<9) { index in
                Rectangle()
                    .fill(Color.white.opacity(0.3))
                    .frame(width: 1.5, height: gaugeSize * 0.04)
                    .offset(y: -radius + gaugeSize * 0.06)
                    .rotationEffect(.degrees(Double(index) * 30 - 135))
            }

            // Labels (outside the arc, within bounding box)
            ForEach([0, 25, 50, 75, 100], id: \.self) { percentage in
                Text("\(percentage)")
                    .font(.system(size: gaugeSize * 0.04, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.5))
                    .offset(y: -radius - gaugeSize * 0.06)
                    .rotationEffect(.degrees(Double(percentage) * 2.7 - 135))
            }
        }
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
                .rotationEffect(.degrees(animatedPercentage * 270 - 135))
                .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 2)

            Circle()
                .fill(Color.white)
                .frame(width: gaugeSize * 0.05, height: gaugeSize * 0.05)
                .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 2)
        }
    }

    private func centerDisplay(gaugeSize: CGFloat) -> some View {
        VStack(spacing: 2) {
            Text("\(usage.tokensUsed)")
                .font(.system(size: gaugeSize * 0.1, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .minimumScaleFactor(0.5)
                .lineLimit(1)

            Text("of \(usage.maxTokens)")
                .font(.system(size: gaugeSize * 0.045, weight: .medium, design: .rounded))
                .foregroundColor(.white.opacity(0.6))
                .minimumScaleFactor(0.5)
                .lineLimit(1)

            Text("tokens")
                .font(.system(size: gaugeSize * 0.035, weight: .regular, design: .rounded))
                .foregroundColor(.white.opacity(0.4))
        }
        .offset(y: gaugeSize * 0.1)
    }

    private var statsBar: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Used")
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.5))
                Text("\(usage.tokensUsed)")
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .foregroundColor(currentColor)
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .center, spacing: 2) {
                Text("Left")
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.5))
                Text("\(usage.tokensRemaining)")
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)

            VStack(alignment: .trailing, spacing: 2) {
                Text("Reset")
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.5))
                Text(formatTimeRemaining())
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

    private var currentColor: Color {
        switch usage.percentageUsed {
        case 0..<0.60:
            return Color(hex: "#10B981")
        case 0.60..<0.85:
            return Color(hex: "#F59E0B")
        default:
            return Color(hex: "#EF4444")
        }
    }

    private func formatTimeRemaining() -> String {
        let timeRemaining = usage.timeUntilReset
        let hours = Int(timeRemaining) / 3600
        let minutes = Int(timeRemaining) % 3600 / 60

        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
