import Foundation

public enum AccountTier: String, Codable, CaseIterable {
    case free = "free"
    case tier1 = "tier1"
    case tier2 = "tier2"
    case tier3 = "tier3"
    case tier4 = "tier4"
    case scale = "scale"
    
    var maxTokensPer5Hours: Int {
        switch self {
        case .free:
            return 25_000
        case .tier1:
            return 50_000
        case .tier2:
            return 100_000
        case .tier3:
            return 200_000
        case .tier4:
            return 400_000
        case .scale:
            return 800_000
        }
    }
    
    var displayName: String {
        switch self {
        case .free:
            return "Free"
        case .tier1:
            return "Tier 1"
        case .tier2:
            return "Tier 2"
        case .tier3:
            return "Tier 3"
        case .tier4:
            return "Tier 4"
        case .scale:
            return "Scale"
        }
    }
}

public enum ModelType: String, Codable, CaseIterable {
    case opus = "claude-3-opus"
    case sonnet = "claude-3-sonnet"
    case haiku = "claude-3-haiku"
    case sonnet35 = "claude-3.5-sonnet"
    
    var displayName: String {
        switch self {
        case .opus:
            return "Opus"
        case .sonnet:
            return "Sonnet"
        case .haiku:
            return "Haiku"
        case .sonnet35:
            return "Sonnet 3.5"
        }
    }
    
    var color: String {
        switch self {
        case .opus:
            return "#8B5CF6"
        case .sonnet:
            return "#3B82F6"
        case .haiku:
            return "#10B981"
        case .sonnet35:
            return "#F59E0B"
        }
    }
}

public struct TokenUsage: Codable, Identifiable {
    public let id: UUID
    public let timestamp: Date
    public let tokensUsed: Int
    public let windowStart: Date
    public let windowEnd: Date
    public let maxTokens: Int
    public let tier: AccountTier
    public let modelType: ModelType?
    public let tokensRemaining: Int
    public let percentageUsed: Double
    
    public init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        tokensUsed: Int,
        windowStart: Date,
        windowEnd: Date,
        maxTokens: Int,
        tier: AccountTier,
        modelType: ModelType? = nil
    ) {
        self.id = id
        self.timestamp = timestamp
        self.tokensUsed = tokensUsed
        self.windowStart = windowStart
        self.windowEnd = windowEnd
        self.maxTokens = maxTokens
        self.tier = tier
        self.modelType = modelType
        self.tokensRemaining = max(0, maxTokens - tokensUsed)
        self.percentageUsed = maxTokens > 0 ? Double(tokensUsed) / Double(maxTokens) : 0
    }
    
    var timeUntilReset: TimeInterval {
        return windowEnd.timeIntervalSince(Date())
    }
    
    var isNearLimit: Bool {
        return percentageUsed >= 0.75
    }
    
    var isCritical: Bool {
        return percentageUsed >= 0.90
    }
    
    var usageColor: String {
        switch percentageUsed {
        case 0..<0.60:
            return "#10B981"
        case 0.60..<0.85:
            return "#F59E0B"
        default:
            return "#EF4444"
        }
    }
}

public struct TokenUsageHistory: Codable {
    public let entries: [TokenUsage]
    public let startDate: Date
    public let endDate: Date
    
    public init(entries: [TokenUsage], startDate: Date, endDate: Date) {
        self.entries = entries
        self.startDate = startDate
        self.endDate = endDate
    }
    
    public var totalTokensUsed: Int {
        entries.reduce(0) { $0 + $1.tokensUsed }
    }
    
    public var averageUsagePerHour: Double {
        let hours = endDate.timeIntervalSince(startDate) / 3600
        return hours > 0 ? Double(totalTokensUsed) / hours : 0
    }
    
    public func usageByModel() -> [ModelType: Int] {
        var usage: [ModelType: Int] = [:]
        for entry in entries {
            if let model = entry.modelType {
                usage[model, default: 0] += entry.tokensUsed
            }
        }
        return usage
    }
}