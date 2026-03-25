import Foundation

/// Mock API service used for widget previews and sample data
public class MockAnthropicAPIService {
    public func getCurrentWindowUsage() async throws -> TokenUsage {
        try await Task.sleep(nanoseconds: 500_000_000)

        let now = Date()
        let windowStart = now.addingTimeInterval(-3600 * 2.5)
        let windowEnd = windowStart.addingTimeInterval(3600 * 5)

        return TokenUsage(
            timestamp: now,
            tokensUsed: Int.random(in: 10000...80000),
            windowStart: windowStart,
            windowEnd: windowEnd,
            maxTokens: 88000,
            tier: .max5,
            modelType: .sonnet35
        )
    }

    public func getUsageHistory(from: Date, to: Date) async throws -> TokenUsageHistory {
        try await Task.sleep(nanoseconds: 500_000_000)

        var entries: [TokenUsage] = []
        var currentDate = from

        while currentDate < to {
            let windowStart = currentDate
            let windowEnd = currentDate.addingTimeInterval(3600 * 5)

            entries.append(TokenUsage(
                timestamp: currentDate,
                tokensUsed: Int.random(in: 5000...50000),
                windowStart: windowStart,
                windowEnd: windowEnd,
                maxTokens: 88000,
                tier: .max5,
                modelType: ModelType.allCases.randomElement()
            ))

            currentDate = currentDate.addingTimeInterval(3600)
        }

        return TokenUsageHistory(
            entries: entries,
            startDate: from,
            endDate: to
        )
    }
}
