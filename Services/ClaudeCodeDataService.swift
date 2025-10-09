import Foundation

/// Service for reading and parsing Claude Code usage data from local JSONL files
public class ClaudeCodeDataService: ObservableObject {
    @Published public var isLoading = false
    @Published public var lastError: Error?
    @Published public var lastUpdated: Date?

    private let fileManager = FileManager.default
    private let claudeProjectsPath: URL

    public init() {
        // Default path: ~/.claude/projects
        let homeDirectory = fileManager.homeDirectoryForCurrentUser
        self.claudeProjectsPath = homeDirectory.appendingPathComponent(".claude/projects")
    }

    /// Get all usage data from Claude Code sessions
    public func getAllUsageData() async throws -> [ClaudeUsageEntry] {
        isLoading = true
        defer { isLoading = false }

        var allEntries: [ClaudeUsageEntry] = []

        // Find all JSONL files
        let jsonlFiles = try findJSONLFiles()
        print("📁 Found \(jsonlFiles.count) JSONL files")

        // Parse each file
        for fileURL in jsonlFiles {
            do {
                let entries = try parseJSONLFile(at: fileURL)
                print("📊 Parsed \(entries.count) entries from \(fileURL.lastPathComponent)")
                allEntries.append(contentsOf: entries)
            } catch {
                print("⚠️ Error parsing \(fileURL.lastPathComponent): \(error)")
                // Continue with other files
            }
        }

        print("✅ Total entries: \(allEntries.count)")

        // Sort by timestamp
        allEntries.sort { $0.timestamp < $1.timestamp }

        await MainActor.run {
            lastUpdated = Date()
        }

        return allEntries
    }

    /// Find all JSONL files in the Claude projects directory
    private func findJSONLFiles() throws -> [URL] {
        guard fileManager.fileExists(atPath: claudeProjectsPath.path) else {
            throw ClaudeDataError.projectsDirectoryNotFound
        }

        var jsonlFiles: [URL] = []

        // Enumerate all project directories
        let projectDirs = try fileManager.contentsOfDirectory(
            at: claudeProjectsPath,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        )

        for projectDir in projectDirs {
            var isDirectory: ObjCBool = false
            guard fileManager.fileExists(atPath: projectDir.path, isDirectory: &isDirectory),
                  isDirectory.boolValue else {
                continue
            }

            // Find JSONL files in this project directory
            let files = try fileManager.contentsOfDirectory(
                at: projectDir,
                includingPropertiesForKeys: [.isRegularFileKey],
                options: [.skipsHiddenFiles]
            )

            let projectJSONLFiles = files.filter { $0.pathExtension == "jsonl" }
            jsonlFiles.append(contentsOf: projectJSONLFiles)
        }

        return jsonlFiles
    }

    /// Parse a JSONL file and extract usage entries
    private func parseJSONLFile(at url: URL) throws -> [ClaudeUsageEntry] {
        let content = try String(contentsOf: url, encoding: .utf8)
        let lines = content.components(separatedBy: .newlines).filter { !$0.isEmpty }

        var entries: [ClaudeUsageEntry] = []
        let decoder = JSONDecoder()

        var parseErrors = 0
        var successCount = 0

        for (index, line) in lines.enumerated() {
            guard let data = line.data(using: .utf8) else { continue }

            do {
                let entry = try decoder.decode(ClaudeJSONLEntry.self, from: data)

                // Only process entries that have message with usage data and a valid timestamp
                if let message = entry.message,
                   let usage = message.usage,
                   let timestamp = entry.parsedTimestamp,
                   let sessionId = entry.sessionId {

                    let modelType = message.model.flatMap { ModelType.fromString($0) }

                    let usageEntry = ClaudeUsageEntry(
                        timestamp: timestamp,
                        sessionId: sessionId,
                        inputTokens: usage.inputTokens ?? 0,
                        outputTokens: usage.outputTokens ?? 0,
                        cacheCreationTokens: usage.cacheCreationInputTokens ?? 0,
                        cacheReadTokens: usage.cacheReadInputTokens ?? 0,
                        modelType: modelType
                    )
                    entries.append(usageEntry)
                    successCount += 1
                }
            } catch {
                parseErrors += 1
                if parseErrors <= 3 {
                    print("⚠️ Parse error at line \(index): \(error)")
                }
            }
        }

        if parseErrors > 0 {
            print("⚠️ Total parse errors: \(parseErrors), successful: \(successCount)")
        }

        return entries
    }

    /// Aggregate usage data by time window (e.g., 5-hour windows)
    public func aggregateByTimeWindow(_ entries: [ClaudeUsageEntry], windowHours: Int = 5) -> [TokenUsage] {
        let windowSeconds = TimeInterval(windowHours * 3600)
        var aggregated: [TokenUsage] = []

        guard !entries.isEmpty else { return [] }

        // Group entries by time windows
        let sortedEntries = entries.sorted { $0.timestamp < $1.timestamp }
        let startDate = sortedEntries.first!.timestamp
        let endDate = sortedEntries.last!.timestamp

        var currentWindowStart = startDate

        while currentWindowStart < endDate {
            let windowEnd = currentWindowStart.addingTimeInterval(windowSeconds)

            let windowEntries = sortedEntries.filter {
                $0.timestamp >= currentWindowStart && $0.timestamp < windowEnd
            }

            if !windowEntries.isEmpty {
                let totalInput = windowEntries.reduce(0) { $0 + $1.inputTokens }
                let totalOutput = windowEntries.reduce(0) { $0 + $1.outputTokens }
                let totalCache = windowEntries.reduce(0) { $0 + $1.cacheCreationTokens + $1.cacheReadTokens }
                let totalTokens = totalInput + totalOutput

                // Determine the most used model in this window
                let modelCounts = Dictionary(grouping: windowEntries, by: { $0.modelType })
                let mostUsedModel = modelCounts.max { $0.value.count < $1.value.count }?.key

                let usage = TokenUsage(
                    timestamp: currentWindowStart,
                    tokensUsed: totalTokens,
                    windowStart: currentWindowStart,
                    windowEnd: windowEnd,
                    maxTokens: 88000, // Default Max5 limit
                    tier: .max5,
                    modelType: mostUsedModel
                )

                aggregated.append(usage)
            }

            currentWindowStart = windowEnd
        }

        return aggregated
    }

    /// Calculate total usage for the current 5-hour window
    public func getCurrentWindowUsage(_ entries: [ClaudeUsageEntry], tier: AccountTier = .custom, p90Limit: Int? = nil) -> TokenUsage {
        let now = Date()
        let fiveHoursAgo = now.addingTimeInterval(-5 * 3600)

        let recentEntries = entries.filter { $0.timestamp >= fiveHoursAgo }

        let totalInput = recentEntries.reduce(0) { $0 + $1.inputTokens }
        let totalOutput = recentEntries.reduce(0) { $0 + $1.outputTokens }
        let totalTokens = totalInput + totalOutput

        let modelCounts = Dictionary(grouping: recentEntries, by: { $0.modelType })
        let mostUsedModel = modelCounts.max { $0.value.count < $1.value.count }?.key

        // The window end should be 5 hours from the OLDEST token in the current window
        // This is when those tokens will expire from the rolling window
        let actualWindowStart: Date
        let actualWindowEnd: Date

        if let oldestEntry = recentEntries.min(by: { $0.timestamp < $1.timestamp }) {
            // Window resets 5 hours after the oldest token
            actualWindowStart = oldestEntry.timestamp
            actualWindowEnd = oldestEntry.timestamp.addingTimeInterval(5 * 3600)
        } else {
            // No entries, use default window
            actualWindowStart = fiveHoursAgo
            actualWindowEnd = now
        }

        // Determine max tokens based on tier
        let maxTokens: Int
        if tier == .custom, let p90 = p90Limit {
            maxTokens = p90
        } else if tier == .custom {
            maxTokens = 88_000 // Default to Max5 level for custom
        } else {
            maxTokens = tier.maxTokensPer5Hours
        }

        return TokenUsage(
            timestamp: now,
            tokensUsed: totalTokens,
            windowStart: actualWindowStart,
            windowEnd: actualWindowEnd,
            maxTokens: maxTokens,
            tier: tier,
            modelType: mostUsedModel
        )
    }
}

// MARK: - Data Models

/// Entry from Claude Code JSONL file
private struct ClaudeJSONLEntry: Codable {
    let uuid: String?
    let sessionId: String?
    let timestamp: String?
    let message: ClaudeMessage?

    enum CodingKeys: String, CodingKey {
        case uuid
        case sessionId
        case timestamp
        case message
    }

    var parsedTimestamp: Date? {
        guard let timestamp = timestamp else { return nil }

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        if let date = formatter.date(from: timestamp) {
            return date
        }

        // Try without fractional seconds
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: timestamp)
    }
}

/// Message data from Claude Code entry
private struct ClaudeMessage: Codable {
    let model: String?
    let usage: ClaudeUsageData?
}

/// Usage data from a Claude Code entry
private struct ClaudeUsageData: Codable {
    let inputTokens: Int?
    let outputTokens: Int?
    let cacheCreationInputTokens: Int?
    let cacheReadInputTokens: Int?

    enum CodingKeys: String, CodingKey {
        case inputTokens = "input_tokens"
        case outputTokens = "output_tokens"
        case cacheCreationInputTokens = "cache_creation_input_tokens"
        case cacheReadInputTokens = "cache_read_input_tokens"
    }
}

/// Parsed usage entry from Claude Code
public struct ClaudeUsageEntry {
    public let timestamp: Date
    public let sessionId: String
    public let inputTokens: Int
    public let outputTokens: Int
    public let cacheCreationTokens: Int
    public let cacheReadTokens: Int
    public let modelType: ModelType?

    public var totalTokens: Int {
        inputTokens + outputTokens
    }
}

/// Errors that can occur when reading Claude Code data
public enum ClaudeDataError: LocalizedError {
    case projectsDirectoryNotFound
    case noDataFound
    case parsingError(String)

    public var errorDescription: String? {
        switch self {
        case .projectsDirectoryNotFound:
            return "Claude Code projects directory not found at ~/.claude/projects"
        case .noDataFound:
            return "No Claude Code usage data found. Make sure you've used Claude Code recently."
        case .parsingError(let message):
            return "Error parsing data: \(message)"
        }
    }
}

// MARK: - ModelType Extension

extension ModelType {
    static func fromString(_ string: String) -> ModelType? {
        let lowercase = string.lowercased()
        if lowercase.contains("opus") {
            return .opus
        } else if lowercase.contains("sonnet") {
            // Check for 3.5 or 35 in the name
            if lowercase.contains("3.5") || lowercase.contains("3-5") || lowercase.contains("35") {
                return .sonnet35
            }
            return .sonnet
        } else if lowercase.contains("haiku") {
            return .haiku
        }
        return .sonnet35 // Default to sonnet 3.5 if unknown
    }
}
