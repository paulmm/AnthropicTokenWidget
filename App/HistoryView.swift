import SwiftUI
import Charts

struct HistoryView: View {
    @EnvironmentObject var tokenMonitor: TokenUsageMonitor
    @State private var selectedRange: GraphTimeRange = .day
    @State private var selectedEntry: TokenUsage?
    @State private var showingDetails = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Usage History")
                    .font(.largeTitle.bold())
                Spacer()
            }
            .padding()

            Divider()

            // Content
            ScrollView {
                VStack(spacing: 20) {
                    timeRangeSelector

                    if !filteredHistory.isEmpty {
                        mainChart
                        statisticsCards
                        usageList
                    } else {
                        EmptyHistoryView()
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .sheet(item: $selectedEntry) { entry in
            UsageDetailView(usage: entry)
        }
    }
    
    private var filteredHistory: [TokenUsage] {
        tokenMonitor.getUsageByTimeRange(selectedRange)
    }
    
    private var timeRangeSelector: some View {
        Picker("Time Range", selection: $selectedRange) {
            ForEach(GraphTimeRange.allCases, id: \.self) { range in
                Text(range.displayName).tag(range)
            }
        }
        .pickerStyle(SegmentedPickerStyle())
    }
    
    private var mainChart: some View {
        VStack(alignment: .leading) {
            Text("Token Usage Over Time")
                .font(.headline)
            
            Chart(filteredHistory) { entry in
                LineMark(
                    x: .value("Time", entry.timestamp),
                    y: .value("Tokens", entry.tokensUsed)
                )
                .foregroundStyle(Color.blue.gradient)
                .interpolationMethod(.catmullRom)
                .lineStyle(StrokeStyle(lineWidth: 2))
                
                AreaMark(
                    x: .value("Time", entry.timestamp),
                    y: .value("Tokens", entry.tokensUsed)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color.blue.opacity(0.3), Color.blue.opacity(0.05)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .interpolationMethod(.catmullRom)
                
                if let selected = selectedEntry, selected.id == entry.id {
                    RuleMark(x: .value("Time", entry.timestamp))
                        .foregroundStyle(Color.orange)
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 5]))
                    
                    PointMark(
                        x: .value("Time", entry.timestamp),
                        y: .value("Tokens", entry.tokensUsed)
                    )
                    .foregroundStyle(Color.orange)
                    .symbolSize(100)
                }
            }
            .frame(height: 250)
            .chartXAxis {
                AxisMarks(preset: .automatic)
            }
            .chartYAxis {
                AxisMarks(preset: .automatic)
            }
            .overlay(alignment: .topTrailing) {
                if let selected = selectedEntry {
                    VStack(alignment: .trailing) {
                        Text("\(selected.tokensUsed) tokens")
                            .font(.caption.bold())
                        Text(selected.timestamp, style: .date)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .padding(8)
                    .background(Color(nsColor: .windowBackgroundColor))
                    .cornerRadius(8)
                    .shadow(radius: 2)
                }
            }
        }
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(12)
    }
    
    private var statisticsCards: some View {
        let totalUsage = filteredHistory.reduce(0) { $0 + $1.tokensUsed }
        let avgUsage = filteredHistory.isEmpty ? 0 : totalUsage / filteredHistory.count
        let maxUsage = filteredHistory.map { $0.tokensUsed }.max() ?? 0
        let windows = Set(filteredHistory.map { $0.windowStart }).count
        
        return LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            StatisticCard(
                title: "Total Tokens",
                value: "\(totalUsage)",
                icon: "sum",
                color: .blue
            )
            
            StatisticCard(
                title: "Average Usage",
                value: "\(avgUsage)",
                icon: "chart.bar.fill",
                color: .green
            )
            
            StatisticCard(
                title: "Peak Usage",
                value: "\(maxUsage)",
                icon: "arrow.up",
                color: .orange
            )
            
            StatisticCard(
                title: "Windows",
                value: "\(windows)",
                icon: "clock.arrow.circlepath",
                color: .purple
            )
        }
    }
    
    private var usageList: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent Entries")
                .font(.headline)
            
            ForEach(filteredHistory.prefix(20)) { entry in
                UsageRow(usage: entry)
                    .onTapGesture {
                        selectedEntry = entry
                    }
            }
        }
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(12)
    }
}

struct StatisticCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            
            VStack(alignment: .leading) {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(value)
                    .font(.title3.bold())
            }
            
            Spacer()
        }
        .padding()
        .background(Color(nsColor: .controlColor))
        .cornerRadius(8)
    }
}

struct UsageRow: View {
    let usage: TokenUsage
    
    var body: some View {
        HStack {
            Circle()
                .fill(Color(hex: usage.usageColor))
                .frame(width: 8, height: 8)
            
            VStack(alignment: .leading) {
                Text(usage.timestamp, style: .date)
                    .font(.caption.bold())
                Text(usage.timestamp, style: .time)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing) {
                Text("\(usage.tokensUsed)")
                    .font(.caption.bold())
                Text("\(Int(usage.percentageUsed * 100))%")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            if let model = usage.modelType {
                Text(model.displayName)
                    .font(.caption2)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color(hex: model.color).opacity(0.2))
                    .cornerRadius(4)
            }
        }
        .padding(.vertical, 4)
    }
}

struct UsageDetailView: View {
    let usage: TokenUsage
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            Form {
                Section("Details") {
                    LabeledContent("Timestamp", value: usage.timestamp.formatted())
                    LabeledContent("Tokens Used", value: "\(usage.tokensUsed)")
                    LabeledContent("Max Tokens", value: "\(usage.maxTokens)")
                    LabeledContent("Percentage", value: "\(Int(usage.percentageUsed * 100))%")
                    LabeledContent("Tier", value: usage.tier.displayName)
                    if let model = usage.modelType {
                        LabeledContent("Model", value: model.displayName)
                    }
                }
                
                Section("Window") {
                    LabeledContent("Start", value: usage.windowStart.formatted())
                    LabeledContent("End", value: usage.windowEnd.formatted())
                    LabeledContent("Time Until Reset", value: formatTime(usage.timeUntilReset))
                }
                
                Section("Status") {
                    HStack {
                        Text("Usage Level")
                        Spacer()
                        Circle()
                            .fill(Color(hex: usage.usageColor))
                            .frame(width: 12, height: 12)
                        Text(usageLevelText)
                            .foregroundColor(Color(hex: usage.usageColor))
                    }
                }
            }
            .navigationTitle("Usage Details")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private var usageLevelText: String {
        switch usage.percentageUsed {
        case 0..<0.60:
            return "Normal"
        case 0.60..<0.85:
            return "Elevated"
        default:
            return "Critical"
        }
    }
    
    private func formatTime(_ interval: TimeInterval) -> String {
        let hours = Int(interval) / 3600
        let minutes = Int(interval) % 3600 / 60
        return "\(hours)h \(minutes)m"
    }
}

struct EmptyHistoryView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            Text("No Usage History")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Start using the API to see your usage history here")
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(50)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}