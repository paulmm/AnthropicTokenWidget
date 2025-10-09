import WidgetKit
import SwiftUI

struct TachometerProvider: TimelineProvider {
    typealias Entry = TachometerEntry

    private let apiService = MockAnthropicAPIService()
    
    func placeholder(in context: Context) -> TachometerEntry {
        TachometerEntry(
            date: Date(),
            usage: sampleUsage(),
            prediction: samplePrediction()
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (TachometerEntry) -> ()) {
        if context.isPreview {
            completion(placeholder(in: context))
        } else {
            Task {
                do {
                    let usage = try await apiService.getCurrentWindowUsage()
                    let prediction = await MainActor.run { TokenUsageMonitor.shared.generatePrediction(for: usage) }
                    let entry = TachometerEntry(
                        date: Date(),
                        usage: usage,
                        prediction: prediction
                    )
                    completion(entry)
                } catch {
                    completion(placeholder(in: context))
                }
            }
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TachometerEntry>) -> ()) {
        Task {
            do {
                let usage = try await apiService.getCurrentWindowUsage()
                let prediction = await MainActor.run { TokenUsageMonitor.shared.generatePrediction(for: usage) }

                let entry = TachometerEntry(
                    date: Date(),
                    usage: usage,
                    prediction: prediction
                )

                let refreshDate = Date().addingTimeInterval(60)

                let timeline = Timeline(entries: [entry], policy: .after(refreshDate))
                completion(timeline)
            } catch {
                let entry = placeholder(in: context)
                let timeline = Timeline(entries: [entry], policy: .after(Date().addingTimeInterval(300)))
                completion(timeline)
            }
        }
    }
    
    private func sampleUsage() -> TokenUsage {
        TokenUsage(
            tokensUsed: 45000,
            windowStart: Date().addingTimeInterval(-7200),
            windowEnd: Date().addingTimeInterval(10800),
            maxTokens: 88000,
            tier: .max5,
            modelType: .sonnet35
        )
    }
    
    private func samplePrediction() -> Prediction {
        Prediction(
            projectedUsage: 65000,
            timeToLimit: 3600,
            confidence: 0.85,
            recommendation: "Current rate sustainable",
            burnRate: 250,
            safeRate: 200,
            windowEnd: Date().addingTimeInterval(10800)
        )
    }
}

struct DashboardProvider: TimelineProvider {
    typealias Entry = DashboardEntry

    private let apiService = MockAnthropicAPIService()
    
    func placeholder(in context: Context) -> DashboardEntry {
        DashboardEntry(
            date: Date(),
            usage: sampleUsage(),
            history: sampleHistory(),
            prediction: samplePrediction()
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (DashboardEntry) -> ()) {
        if context.isPreview {
            completion(placeholder(in: context))
        } else {
            Task {
                do {
                    let usage = try await apiService.getCurrentWindowUsage()
                    let history = try await apiService.getUsageHistory(
                        from: Date().addingTimeInterval(-86400),
                        to: Date()
                    )
                    let prediction = await MainActor.run { TokenUsageMonitor.shared.generatePrediction(for: usage) }

                    let entry = DashboardEntry(
                        date: Date(),
                        usage: usage,
                        history: history,
                        prediction: prediction
                    )
                    completion(entry)
                } catch {
                    completion(placeholder(in: context))
                }
            }
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<DashboardEntry>) -> ()) {
        Task {
            do {
                let usage = try await apiService.getCurrentWindowUsage()
                let history = try await apiService.getUsageHistory(
                    from: Date().addingTimeInterval(-86400),
                    to: Date()
                )
                let prediction = await MainActor.run { TokenUsageMonitor.shared.generatePrediction(for: usage) }

                let entry = DashboardEntry(
                    date: Date(),
                    usage: usage,
                    history: history,
                    prediction: prediction
                )

                let refreshDate = Date().addingTimeInterval(120)

                let timeline = Timeline(entries: [entry], policy: .after(refreshDate))
                completion(timeline)
            } catch {
                let entry = placeholder(in: context)
                let timeline = Timeline(entries: [entry], policy: .after(Date().addingTimeInterval(300)))
                completion(timeline)
            }
        }
    }
    
    private func sampleUsage() -> TokenUsage {
        TokenUsage(
            tokensUsed: 65000,
            windowStart: Date().addingTimeInterval(-10800),
            windowEnd: Date().addingTimeInterval(7200),
            maxTokens: 88000,
            tier: .max5,
            modelType: .sonnet35
        )
    }
    
    private func sampleHistory() -> TokenUsageHistory {
        var entries: [TokenUsage] = []
        for i in 0..<24 {
            let timestamp = Date().addingTimeInterval(Double(-i * 3600))
            entries.append(TokenUsage(
                timestamp: timestamp,
                tokensUsed: Int.random(in: 1000...8000),
                windowStart: timestamp.addingTimeInterval(-7200),
                windowEnd: timestamp.addingTimeInterval(10800),
                maxTokens: 88000,
                tier: .max5,
                modelType: ModelType.allCases.randomElement()
            ))
        }
        
        return TokenUsageHistory(
            entries: entries,
            startDate: Date().addingTimeInterval(-86400),
            endDate: Date()
        )
    }
    
    private func samplePrediction() -> Prediction {
        Prediction(
            projectedUsage: 85000,
            timeToLimit: 7200,
            confidence: 0.78,
            recommendation: "Consider reducing usage rate",
            burnRate: 320,
            safeRate: 250,
            windowEnd: Date().addingTimeInterval(7200)
        )
    }
}