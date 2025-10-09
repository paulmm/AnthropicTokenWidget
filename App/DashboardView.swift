import SwiftUI
import Charts

struct DashboardView: View {
    @EnvironmentObject var tokenMonitor: TokenUsageMonitor
    @State private var showingExportOptions = false
    @State private var refreshing = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Token Dashboard")
                    .font(.largeTitle.bold())
                Spacer()
                Button(action: { showingExportOptions.toggle() }) {
                    Image(systemName: "square.and.arrow.up")
                }
                .buttonStyle(.borderless)

                Button(action: refreshData) {
                    Image(systemName: "arrow.clockwise")
                        .rotationEffect(.degrees(refreshing ? 360 : 0))
                        .animation(refreshing ? .linear(duration: 1).repeatForever(autoreverses: false) : .default, value: refreshing)
                }
                .buttonStyle(.borderless)
            }
            .padding()

            Divider()

            // Content
            ScrollView {
                VStack(spacing: 20) {
                    if let usage = tokenMonitor.currentUsage {
                        mainGaugeCard(usage: usage)

                        if let prediction = tokenMonitor.currentPrediction {
                            predictionCard(prediction: prediction)
                        }

                        quickStatsGrid(usage: usage)

                        recentActivityCard()

                        modelBreakdownCard()
                    } else {
                        ProgressView("Loading token usage...")
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .padding(50)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .sheet(isPresented: $showingExportOptions) {
            ExportOptionsView()
        }
    }
    
    private func mainGaugeCard(usage: TokenUsage) -> some View {
        HStack(spacing: 20) {
            // Left: Burn Rate Gauge
            BurnRateGauge(
                burnRate: tokenMonitor.calculateBurnRate(over: 300),
                safeRate: tokenMonitor.currentPrediction?.safeRate ?? 200
            )
            .frame(height: 300)

            // Right: Usage Tachometer
            TachometerView(usage: usage, size: .systemLarge)
                .frame(height: 300)
        }
        .padding(20)
    }
    
    private func predictionCard(prediction: Prediction) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "wand.and.stars")
                    .foregroundColor(Color(hex: "#F59E0B"))
                Text("AI Prediction")
                    .font(.headline)
                Spacer()
                Text("\(Int(prediction.confidence * 100))% confidence")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Text(prediction.recommendation)
                .font(.body)
                .foregroundColor(.primary)
            
            HStack {
                VStack(alignment: .leading) {
                    Text("Time to Limit")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(prediction.timeToLimitFormatted)
                        .font(.title3.bold())
                        .foregroundColor(prediction.timeToLimit == nil ? .green : .orange)
                }
                
                Spacer()
                
                VStack(alignment: .leading) {
                    Text("Burn Rate")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(prediction.burnRateFormatted)
                        .font(.title3.bold())
                }
                
                Spacer()
                
                VStack(alignment: .leading) {
                    Text("Safe Rate")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(prediction.safeRateFormatted)
                        .font(.title3.bold())
                        .foregroundColor(.green)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 15)
                .fill(Color(nsColor: .windowBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 15)
                .stroke(Color(hex: "#F59E0B").opacity(0.3), lineWidth: 1)
        )
    }
    
    private func quickStatsGrid(usage: TokenUsage) -> some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 15) {
            StatCard(
                title: "Used Today",
                value: "\(usage.tokensUsed)",
                icon: "flame.fill",
                color: Color(hex: usage.usageColor)
            )
            
            StatCard(
                title: "Remaining",
                value: "\(usage.tokensRemaining)",
                icon: "battery.75",
                color: .green
            )
            
            StatCard(
                title: "Window Reset",
                value: formatTimeRemaining(usage.timeUntilReset),
                icon: "clock.fill",
                color: .blue
            )
            
            StatCard(
                title: "Account Tier",
                value: usage.tier.displayName,
                icon: "star.fill",
                color: .purple
            )
        }
    }
    
    private func recentActivityCard() -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .foregroundColor(.blue)
                Text("Recent Activity")
                    .font(.headline)
                Spacer()
                NavigationLink(destination: HistoryView()) {
                    Text("See All")
                        .font(.caption)
                }
            }
            
            if tokenMonitor.usageHistory.count > 0 {
                MiniUsageChart(history: Array(tokenMonitor.usageHistory.suffix(20)))
                    .frame(height: 100)
            } else {
                Text("No recent activity")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 100)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 15)
                .fill(Color(nsColor: .windowBackgroundColor))
        )
    }
    
    private func modelBreakdownCard() -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "chart.pie.fill")
                    .foregroundColor(.purple)
                Text("Model Usage")
                    .font(.headline)
                Spacer()
            }
            
            ModelUsagePieChart(history: tokenMonitor.usageHistory)
                .frame(height: 200)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 15)
                .fill(Color(nsColor: .windowBackgroundColor))
        )
    }
    
    private func refreshData() {
        refreshing = true
        Task {
            await tokenMonitor.refreshUsage()
            // Add small delay so user can see the refresh happened
            try? await Task.sleep(nanoseconds: 500_000_000)
            await MainActor.run {
                refreshing = false
            }
        }
    }
    
    private func formatTimeRemaining(_ interval: TimeInterval) -> String {
        let hours = Int(interval) / 3600
        let minutes = Int(interval) % 3600 / 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .font(.title3)
                Spacer()
            }
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text(value)
                .font(.title2.bold())
                .foregroundColor(.primary)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
    }
}

struct MiniUsageChart: View {
    let history: [TokenUsage]
    
    var body: some View {
        Chart(history) { usage in
            LineMark(
                x: .value("Time", usage.timestamp),
                y: .value("Tokens", usage.tokensUsed)
            )
            .foregroundStyle(Color.blue.gradient)
            .interpolationMethod(.catmullRom)
        }
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
    }
}

struct ModelUsagePieChart: View {
    let history: [TokenUsage]

    var modelBreakdown: [(ModelType, Int)] {
        var breakdown: [ModelType: Int] = [:]
        for usage in history {
            if let model = usage.modelType {
                breakdown[model, default: 0] += usage.tokensUsed
            }
        }
        return breakdown.sorted { $0.value > $1.value }
    }

    var body: some View {
        if modelBreakdown.isEmpty {
            Text("No model data available")
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            if #available(macOS 14.0, *) {
                Chart(modelBreakdown, id: \.0) { model, tokens in
                    SectorMark(
                        angle: .value("Tokens", tokens),
                        innerRadius: .ratio(0.5),
                        angularInset: 2
                    )
                    .foregroundStyle(Color(hex: model.color))
                    .opacity(0.9)
                }
                .chartBackground { _ in
                    VStack {
                        Text("\(modelBreakdown.reduce(0) { $0 + $1.1 })")
                            .font(.title2.bold())
                        Text("Total Tokens")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            } else {
                VStack {
                    Text("Model breakdown requires macOS 14.0 or later")
                        .foregroundColor(.secondary)
                    ForEach(modelBreakdown, id: \.0) { model, tokens in
                        HStack {
                            Circle()
                                .fill(Color(hex: model.color))
                                .frame(width: 12, height: 12)
                            Text(model.displayName)
                            Spacer()
                            Text("\(tokens)")
                                .bold()
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
    }
}
