import Foundation

public struct Prediction: Codable, Identifiable {
    public let id: UUID
    public let timestamp: Date
    public let projectedUsage: Int
    public let timeToLimit: TimeInterval?
    public let confidence: Double
    public let recommendation: String
    public let burnRate: Double
    public let safeRate: Double
    public let windowEnd: Date
    
    public init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        projectedUsage: Int,
        timeToLimit: TimeInterval?,
        confidence: Double,
        recommendation: String,
        burnRate: Double,
        safeRate: Double,
        windowEnd: Date
    ) {
        self.id = id
        self.timestamp = timestamp
        self.projectedUsage = projectedUsage
        self.timeToLimit = timeToLimit
        self.confidence = confidence
        self.recommendation = recommendation
        self.burnRate = burnRate
        self.safeRate = safeRate
        self.windowEnd = windowEnd
    }
    
    public var timeToLimitFormatted: String {
        guard let timeToLimit = timeToLimit else {
            return "Safe"
        }
        
        let hours = Int(timeToLimit) / 3600
        let minutes = Int(timeToLimit) % 3600 / 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
    
    public var confidenceLevel: ConfidenceLevel {
        switch confidence {
        case 0.8...1.0:
            return .high
        case 0.5..<0.8:
            return .medium
        default:
            return .low
        }
    }
    
    public var burnRateFormatted: String {
        return String(format: "%.0f tokens/min", burnRate)
    }
    
    public var safeRateFormatted: String {
        return String(format: "%.0f tokens/min", safeRate)
    }
}

public enum ConfidenceLevel: String, CaseIterable {
    case high = "High"
    case medium = "Medium"
    case low = "Low"
    
    public var color: String {
        switch self {
        case .high:
            return "#10B981"
        case .medium:
            return "#F59E0B"
        case .low:
            return "#EF4444"
        }
    }
}

public struct UsagePattern: Codable {
    public let hourOfDay: Int
    public let dayOfWeek: Int
    public let averageUsage: Double
    public let peakUsage: Int
    public let sampleCount: Int
    
    public init(
        hourOfDay: Int,
        dayOfWeek: Int,
        averageUsage: Double,
        peakUsage: Int,
        sampleCount: Int
    ) {
        self.hourOfDay = hourOfDay
        self.dayOfWeek = dayOfWeek
        self.averageUsage = averageUsage
        self.peakUsage = peakUsage
        self.sampleCount = sampleCount
    }
    
    public var dayName: String {
        let formatter = DateFormatter()
        return formatter.weekdaySymbols[dayOfWeek - 1]
    }
    
    public var hourFormatted: String {
        let hour12 = hourOfDay == 0 ? 12 : (hourOfDay > 12 ? hourOfDay - 12 : hourOfDay)
        let period = hourOfDay < 12 ? "AM" : "PM"
        return "\(hour12) \(period)"
    }
}