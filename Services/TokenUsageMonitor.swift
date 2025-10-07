import Foundation
import Combine
import SwiftUI

@MainActor
public class TokenUsageMonitor: ObservableObject {
    public static let shared = TokenUsageMonitor()

    @Published public var currentUsage: TokenUsage?
    @Published public var usageHistory: [TokenUsage] = []
    @Published public var currentPrediction: Prediction?
    @Published public var isMonitoring = false
    @Published public var lastError: Error?

    private var apiService: AnthropicAPIServiceProtocol
    private let claudeDataService = ClaudeCodeDataService()
    private var refreshTimer: Timer?
    private var refreshInterval: TimeInterval = 60 // Check for new data every minute
    private let predictionEngine = PredictionEngine()

    private init() {
        self.apiService = MockAnthropicAPIService()
        loadHistoricalData()
    }

    /// Load usage data from Claude Code local files
    public func loadClaudeCodeData() async throws {
        let entries = try await claudeDataService.getAllUsageData()

        guard !entries.isEmpty else {
            throw ClaudeDataError.noDataFound
        }

        // Get current window usage
        let current = claudeDataService.getCurrentWindowUsage(entries)

        // Aggregate by 5-hour windows
        let aggregated = claudeDataService.aggregateByTimeWindow(entries, windowHours: 5)

        await MainActor.run {
            self.currentUsage = current
            self.usageHistory = aggregated
            self.currentPrediction = generatePrediction(for: current)
            self.isMonitoring = true
        }

        // Start monitoring for updates
        startMonitoring()
    }
    
    public func configure(apiKey: String, refreshInterval: TimeInterval = 30) {
        self.apiService = AnthropicAPIService(apiKey: apiKey)
        self.refreshInterval = refreshInterval
    }
    
    public func startMonitoring() {
        guard refreshTimer == nil else { return }

        isMonitoring = true
        refreshTimer?.invalidate()

        // Start periodic refresh
        refreshTimer = Timer.scheduledTimer(withTimeInterval: refreshInterval, repeats: true) { _ in
            Task { @MainActor in
                await self.refreshUsage()
            }
        }
    }

    public func stopMonitoring() {
        isMonitoring = false
        refreshTimer?.invalidate()
        refreshTimer = nil
    }

    @MainActor
    public func refreshUsage() async {
        do {
            // Reload data from Claude Code files
            let entries = try await claudeDataService.getAllUsageData()

            guard !entries.isEmpty else {
                return
            }

            // Get current window usage
            let current = claudeDataService.getCurrentWindowUsage(entries)

            // Aggregate by 5-hour windows
            let aggregated = claudeDataService.aggregateByTimeWindow(entries, windowHours: 5)

            currentUsage = current
            usageHistory = aggregated
            currentPrediction = generatePrediction(for: current)

            saveHistoricalData()
            checkAlerts(for: current)

            lastError = nil
        } catch {
            lastError = error
            print("Failed to refresh usage: \(error)")
        }
    }
    
    public func generatePrediction(for usage: TokenUsage) -> Prediction {
        return predictionEngine.predict(
            currentUsage: usage,
            history: usageHistory
        )
    }
    
    private func checkAlerts(for usage: TokenUsage) {
        let settings = AccountSettings()
        
        if usage.percentageUsed >= settings.alertThresholds.critical && settings.notificationsEnabled {
            NotificationManager.shared.sendCriticalAlert(usage: usage)
        } else if usage.percentageUsed >= settings.alertThresholds.warning && settings.notificationsEnabled {
            NotificationManager.shared.sendWarningAlert(usage: usage)
        }
        
        if let prediction = currentPrediction,
           let timeToLimit = prediction.timeToLimit,
           timeToLimit < 1800 && settings.notificationsEnabled {
            NotificationManager.shared.sendPredictionAlert(prediction: prediction)
        }
    }
    
    public func exportData(format: ExportFormat) -> URL? {
        let exportManager = DataExportManager()
        return exportManager.export(history: usageHistory, format: format)
    }
    
    private func loadHistoricalData() {
        if let data = UserDefaults.standard.data(forKey: "usageHistory"),
           let history = try? JSONDecoder().decode([TokenUsage].self, from: data) {
            usageHistory = history
        }
    }
    
    private func saveHistoricalData() {
        if let data = try? JSONEncoder().encode(usageHistory) {
            UserDefaults.standard.set(data, forKey: "usageHistory")
        }
    }
    
    public func calculateBurnRate(over interval: TimeInterval = 300) -> Double {
        guard usageHistory.count >= 2 else { return 0 }
        
        let cutoff = Date().addingTimeInterval(-interval)
        let recentUsage = usageHistory.filter { $0.timestamp > cutoff }
        
        guard recentUsage.count >= 2,
              let first = recentUsage.first,
              let last = recentUsage.last else { return 0 }
        
        let tokenDiff = last.tokensUsed - first.tokensUsed
        let timeDiff = last.timestamp.timeIntervalSince(first.timestamp) / 60
        
        return timeDiff > 0 ? Double(tokenDiff) / timeDiff : 0
    }
    
    public func getUsageByTimeRange(_ range: GraphTimeRange) -> [TokenUsage] {
        let cutoff = Date().addingTimeInterval(-Double(range.hours * 3600))
        return usageHistory.filter { $0.timestamp > cutoff }
    }
}

public enum ExportFormat {
    case csv
    case json
    
    var fileExtension: String {
        switch self {
        case .csv: return "csv"
        case .json: return "json"
        }
    }
}

class DataExportManager {
    func export(history: [TokenUsage], format: ExportFormat) -> URL? {
        let fileName = "token_usage_\(Date().timeIntervalSince1970).\(format.fileExtension)"
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        
        do {
            let data: Data
            
            switch format {
            case .csv:
                data = exportAsCSV(history: history)
            case .json:
                let encoder = JSONEncoder()
                encoder.outputFormatting = .prettyPrinted
                encoder.dateEncodingStrategy = .iso8601
                data = try encoder.encode(history)
            }
            
            try data.write(to: tempURL)
            return tempURL
        } catch {
            print("Export failed: \(error)")
            return nil
        }
    }
    
    private func exportAsCSV(history: [TokenUsage]) -> Data {
        var csv = "Timestamp,Tokens Used,Max Tokens,Percentage,Tier,Model\n"
        
        for entry in history {
            let row = "\(entry.timestamp.timeIntervalSince1970),\(entry.tokensUsed),\(entry.maxTokens),\(entry.percentageUsed),\(entry.tier.rawValue),\(entry.modelType?.rawValue ?? "")\n"
            csv += row
        }
        
        return csv.data(using: .utf8) ?? Data()
    }
}