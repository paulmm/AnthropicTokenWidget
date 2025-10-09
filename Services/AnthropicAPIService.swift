import Foundation
import Combine

public enum APIError: LocalizedError {
    case invalidURL
    case invalidResponse
    case unauthorized
    case rateLimited(retryAfter: TimeInterval)
    case networkError(Error)
    case decodingError(Error)
    case unknown
    
    public var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid API URL"
        case .invalidResponse:
            return "Invalid response from server"
        case .unauthorized:
            return "Unauthorized - Please check your API key"
        case .rateLimited(let retryAfter):
            return "Rate limited. Retry after \(Int(retryAfter)) seconds"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .decodingError(let error):
            return "Data decoding error: \(error.localizedDescription)"
        case .unknown:
            return "An unknown error occurred"
        }
    }
}

public protocol AnthropicAPIServiceProtocol {
    func getCurrentWindowUsage() async throws -> TokenUsage
    func getUsageHistory(from: Date, to: Date) async throws -> TokenUsageHistory
    func validateAPIKey(_ apiKey: String) async throws -> Bool
}

public class AnthropicAPIService: ObservableObject, AnthropicAPIServiceProtocol {
    @Published public var isLoading = false
    @Published public var lastError: APIError?
    
    private let baseURL = "https://api.anthropic.com/v1"
    private let session: URLSession
    private var apiKey: String?
    private var cancellables = Set<AnyCancellable>()
    
    public init(apiKey: String? = nil) {
        self.apiKey = apiKey
        
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 60
        configuration.waitsForConnectivity = true
        
        self.session = URLSession(configuration: configuration)
    }
    
    public func updateAPIKey(_ key: String) {
        self.apiKey = key
    }
    
    public func getCurrentWindowUsage() async throws -> TokenUsage {
        guard let apiKey = apiKey else {
            throw APIError.unauthorized
        }
        
        let endpoint = "\(baseURL)/usage/current"
        guard let url = URL(string: endpoint) else {
            throw APIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        
        do {
            let (data, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIError.invalidResponse
            }
            
            switch httpResponse.statusCode {
            case 200:
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                let usageResponse = try decoder.decode(UsageResponse.self, from: data)
                return usageResponse.toTokenUsage()
            case 401:
                throw APIError.unauthorized
            case 429:
                let retryAfter = httpResponse.value(forHTTPHeaderField: "Retry-After")
                    .flatMap { Double($0) } ?? 60
                throw APIError.rateLimited(retryAfter: retryAfter)
            default:
                throw APIError.unknown
            }
        } catch let error as APIError {
            throw error
        } catch let error as DecodingError {
            throw APIError.decodingError(error)
        } catch {
            throw APIError.networkError(error)
        }
    }
    
    public func getUsageHistory(from startDate: Date, to endDate: Date) async throws -> TokenUsageHistory {
        guard let apiKey = apiKey else {
            throw APIError.unauthorized
        }
        
        let formatter = ISO8601DateFormatter()
        let fromStr = formatter.string(from: startDate)
        let toStr = formatter.string(from: endDate)
        
        let endpoint = "\(baseURL)/usage/history?from=\(fromStr)&to=\(toStr)"
        guard let url = URL(string: endpoint) else {
            throw APIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        
        do {
            let (data, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIError.invalidResponse
            }
            
            switch httpResponse.statusCode {
            case 200:
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                let historyResponse = try decoder.decode(UsageHistoryResponse.self, from: data)
                return historyResponse.toTokenUsageHistory()
            case 401:
                throw APIError.unauthorized
            case 429:
                let retryAfter = httpResponse.value(forHTTPHeaderField: "Retry-After")
                    .flatMap { Double($0) } ?? 60
                throw APIError.rateLimited(retryAfter: retryAfter)
            default:
                throw APIError.unknown
            }
        } catch let error as APIError {
            throw error
        } catch let error as DecodingError {
            throw APIError.decodingError(error)
        } catch {
            throw APIError.networkError(error)
        }
    }
    
    public func validateAPIKey(_ apiKey: String) async throws -> Bool {
        let tempService = AnthropicAPIService(apiKey: apiKey)
        do {
            _ = try await tempService.getCurrentWindowUsage()
            return true
        } catch APIError.unauthorized {
            return false
        }
    }
}

private struct UsageResponse: Codable {
    let timestamp: Date
    let tokensUsed: Int
    let windowStart: Date
    let windowEnd: Date
    let maxTokens: Int
    let tier: String
    let modelType: String?
    
    func toTokenUsage() -> TokenUsage {
        return TokenUsage(
            timestamp: timestamp,
            tokensUsed: tokensUsed,
            windowStart: windowStart,
            windowEnd: windowEnd,
            maxTokens: maxTokens,
            tier: AccountTier(rawValue: tier.lowercased()) ?? .pro,
            modelType: modelType.flatMap { ModelType(rawValue: $0) }
        )
    }
}

private struct UsageHistoryResponse: Codable {
    let entries: [UsageResponse]
    let startDate: Date
    let endDate: Date
    
    func toTokenUsageHistory() -> TokenUsageHistory {
        let tokenUsages = entries.map { $0.toTokenUsage() }
        return TokenUsageHistory(
            entries: tokenUsages,
            startDate: startDate,
            endDate: endDate
        )
    }
}

public class MockAnthropicAPIService: AnthropicAPIServiceProtocol {
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
    
    public func validateAPIKey(_ apiKey: String) async throws -> Bool {
        try await Task.sleep(nanoseconds: 500_000_000)
        return apiKey.count > 10
    }
}