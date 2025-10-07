import SwiftUI

struct ExportOptionsView: View {
    @EnvironmentObject var tokenMonitor: TokenUsageMonitor
    @Environment(\.dismiss) var dismiss
    @State private var exportFormat: ExportFormat = .csv
    @State private var includeHistory = true
    @State private var includePredictions = true
    @State private var includePatterns = true
    @State private var dateRange = DateRange.all
    @State private var exportURL: URL?
    @State private var isExporting = false
    
    enum DateRange: String, CaseIterable {
        case today = "Today"
        case week = "Last 7 Days"
        case month = "Last 30 Days"
        case all = "All Time"
        
        var days: Int? {
            switch self {
            case .today: return 1
            case .week: return 7
            case .month: return 30
            case .all: return nil
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Export Data")
                    .font(.title2.bold())
                Spacer()
            }
            .padding()
            .background(Color(nsColor: .controlBackgroundColor))

            // Form content
            Form {
                Section("Export Format") {
                    Picker("Format", selection: $exportFormat) {
                        Label("CSV", systemImage: "tablecells").tag(ExportFormat.csv)
                        Label("JSON", systemImage: "curlybraces").tag(ExportFormat.json)
                    }
                    .pickerStyle(RadioGroupPickerStyle())
                }

                Section("Data to Include") {
                    Toggle("Usage History", isOn: $includeHistory)
                    Toggle("Predictions", isOn: $includePredictions)
                    Toggle("Usage Patterns", isOn: $includePatterns)
                }

                Section("Date Range") {
                    Picker("Period", selection: $dateRange) {
                        ForEach(DateRange.allCases, id: \.self) { range in
                            Text(range.rawValue).tag(range)
                        }
                    }
                    .pickerStyle(RadioGroupPickerStyle())
                }

                Section {
                    if isExporting {
                        HStack {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle())
                            Text("Exporting...")
                                .foregroundColor(.secondary)
                        }
                    } else if let url = exportURL {
                        VStack(alignment: .leading, spacing: 8) {
                            Label("Export Complete", systemImage: "checkmark.circle.fill")
                                .foregroundColor(.green)

                            Text(url.lastPathComponent)
                                .font(.caption)
                                .foregroundColor(.secondary)

                            Button("Open in Finder") {
                                NSWorkspace.shared.selectFile(url.path, inFileViewerRootedAtPath: "")
                            }
                        }
                    }
                }
            }

            // Footer with buttons
            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .buttonStyle(.bordered)

                Spacer()

                Button("Export") {
                    performExport()
                }
                .buttonStyle(.borderedProminent)
                .disabled(isExporting || (!includeHistory && !includePredictions && !includePatterns))
            }
            .padding()
            .background(Color(nsColor: .controlBackgroundColor))
        }
        .frame(width: 500, height: 450)
    }
    
    private func performExport() {
        isExporting = true
        
        Task {
            await MainActor.run {
                let filteredHistory = filterHistory()
                exportURL = exportData(history: filteredHistory)
                isExporting = false
            }
        }
    }
    
    private func filterHistory() -> [TokenUsage] {
        guard let days = dateRange.days else {
            return tokenMonitor.usageHistory
        }
        
        let cutoff = Date().addingTimeInterval(-Double(days * 86400))
        return tokenMonitor.usageHistory.filter { $0.timestamp > cutoff }
    }
    
    private func exportData(history: [TokenUsage]) -> URL? {
        let fileName = "anthropic_usage_\(Date().timeIntervalSince1970).\(exportFormat.fileExtension)"
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        
        do {
            let data: Data
            
            switch exportFormat {
            case .csv:
                data = createCSVData(history: history)
            case .json:
                data = try createJSONData(history: history)
            }
            
            try data.write(to: tempURL)
            return tempURL
        } catch {
            print("Export failed: \(error)")
            return nil
        }
    }
    
    private func createCSVData(history: [TokenUsage]) -> Data {
        var csv = "Timestamp,Tokens Used,Max Tokens,Percentage,Tier,Model,Window Start,Window End\n"
        
        for entry in history {
            let row = [
                "\(entry.timestamp.timeIntervalSince1970)",
                "\(entry.tokensUsed)",
                "\(entry.maxTokens)",
                "\(entry.percentageUsed)",
                entry.tier.rawValue,
                entry.modelType?.rawValue ?? "",
                "\(entry.windowStart.timeIntervalSince1970)",
                "\(entry.windowEnd.timeIntervalSince1970)"
            ].joined(separator: ",")
            csv += row + "\n"
        }
        
        if includePredictions, let prediction = tokenMonitor.currentPrediction {
            csv += "\n\nPredictions\n"
            csv += "Projected Usage,Time to Limit,Confidence,Burn Rate,Safe Rate\n"
            csv += "\(prediction.projectedUsage),\(prediction.timeToLimit ?? 0),\(prediction.confidence),\(prediction.burnRate),\(prediction.safeRate)\n"
        }
        
        return csv.data(using: .utf8) ?? Data()
    }
    
    private func createJSONData(history: [TokenUsage]) throws -> Data {
        var exportData: [String: Any] = [:]
        
        if includeHistory {
            exportData["history"] = history.map { usage in
                [
                    "timestamp": usage.timestamp.timeIntervalSince1970,
                    "tokensUsed": usage.tokensUsed,
                    "maxTokens": usage.maxTokens,
                    "percentageUsed": usage.percentageUsed,
                    "tier": usage.tier.rawValue,
                    "model": usage.modelType?.rawValue ?? "",
                    "windowStart": usage.windowStart.timeIntervalSince1970,
                    "windowEnd": usage.windowEnd.timeIntervalSince1970
                ]
            }
        }
        
        if includePredictions, let prediction = tokenMonitor.currentPrediction {
            exportData["prediction"] = [
                "projectedUsage": prediction.projectedUsage,
                "timeToLimit": prediction.timeToLimit ?? 0,
                "confidence": prediction.confidence,
                "recommendation": prediction.recommendation,
                "burnRate": prediction.burnRate,
                "safeRate": prediction.safeRate
            ]
        }
        
        if includePatterns {
            let modelBreakdown = history.reduce(into: [String: Int]()) { result, usage in
                if let model = usage.modelType {
                    result[model.rawValue, default: 0] += usage.tokensUsed
                }
            }
            exportData["patterns"] = [
                "modelBreakdown": modelBreakdown,
                "totalEntries": history.count,
                "dateRange": dateRange.rawValue
            ]
        }
        
        return try JSONSerialization.data(withJSONObject: exportData, options: .prettyPrinted)
    }
}