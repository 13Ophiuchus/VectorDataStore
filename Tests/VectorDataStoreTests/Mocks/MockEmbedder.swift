//
//  MockEmbedder.swift
//  VectorDataStore
//
//  Created by Nicholas Reich on 10/24/25.
//


import Foundation
@testable import VectorDataStore

/// Deterministic mock embedder for testing
/// Provides controlled, predictable embeddings for test scenarios
actor MockEmbedder: EmbeddingModel {
    typealias Vector = [Float]
    
    private let dimension: Int
    private var embeddings: [String: [Float]] = [:]
    private var callCount = 0
    
    init(dimension: Int = 384) {
        self.dimension = dimension
    }
    
    /// Configure predefined embedding for a specific text
    func setEmbedding(_ text: String, vector: [Float]) {
        precondition(vector.count == dimension, "Vector dimension mismatch")
        embeddings[text] = vector
    }
    
    /// Get number of times embed was called (for verification)
    func getCallCount() -> Int {
        return callCount
    }
    
    /// Reset call counter
    func resetCallCount() {
        callCount = 0
    }
    
    func embed(texts: [String]) async throws -> [[Float]] {
        callCount += 1
        
        return texts.map { text in
            if let embedding = embeddings[text] {
                return embedding
            }
            // Return deterministic zero vector for unknown texts
            return Array(repeating: Float(0.0), count: dimension)
        }
    }
}
