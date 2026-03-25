import Foundation

public class PredictionEngine {
    private var usagePatterns: [UsagePattern] = []
    private let calendar = Calendar.current
    
    public init() {
        loadPatterns()
    }
    
    public func predict(currentUsage: TokenUsage, history: [TokenUsage]) -> Prediction {
        let burnRate = calculateBurnRate(from: history)
        let remainingTime = currentUsage.timeUntilReset
        let remainingTokens = currentUsage.tokensRemaining
        
        let projectedUsage = calculateProjectedUsage(
            current: currentUsage.tokensUsed,
            burnRate: burnRate,
            remainingTime: remainingTime
        )
        
        let timeToLimit = calculateTimeToLimit(
            remainingTokens: remainingTokens,
            burnRate: burnRate
        )
        
        let safeRate = calculateSafeRate(
            remainingTokens: remainingTokens,
            remainingTime: remainingTime
        )
        
        let confidence = calculateConfidence(history: history)
        
        let recommendation = generateRecommendation(
            currentUsage: currentUsage,
            projectedUsage: projectedUsage,
            burnRate: burnRate,
            safeRate: safeRate
        )
        
        analyzePatterns(from: history)
        
        return Prediction(
            projectedUsage: projectedUsage,
            timeToLimit: timeToLimit,
            confidence: confidence,
            recommendation: recommendation,
            burnRate: burnRate,
            safeRate: safeRate,
            windowEnd: currentUsage.windowEnd
        )
    }
    
    private func calculateBurnRate(from history: [TokenUsage]) -> Double {
        guard history.count >= 2 else { return 0 }
        
        let recentHistory = Array(history.suffix(10))
        guard let first = recentHistory.first,
              let last = recentHistory.last else { return 0 }
        
        let tokenDiff = last.tokensUsed - first.tokensUsed
        let timeDiff = last.timestamp.timeIntervalSince(first.timestamp) / 60
        
        return timeDiff > 0 ? Double(tokenDiff) / timeDiff : 0
    }
    
    private func calculateProjectedUsage(current: Int, burnRate: Double, remainingTime: TimeInterval) -> Int {
        let remainingMinutes = remainingTime / 60
        let projectedAdditional = Int(burnRate * remainingMinutes)
        return current + projectedAdditional
    }
    
    private func calculateTimeToLimit(remainingTokens: Int, burnRate: Double) -> TimeInterval? {
        guard burnRate > 0 else { return nil }
        
        let minutesToLimit = Double(remainingTokens) / burnRate
        return minutesToLimit > 0 ? minutesToLimit * 60 : nil
    }
    
    private func calculateSafeRate(remainingTokens: Int, remainingTime: TimeInterval) -> Double {
        let remainingMinutes = remainingTime / 60
        guard remainingMinutes > 0 else { return 0 }
        
        return Double(remainingTokens) / remainingMinutes * 0.8
    }
    
    private func calculateConfidence(history: [TokenUsage]) -> Double {
        guard history.count >= 5 else {
            return 0.5
        }
        
        let recentHistory = Array(history.suffix(20))
        var burnRates: [Double] = []
        
        for i in 1..<recentHistory.count {
            let tokenDiff = recentHistory[i].tokensUsed - recentHistory[i-1].tokensUsed
            let timeDiff = recentHistory[i].timestamp.timeIntervalSince(recentHistory[i-1].timestamp) / 60
            if timeDiff > 0 {
                burnRates.append(Double(tokenDiff) / timeDiff)
            }
        }
        
        guard !burnRates.isEmpty else { return 0.5 }
        
        let mean = burnRates.reduce(0, +) / Double(burnRates.count)
        let variance = burnRates.map { pow($0 - mean, 2) }.reduce(0, +) / Double(burnRates.count)
        let standardDeviation = sqrt(variance)
        let coefficientOfVariation = mean != 0 ? standardDeviation / abs(mean) : 1.0
        
        let baseConfidence = 1.0 / (1.0 + coefficientOfVariation)
        
        let sampleSizeBonus = min(0.2, Double(history.count) / 100.0)
        
        return min(0.95, baseConfidence + sampleSizeBonus)
    }
    
    private func generateRecommendation(
        currentUsage: TokenUsage,
        projectedUsage: Int,
        burnRate: Double,
        safeRate: Double
    ) -> String {
        let percentProjected = Double(projectedUsage) / Double(currentUsage.maxTokens)
        
        if percentProjected < 0.7 {
            return "Current usage rate is sustainable. You're on track to stay well within limits."
        } else if percentProjected < 0.85 {
            if burnRate > safeRate * 1.2 {
                return "Consider reducing usage slightly. Current rate: \(Int(burnRate)) tokens/min, recommended: \(Int(safeRate)) tokens/min."
            } else {
                return "Usage is moderate. Monitor closely as you approach the limit."
            }
        } else if percentProjected < 1.0 {
            let reduction = Int((burnRate - safeRate) / burnRate * 100)
            return "High usage detected! Reduce consumption by \(reduction)% to avoid hitting the limit."
        } else {
            if let pattern = findOptimalTimeSlot() {
                return "Critical: You will exceed the limit at current rate. Best time to resume: \(pattern.hourFormatted)"
            } else {
                return "Critical: Immediate reduction required! You're on track to exceed the token limit."
            }
        }
    }
    
    private func analyzePatterns(from history: [TokenUsage]) {
        var patterns: [String: UsagePattern] = [:]
        
        for usage in history {
            let hour = calendar.component(.hour, from: usage.timestamp)
            let weekday = calendar.component(.weekday, from: usage.timestamp)
            let key = "\(weekday)-\(hour)"
            
            if let existing = patterns[key] {
                let newAverage = (existing.averageUsage * Double(existing.sampleCount) + Double(usage.tokensUsed)) / Double(existing.sampleCount + 1)
                let newPeak = max(existing.peakUsage, usage.tokensUsed)
                
                patterns[key] = UsagePattern(
                    hourOfDay: hour,
                    dayOfWeek: weekday,
                    averageUsage: newAverage,
                    peakUsage: newPeak,
                    sampleCount: existing.sampleCount + 1
                )
            } else {
                patterns[key] = UsagePattern(
                    hourOfDay: hour,
                    dayOfWeek: weekday,
                    averageUsage: Double(usage.tokensUsed),
                    peakUsage: usage.tokensUsed,
                    sampleCount: 1
                )
            }
        }
        
        usagePatterns = Array(patterns.values)
        savePatterns()
    }
    
    private func findOptimalTimeSlot() -> UsagePattern? {
        return usagePatterns
            .filter { $0.sampleCount >= 3 }
            .sorted { $0.averageUsage < $1.averageUsage }
            .first
    }
    
    public func predictBestUsageTimes() -> [UsagePattern] {
        return usagePatterns
            .filter { $0.sampleCount >= 3 }
            .sorted { $0.averageUsage < $1.averageUsage }
            .prefix(5)
            .map { $0 }
    }
    
    private func loadPatterns() {
        if let data = UserDefaults.standard.data(forKey: "usagePatterns"),
           let patterns = try? JSONDecoder().decode([UsagePattern].self, from: data) {
            usagePatterns = patterns
        }
    }
    
    private func savePatterns() {
        if let data = try? JSONEncoder().encode(usagePatterns) {
            UserDefaults.standard.set(data, forKey: "usagePatterns")
        }
    }
    
    public func anomalyScore(for usage: TokenUsage) -> Double {
        let hour = calendar.component(.hour, from: usage.timestamp)
        let weekday = calendar.component(.weekday, from: usage.timestamp)
        
        guard let pattern = usagePatterns.first(where: {
            $0.hourOfDay == hour && $0.dayOfWeek == weekday && $0.sampleCount >= 3
        }) else {
            return 0.5
        }
        
        let deviation = abs(Double(usage.tokensUsed) - pattern.averageUsage)
        let normalizedDeviation = pattern.averageUsage > 0 ? deviation / pattern.averageUsage : 0
        
        return min(1.0, normalizedDeviation)
    }
}