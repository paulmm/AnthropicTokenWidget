import WidgetKit
import SwiftUI

struct TokenWidgetBundle: WidgetBundle {
    var body: some Widget {
        TachometerWidget()
        DashboardWidget()
    }
}

struct TachometerEntry: TimelineEntry {
    let date: Date
    let usage: TokenUsage
    let prediction: Prediction?

    init(date: Date, usage: TokenUsage, prediction: Prediction? = nil) {
        self.date = date
        self.usage = usage
        self.prediction = prediction
    }
}

struct DashboardEntry: TimelineEntry {
    let date: Date
    let usage: TokenUsage
    let history: TokenUsageHistory
    let prediction: Prediction?
}

struct TachometerWidget: Widget {
    let kind: String = "TachometerWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TachometerProvider()) { entry in
            TachometerWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Token Usage Gauge")
        .description("Monitor your Anthropic API token usage with a visual tachometer.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct DashboardWidget: Widget {
    let kind: String = "DashboardWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: DashboardProvider()) { entry in
            DashboardWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Token Usage Dashboard")
        .description("Comprehensive view of your token usage with graphs and predictions.")
        .supportedFamilies([.systemLarge])
    }
}

struct TachometerWidgetEntryView: View {
    var entry: TachometerProvider.Entry
    @Environment(\.widgetFamily) var family
    
    var body: some View {
        ZStack {
            Color(hex: "#0F172A")
            
            switch family {
            case .systemSmall:
                SmallTachometerView(usage: entry.usage)
            case .systemMedium:
                MediumTachometerView(usage: entry.usage, prediction: entry.prediction)
            default:
                TachometerView(usage: entry.usage, size: family)
            }
        }
        .widgetURL(URL(string: "anthropic-widget://open"))
    }
}

struct DashboardWidgetEntryView: View {
    var entry: DashboardProvider.Entry
    @Environment(\.widgetFamily) var family
    
    var body: some View {
        ZStack {
            Color(hex: "#0F172A")
            
            VStack(spacing: 12) {
                HStack {
                    TachometerView(usage: entry.usage, size: .systemSmall)
                        .frame(width: 150, height: 150)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        if let prediction = entry.prediction {
                            PredictionView(prediction: prediction)
                        }
                        
                        Spacer()
                        
                        QuickStatsView(usage: entry.usage)
                    }
                    
                    Spacer()
                }
                .padding()
                
                UsageGraphView(history: entry.history)
                    .frame(maxHeight: 200)
            }
        }
        .widgetURL(URL(string: "anthropic-widget://dashboard"))
    }
}

struct SmallTachometerView: View {
    let usage: TokenUsage
    
    var body: some View {
        TachometerView(usage: usage, size: .systemSmall)
            .padding(8)
    }
}

struct MediumTachometerView: View {
    let usage: TokenUsage
    let prediction: Prediction?
    
    var body: some View {
        HStack(spacing: 16) {
            TachometerView(usage: usage, size: .systemSmall)
                .frame(width: 120, height: 120)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Token Usage")
                    .font(.headline)
                    .foregroundColor(.white)
                
                HStack {
                    Image(systemName: "flame.fill")
                        .foregroundColor(Color(hex: usage.usageColor))
                    Text("\(usage.tokensUsed) / \(usage.maxTokens)")
                        .font(.system(.body, design: .monospaced))
                        .foregroundColor(.white.opacity(0.9))
                }
                
                if let prediction = prediction {
                    Divider()
                        .background(Color.white.opacity(0.2))
                    
                    HStack {
                        Image(systemName: "chart.line.uptrend.xyaxis")
                            .foregroundColor(Color(hex: "#F59E0B"))
                        Text(prediction.timeToLimitFormatted)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundColor(.white.opacity(0.8))
                    }
                    
                    Text(prediction.recommendation)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.6))
                        .lineLimit(2)
                }
            }
            
            Spacer()
        }
        .padding()
    }
}

struct PredictionView: View {
    let prediction: Prediction
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Label("Prediction", systemImage: "wand.and.stars")
                .font(.caption)
                .foregroundColor(.white.opacity(0.6))
            
            Text(prediction.recommendation)
                .font(.caption2)
                .foregroundColor(.white.opacity(0.8))
                .lineLimit(2)
            
            HStack(spacing: 8) {
                Label(prediction.timeToLimitFormatted, systemImage: "clock")
                Label(prediction.burnRateFormatted, systemImage: "flame")
            }
            .font(.caption2)
            .foregroundColor(Color(hex: "#F59E0B"))
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.white.opacity(0.05))
        )
    }
}

struct QuickStatsView: View {
    let usage: TokenUsage
    
    var body: some View {
        HStack(spacing: 12) {
            StatItem(
                icon: "percent",
                value: String(format: "%.0f%%", usage.percentageUsed * 100),
                color: Color(hex: usage.usageColor)
            )
            
            StatItem(
                icon: "clock",
                value: formatTimeRemaining(),
                color: .white.opacity(0.8)
            )
        }
    }
    
    private func formatTimeRemaining() -> String {
        let timeRemaining = usage.timeUntilReset
        let hours = Int(timeRemaining) / 3600
        let minutes = Int(timeRemaining) % 3600 / 60
        
        if hours > 0 {
            return "\(hours)h"
        } else {
            return "\(minutes)m"
        }
    }
}

struct StatItem: View {
    let icon: String
    let value: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)
            Text(value)
                .font(.caption.bold())
        }
        .foregroundColor(color)
    }
}