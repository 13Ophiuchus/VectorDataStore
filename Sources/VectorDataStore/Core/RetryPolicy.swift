//
//  RetryPolicy.swift
//  VectorDataStore
//
//  Created by Nicholas Reich on 10/24/25.
//
import SwiftData
imp
// MARK: - Retry Logic Helper --------------------------------------------------

/// Retry policy for network operations
public actor RetryPolicy {
    public let maxAttempts: Int
    public let baseDelay: TimeInterval
    public let maxDelay: TimeInterval
    
    public init(maxAttempts: Int = 3, baseDelay: TimeInterval = 1.0, maxDelay: TimeInterval = 30.0) {
        self.maxAttempts = maxAttempts
        self.baseDelay = baseDelay
        self.maxDelay = maxDelay
    }
    
    /// Execute operation with exponential backoff retry
    public func execute<T>(_ operation: @Sendable () async throws -> T) async throws -> T {
        var lastError: Error?
        
        for attempt in 1...maxAttempts {
            do {
                return try await operation()
            } catch {
                lastError = error
                
                // Check if we should retry
                guard attempt < maxAttempts, shouldRetry(error) else {
                    throw error
                }
                
                // Calculate delay with exponential backoff
                let delay = min(baseDelay * pow(2.0, Double(attempt - 1)), maxDelay)
                
                // Add jitter (random 0-20% of delay)
                let jitter = delay * Double.random(in: 0...0.2)
                let totalDelay = delay + jitter
                
                try await Task.sleep(nanoseconds: UInt64(totalDelay * 1_000_000_000))
            }
        }
        
        throw lastError ?? NSError(domain: "RetryPolicy", code: -1, userInfo: [
            NSLocalizedDescriptionKey: "All retry attempts failed"
        ])
    }
    
    /// Determine if error is retryable
    private func shouldRetry(_ error: Error) -> Bool {
        // Retry on network errors, timeouts, rate limits
        if let urlError = error as? URLError {
            switch urlError.code {
            case .timedOut, .cannotConnectToHost, .networkConnectionLost, .notConnectedToInternet:
                return true
            default:
                return false
            }
        }
        
        // Retry on specific HTTP status codes
        if let httpError = error as? HTTPError {
            switch httpError.statusCode {
            case 408, 429, 500, 502, 503, 504: // Timeout, Rate Limit, Server Errors
                return true
            default:
                return false
            }
        }
        
        return false
    }
}

struct HTTPError: Error {
    let statusCode: Int
}
