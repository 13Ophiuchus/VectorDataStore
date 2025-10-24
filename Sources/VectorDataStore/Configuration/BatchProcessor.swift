//
//  BatchProcessor.swift
//  VectorDataStore
//
//  Created by Nicholas Reich on 10/24/25.
//


/ MARK: - Batch Size Limiter --------------------------------------------------

/// Helper to batch large operations
public struct BatchProcessor {
    public let batchSize: Int
    
    public init(batchSize: Int = 100) {
        self.batchSize = batchSize
    }
    
    /// Process items in batches
    public func process<T, R>(
        items: [T],
        operation: ([T]) async throws -> R
    ) async throws -> [R] {
        var results: [R] = []
        
        for batch in items.chunked(into: batchSize) {
            let result = try await operation(batch)
            results.append(result)
        }
        
        return results
    }
}

extension Array {
    /// Split array into chunks of specified size
    func chunked(into size: Int) -> [[Element]] {
        stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}
