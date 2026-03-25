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

    private let claudeDataService = ClaudeCodeDataService()
    private var refreshTimer: Timer?
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
        guard !entries.isEmpty else { return 0 }

        // Look at last 30 seconds for real-time "current" rate
        let thirtySecondsAgo = Date().addingTimeInterval(-30)
        let recentEntries = entries.filter { $0.timestamp >= thirtySecondsAgo }

        guard !recentEntries.isEmpty else { return 0 }

        // Sum all tokens in the last 30 seconds
        let totalTokens = recentEntries.reduce(0) { $0 + $1.totalTokens }

        guard totalTokens > 0 else { return 0 }

        // Calculate actual elapsed time from oldest entry to now
        guard let oldest = recentEntries.min(by: { $0.timestamp < $1.timestamp }) else {
            return 0
        }

        let elapsedMinutes = Date().timeIntervalSince(oldest.timestamp) / 60.0

        // If we have at least 10 seconds of data, calculate rate
        guard elapsedMinutes >= 0.16, elapsedMinutes.isFinite else {
            return 0
        }

        let rate = Double(totalTokens) / elapsedMinutes

        // Sanity check: cap at reasonable maximum (e.g., 100k tokens/min)
        return min(rate, 100_000)
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