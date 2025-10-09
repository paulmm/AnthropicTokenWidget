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
    @Published public var realtimeBurnRate: Double = 0 // Tokens per minute

    private var apiService: AnthropicAPIServiceProtocol
    private let claudeDataService = ClaudeCodeDataService()
    private var refreshTimer: Timer?
    private var refreshInterval: TimeInterval = 15 // Default: check for new data every 15 seconds
    private let predictionEngine = PredictionEngine()

    // Store raw entries for real-time burn rate calculation
    private var rawEntries: [ClaudeUsageEntry] = []

    // Read refresh interval from settings
    private func getRefreshInterval() -> TimeInterval {
        let savedInterval = UserDefaults.standard.double(forKey: "refreshInterval")
        // Default to 15 seconds for real-time feel, min 10 seconds
        if savedInterval > 0 {
            return max(savedInterval, 10)
        }
        return 15
    }

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

        // Aggregate by 5-hour windows first to build history
        let aggregated = claudeDataService.aggregateByTimeWindow(entries, windowHours: 5)

        // Get tier from settings
        let tier = getUserTier()

        // Calculate P90 limit if using custom tier
        await MainActor.run {
            self.rawEntries = entries
            self.usageHistory = aggregated
            self.realtimeBurnRate = calculateRealtimeBurnRate(from: entries)
        }
        let p90Limit = tier == .custom ? calculateP90Limit() : nil

        // Get current window usage with P90 limit
        let current = claudeDataService.getCurrentWindowUsage(entries, tier: tier, p90Limit: p90Limit)

        await MainActor.run {
            self.currentUsage = current
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
        // Stop any existing timer first
        refreshTimer?.invalidate()
        refreshTimer = nil

        isMonitoring = true

        // Get refresh interval from settings
        let interval = getRefreshInterval()

        print("📊 Starting monitoring with \(interval)s refresh interval")

        // Start periodic refresh
        refreshTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { _ in
            Task { @MainActor in
                await self.refreshUsage()
            }
        }

        // Fire immediately for instant update
        Task { @MainActor in
            await self.refreshUsage()
        }
    }

    public func stopMonitoring() {
        print("⏸️ Stopping monitoring")
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

            // Store raw entries for real-time calculations
            rawEntries = entries

            // Calculate real-time burn rate
            realtimeBurnRate = calculateRealtimeBurnRate(from: entries)

            // Aggregate by 5-hour windows first
            let aggregated = claudeDataService.aggregateByTimeWindow(entries, windowHours: 5)
            usageHistory = aggregated

            // Get tier from settings
            let tier = getUserTier()

            // Calculate P90 limit if using custom tier
            let p90Limit = tier == .custom ? calculateP90Limit() : nil

            // Get current window usage with P90 limit
            let current = claudeDataService.getCurrentWindowUsage(entries, tier: tier, p90Limit: p90Limit)

            currentUsage = current
            currentPrediction = generatePrediction(for: current)

            saveHistoricalData()
            checkAlerts(for: current)

            lastError = nil
        } catch {
            lastError = error
            print("Failed to refresh usage: \(error)")
        }
    }

    private func getUserTier() -> AccountTier {
        if let tierString = UserDefaults.standard.string(forKey: "accountTier"),
           let tier = AccountTier(rawValue: tierString) {
            return tier
        }
        return .custom // Default to custom (auto-detect)
    }

    /// Calculate P90 (90th percentile) usage from history for custom tier
    public func calculateP90Limit() -> Int {
        guard !usageHistory.isEmpty else {
            return 88_000 // Default to Max5 level if no history
        }

        // Get all token usage values
        let usageValues = usageHistory.map { $0.tokensUsed }.sorted()

        // Calculate 90th percentile
        let p90Index = Int(Double(usageValues.count) * 0.9)
        let p90Value = usageValues[min(p90Index, usageValues.count - 1)]

        // Add 20% buffer for safety
        let limitWithBuffer = Int(Double(p90Value) * 1.2)

        // Clamp between reasonable bounds
        return max(19_000, min(limitWithBuffer, 220_000))
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
    
    /// Calculate real-time burn rate from raw entries
    private func calculateRealtimeBurnRate(from entries: [ClaudeUsageEntry]) -> Double {
        // Look at last 5 minutes of actual usage
        let fiveMinutesAgo = Date().addingTimeInterval(-300)
        let recentEntries = entries.filter { $0.timestamp >= fiveMinutesAgo }

        guard !recentEntries.isEmpty else { return 0 }

        // Sum all tokens in the last 5 minutes
        let totalTokens = recentEntries.reduce(0) { $0 + $1.totalTokens }

        // Find actual time span
        if let oldest = recentEntries.min(by: { $0.timestamp < $1.timestamp }),
           let newest = recentEntries.max(by: { $0.timestamp < $1.timestamp }) {
            let timeSpan = newest.timestamp.timeIntervalSince(oldest.timestamp) / 60.0 // minutes

            // If we have meaningful time span, calculate rate
            if timeSpan > 0.1 { // At least 6 seconds
                return Double(totalTokens) / timeSpan
            }
        }

        // If less than 5 minutes of data, extrapolate
        let actualTimeSpan = Date().timeIntervalSince(recentEntries[0].timestamp) / 60.0
        return actualTimeSpan > 0 ? Double(totalTokens) / actualTimeSpan : 0
    }

    /// Legacy burn rate calculation for backward compatibility
    public func calculateBurnRate(over interval: TimeInterval = 300) -> Double {
        return realtimeBurnRate
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