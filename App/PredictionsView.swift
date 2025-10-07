import SwiftUI
import Charts

struct PredictionsView: View {
    @EnvironmentObject var tokenMonitor: TokenUsageMonitor
    @State private var selectedTimeFrame = 0
    private let predictionEngine = PredictionEngine()
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Predictions & Insights")
                    .font(.largeTitle.bold())
                Spacer()
            }
            .padding()

            Divider()

            // Content
            ScrollView {
                VStack(spacing: 20) {
                    if let currentPrediction = tokenMonitor.currentPrediction {
                        currentPredictionCard(currentPrediction)
                        burnRateChart
                        optimalTimesCard
                        patternsCard
                    } else {
                        EmptyPredictionsView()
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
    
    private func currentPredictionCard(_ prediction: Prediction) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "wand.and.stars")
                    .font(.title2)
                    .foregroundColor(Color(hex: "#F59E0B"))
                
                VStack(alignment: .leading) {
                    Text("Current Prediction")
                        .font(.headline)
                    Text("Confidence: \(Int(prediction.confidence * 100))%")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                ConfidenceBadge(level: prediction.confidenceLevel)
            }
            
            Text(prediction.recommendation)
                .font(.body)
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(hex: "#F59E0B").opacity(0.1))
                .cornerRadius(8)
            
            HStack(spacing: 30) {
                VStack(alignment: .leading) {
                    Label("Projected Usage", systemImage: "chart.line.uptrend.xyaxis")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(prediction.projectedUsage) tokens")
                        .font(.title3.bold())
                }
                
                VStack(alignment: .leading) {
                    Label("Time to Limit", systemImage: "clock")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(prediction.timeToLimitFormatted)
                        .font(.title3.bold())
                        .foregroundColor(prediction.timeToLimit == nil ? .green : .orange)
                }
                
                VStack(alignment: .leading) {
                    Label("Safe Rate", systemImage: "checkmark.shield")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(prediction.safeRateFormatted)
                        .font(.title3.bold())
                        .foregroundColor(.green)
                }
            }
        }
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(12)
    }
    
    private var burnRateChart: some View {
        VStack(alignment: .leading) {
            Text("Burn Rate Trend")
                .font(.headline)
            
            Chart {
                ForEach(burnRateData, id: \.0) { time, rate in
                    LineMark(
                        x: .value("Time", time),
                        y: .value("Rate", rate)
                    )
                    .foregroundStyle(Color.orange.gradient)
                    .interpolationMethod(.catmullRom)
                    
                    AreaMark(
                        x: .value("Time", time),
                        y: .value("Rate", rate)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.orange.opacity(0.3), Color.orange.opacity(0.05)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                }
                
                if let prediction = tokenMonitor.currentPrediction {
                    RuleMark(y: .value("Safe Rate", prediction.safeRate))
                        .foregroundStyle(Color.green)
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 5]))
                }
            }
            .frame(height: 200)
            .chartYAxisLabel("Tokens/min")
        }
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(12)
    }
    
    private var optimalTimesCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "calendar.badge.clock")
                    .foregroundColor(.blue)
                Text("Optimal Usage Times")
                    .font(.headline)
            }
            
            let patterns = predictionEngine.predictBestUsageTimes()
            
            if patterns.isEmpty {
                Text("Not enough data to determine optimal times")
                    .foregroundColor(.secondary)
                    .padding()
            } else {
                ForEach(patterns.prefix(5), id: \.hourOfDay) { pattern in
                    HStack {
                        VStack(alignment: .leading) {
                            Text("\(pattern.dayName), \(pattern.hourFormatted)")
                                .font(.subheadline)
                            Text("Avg: \(Int(pattern.averageUsage)) tokens")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        UsageLevelIndicator(usage: pattern.averageUsage / 5000)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(12)
    }
    
    private var patternsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "chart.dots.scatter")
                    .foregroundColor(.purple)
                Text("Usage Patterns")
                    .font(.headline)
            }
            
            Picker("Time Frame", selection: $selectedTimeFrame) {
                Text("Daily").tag(0)
                Text("Weekly").tag(1)
                Text("Monthly").tag(2)
            }
            .pickerStyle(SegmentedPickerStyle())
            
            if selectedTimeFrame == 0 {
                DailyPatternChart()
            } else if selectedTimeFrame == 1 {
                WeeklyPatternChart()
            } else {
                MonthlyPatternChart()
            }
        }
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(12)
    }
    
    private var burnRateData: [(Date, Double)] {
        let history = tokenMonitor.usageHistory.suffix(20)
        var data: [(Date, Double)] = []
        
        for i in 1..<history.count {
            let current = history[history.index(history.startIndex, offsetBy: i)]
            let previous = history[history.index(history.startIndex, offsetBy: i - 1)]
            
            let tokenDiff = current.tokensUsed - previous.tokensUsed
            let timeDiff = current.timestamp.timeIntervalSince(previous.timestamp) / 60
            
            if timeDiff > 0 {
                let rate = Double(tokenDiff) / timeDiff
                data.append((current.timestamp, rate))
            }
        }
        
        return data
    }
}

struct ConfidenceBadge: View {
    let level: ConfidenceLevel
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "checkmark.seal.fill")
                .font(.caption)
            Text(level.rawValue)
                .font(.caption.bold())
        }
        .foregroundColor(.white)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color(hex: level.color))
        .cornerRadius(6)
    }
}

struct UsageLevelIndicator: View {
    let usage: Double
    
    var color: Color {
        switch usage {
        case 0..<0.3:
            return .green
        case 0.3..<0.7:
            return .yellow
        default:
            return .red
        }
    }
    
    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<5) { index in
                Rectangle()
                    .fill(Double(index) < usage * 5 ? color : Color.gray.opacity(0.3))
                    .frame(width: 4, height: 12)
            }
        }
    }
}

struct DailyPatternChart: View {
    var body: some View {
        Chart {
            ForEach(0..<24, id: \.self) { hour in
                BarMark(
                    x: .value("Hour", hour),
                    y: .value("Usage", Double.random(in: 1000...5000))
                )
                .foregroundStyle(Color.blue.gradient)
            }
        }
        .frame(height: 150)
        .chartXAxisLabel("Hour of Day")
    }
}

struct WeeklyPatternChart: View {
    let days = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
    
    var body: some View {
        Chart {
            ForEach(days, id: \.self) { day in
                BarMark(
                    x: .value("Day", day),
                    y: .value("Usage", Double.random(in: 10000...30000))
                )
                .foregroundStyle(Color.purple.gradient)
            }
        }
        .frame(height: 150)
    }
}

struct MonthlyPatternChart: View {
    var body: some View {
        Chart {
            ForEach(1...30, id: \.self) { day in
                LineMark(
                    x: .value("Day", day),
                    y: .value("Usage", Double.random(in: 20000...50000))
                )
                .foregroundStyle(Color.green.gradient)
                .interpolationMethod(.catmullRom)
            }
        }
        .frame(height: 150)
        .chartXAxisLabel("Day of Month")
    }
}

struct EmptyPredictionsView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "wand.and.stars")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            Text("No Predictions Available")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Predictions will appear after collecting usage data")
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(50)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}