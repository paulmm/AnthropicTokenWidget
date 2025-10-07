import SwiftUI
import Charts

public enum GraphTimeRange: String, CaseIterable {
    case hour = "1H"
    case fiveHours = "5H"
    case day = "24H"
    case week = "7D"
    
    var hours: Int {
        switch self {
        case .hour: return 1
        case .fiveHours: return 5
        case .day: return 24
        case .week: return 168
        }
    }
    
    var displayName: String {
        switch self {
        case .hour: return "Last Hour"
        case .fiveHours: return "5 Hours"
        case .day: return "24 Hours"
        case .week: return "7 Days"
        }
    }
}

public struct UsageGraphView: View {
    let history: TokenUsageHistory
    @State private var selectedRange: GraphTimeRange = .fiveHours
    @State private var selectedEntry: TokenUsage?
    @State private var showingModelBreakdown = false
    
    public init(history: TokenUsageHistory) {
        self.history = history
    }
    
    public var body: some View {
        VStack(spacing: 16) {
            header

            chart
                .frame(height: 200)
                .padding(.horizontal)

            if showingModelBreakdown {
                if #available(macOS 14.0, *) {
                    modelBreakdownChart
                        .frame(height: 150)
                        .padding(.horizontal)
                } else {
                    Text("Model breakdown requires macOS 14.0 or later")
                        .foregroundColor(.white.opacity(0.6))
                        .padding()
                }
            }

            statistics
        }
        .background(Color(hex: "#0F172A"))
    }
    
    private var header: some View {
        HStack {
            Text("Usage History")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.white)
            
            Spacer()
            
            Picker("Time Range", selection: $selectedRange) {
                ForEach(GraphTimeRange.allCases, id: \.self) { range in
                    Text(range.rawValue)
                        .tag(range)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
            .frame(width: 200)
            
            Button(action: { showingModelBreakdown.toggle() }) {
                Image(systemName: showingModelBreakdown ? "chart.pie.fill" : "chart.pie")
                    .foregroundColor(.white.opacity(0.8))
            }
        }
        .padding(.horizontal)
    }
    
    private var chart: some View {
        let filteredEntries = filterEntries(for: selectedRange)
        
        return Chart(filteredEntries) { entry in
            LineMark(
                x: .value("Time", entry.timestamp),
                y: .value("Tokens", entry.tokensUsed)
            )
            .foregroundStyle(
                LinearGradient(
                    colors: [Color(hex: "#3B82F6"), Color(hex: "#10B981")],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .interpolationMethod(.catmullRom)
            .lineStyle(StrokeStyle(lineWidth: 2))
            
            AreaMark(
                x: .value("Time", entry.timestamp),
                y: .value("Tokens", entry.tokensUsed)
            )
            .foregroundStyle(
                LinearGradient(
                    colors: [
                        Color(hex: "#3B82F6").opacity(0.3),
                        Color(hex: "#10B981").opacity(0.1)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .interpolationMethod(.catmullRom)
            
            if entry.isNearLimit {
                RuleMark(
                    y: .value("Limit", entry.maxTokens)
                )
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 5]))
                .foregroundStyle(Color(hex: "#EF4444").opacity(0.5))
            }
        }
        .chartXAxis {
            AxisMarks(preset: .automatic) { _ in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                    .foregroundStyle(Color.white.opacity(0.1))
                AxisValueLabel()
                    .foregroundStyle(Color.white.opacity(0.6))
            }
        }
        .chartYAxis {
            AxisMarks(preset: .automatic) { _ in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                    .foregroundStyle(Color.white.opacity(0.1))
                AxisValueLabel()
                    .foregroundStyle(Color.white.opacity(0.6))
            }
        }
        .chartBackground { chartProxy in
            Color.clear
        }
        .chartPlotStyle { plotArea in
            plotArea
                .background(Color.white.opacity(0.02))
                .cornerRadius(8)
        }
    }
    
    @available(macOS 14.0, *)
    private var modelBreakdownChart: some View {
        let breakdown = history.usageByModel()
        let total = breakdown.values.reduce(0, +)

        return VStack(alignment: .leading, spacing: 8) {
            Text("Model Breakdown")
                .font(.headline)
                .foregroundColor(.white.opacity(0.8))
                .padding(.horizontal)

            Chart(Array(breakdown), id: \.key) { model, tokens in
                SectorMark(
                    angle: .value("Tokens", tokens),
                    innerRadius: .ratio(0.6),
                    angularInset: 2
                )
                .foregroundStyle(Color(hex: model.color))
                .opacity(0.8)
            }
            .frame(height: 120)
            .chartBackground { _ in
                VStack {
                    Text("\(total)")
                        .font(.title2.bold())
                        .foregroundColor(.white)
                    Text("Total")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.6))
                }
            }

            HStack(spacing: 16) {
                ForEach(Array(breakdown.sorted(by: { $0.value > $1.value })), id: \.key) { model, tokens in
                    HStack(spacing: 4) {
                        Circle()
                            .fill(Color(hex: model.color))
                            .frame(width: 8, height: 8)
                        Text(model.displayName)
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.8))
                        Text("\(tokens)")
                            .font(.caption.bold())
                            .foregroundColor(.white.opacity(0.6))
                    }
                }
            }
            .padding(.horizontal)
        }
    }
    
    private var statistics: some View {
        HStack(spacing: 20) {
            StatBox(
                title: "Total Used",
                value: "\(history.totalTokensUsed)",
                color: Color(hex: "#3B82F6")
            )
            
            StatBox(
                title: "Avg/Hour",
                value: String(format: "%.0f", history.averageUsagePerHour),
                color: Color(hex: "#10B981")
            )
            
            StatBox(
                title: "Peak Usage",
                value: "\(history.entries.map { $0.tokensUsed }.max() ?? 0)",
                color: Color(hex: "#F59E0B")
            )
            
            StatBox(
                title: "Windows Hit",
                value: "\(history.entries.filter { $0.isNearLimit }.count)",
                color: Color(hex: "#EF4444")
            )
        }
        .padding(.horizontal)
    }
    
    private func filterEntries(for range: GraphTimeRange) -> [TokenUsage] {
        let cutoffDate = Date().addingTimeInterval(-Double(range.hours * 3600))
        return history.entries.filter { $0.timestamp > cutoffDate }
    }
}

struct StatBox: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(.white.opacity(0.6))
            
            Text(value)
                .font(.title3.bold())
                .foregroundColor(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(color.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(color.opacity(0.3), lineWidth: 1)
                )
        )
    }
}