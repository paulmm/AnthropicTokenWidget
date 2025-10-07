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
            ZStack {
                backgroundGradient
                
                VStack(spacing: 0) {
                    Spacer()
                    
                    ZStack {
                        gaugeArc(geometry: geometry)
                        needle(geometry: geometry)
                        centerDisplay(geometry: geometry)
                    }
                    .frame(height: geometry.size.height * 0.7)
                    
                    if size != .systemSmall {
                        statsBar
                            .padding(.horizontal)
                            .padding(.bottom, 8)
                    }
                    
                    Spacer()
                }
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.0)) {
                animatedPercentage = usage.percentageUsed
            }
        }
    }
    
    private var backgroundGradient: some View {
        LinearGradient(
            gradient: Gradient(colors: [
                Color(hex: "#0F172A"),
                Color(hex: "#1E293B")
            ]),
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }
    
    private func gaugeArc(geometry: GeometryProxy) -> some View {
        let width = min(geometry.size.width, geometry.size.height) * 0.8
        let strokeWidth = width * 0.08
        
        return ZStack {
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
                    style: StrokeStyle(
                        lineWidth: strokeWidth,
                        lineCap: .round
                    )
                )
                .frame(width: width, height: width)
                .rotationEffect(.degrees(90))
                .shadow(color: currentColor.opacity(0.5), radius: strokeWidth / 2)
            
            tickMarks(width: width)
        }
    }
    
    private func tickMarks(width: CGFloat) -> some View {
        ZStack {
            ForEach(0..<9) { index in
                Rectangle()
                    .fill(Color.white.opacity(0.3))
                    .frame(width: 2, height: width * 0.05)
                    .offset(y: -width / 2 + width * 0.08)
                    .rotationEffect(.degrees(Double(index) * 30 - 135))
            }
            
            ForEach([0, 25, 50, 75, 100], id: \.self) { percentage in
                VStack {
                    Text("\(percentage)")
                        .font(.system(size: width * 0.04, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.6))
                }
                .offset(y: -width / 2 - width * 0.12)
                .rotationEffect(.degrees(Double(percentage) * 2.7 - 135))
            }
        }
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
                .rotationEffect(.degrees(animatedPercentage * 270 - 135))
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
            Text("\(usage.tokensUsed)")
                .font(.system(size: width * 0.12, weight: .bold, design: .rounded))
                .foregroundColor(.white)
            
            Text("of \(usage.maxTokens)")
                .font(.system(size: width * 0.05, weight: .medium, design: .rounded))
                .foregroundColor(.white.opacity(0.6))
            
            Text("tokens")
                .font(.system(size: width * 0.04, weight: .regular, design: .rounded))
                .foregroundColor(.white.opacity(0.4))
        }
        .offset(y: width * 0.15)
    }
    
    private var statsBar: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Rate")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))
                Text("\(Int(calculateBurnRate())) /min")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundColor(currentColor)
            }
            
            Spacer()
            
            VStack(alignment: .center, spacing: 2) {
                Text("Remaining")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))
                Text("\(usage.tokensRemaining)")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                Text("Reset in")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))
                Text(formatTimeRemaining())
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundColor(.white.opacity(0.8))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.white.opacity(0.05))
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
    
    private func calculateBurnRate() -> Double {
        let elapsedTime = usage.timestamp.timeIntervalSince(usage.windowStart) / 60
        return elapsedTime > 0 ? Double(usage.tokensUsed) / elapsedTime : 0
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

// Widget previews removed - they don't work with SPM executable targets
// To preview widgets, add them to Notification Center after running the app