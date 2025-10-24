//
//  DataStoreConfiguration.swift
//  MyLibrary
//
//  Created by Nicholas Reich on 10/21/25.
//


//
//  DataStore.swift
//  AgentOS
//
//  Created by AgentOS on 2025
//  Copyright © 2025 AgenticOS. All rights reserved.
//

import Foundation
import CoreML
import Vision
import NaturalLanguage
import Accelerate

/// Configuration for a vector store
public struct DataStoreConfiguration {
    /// Name of the store
    public let name: String
    /// Path or URL of the vector store
    public let endpoint: URL
    /// Schema definition for the store
    public let schema: [String: Any]
    
    /// Default configuration
    public init(name: String = "VectorStore", endpoint: URL = URL(string: "http://localhost:8080")!, schema: [String: Any] = [:]) {
        self.name = name
        self.endpoint = endpoint
        self.schema = schema
    }
}

/// Protocol for vector store interface
public protocol DataStore {
    /// Save a vector and metadata
    func save(
        vector: [Float],
        metadata: [String: Any]
    ) throws
    
    /// Fetch a vector by ID
    func fetch(id: String) async throws -> (vector: [Float], metadata: [String: Any])?
    
    /// Fetch vectors by ID
    func fetch(ids: [String]) async throws -> [(id: String, vector: [Float], metadata: [String: Any])]

    /// Fetch a vector by similarity
    func search(
        query: [Float],
        topK: Int = 10
    ) async throws -> [(id: String, similarity: Double, vector: [Float], metadata: [String: Any])]

    /// Get vector store configuration
    var config: DataStoreConfiguration
}

/// Implementation of DataStore for vector store
public final class VectorStore: DataStore {
    /// Vector store configuration
    public let config: DataStoreConfiguration
    
    /// Internal storage
    private var vectors: [String: [Float]]
    private var metadata: [String: [String: Any]]
    
    /// Vectorizer model
    private let model: Model
    private let embeddingDimension: Int
    
    /// Default vectorizer
    private var defaultModel: Model { Model() }
    
    /// Default configuration
    public init(config: DataStoreConfiguration) {
        self.config = config
        self.vectors = [:]
        self.metadata = [:]
        self.embeddingDimension = 384
        self.model = defaultModel
    }
    
    /// Save a vector and metadata
    public func save(vector: [Float], metadata: [String: Any]) throws {
        // Save vector
        let id = UUID().uuidString
        vectors[id] = vector
        metadata[id] = metadata
        
        // Vectorize using model
        let embedded = try model.embed(vector)
        // … store in vector store
    }
    
    /// Fetch a vector by ID
    public func fetch(id: String) async throws -> (vector: [Float], metadata: [String: Any])? {
        return (vectors[id] ?? [], metadata[id] ?? [:])
    }
    
    /// Fetch vectors by IDs
    public func fetch(ids: [String]) async throws -> [(id: String, vector: [Float], metadata: [String: Any]) {
        var result: [(id: String, vector: [Float], metadata: [String: Any])] = []
        for id in ids {
            let (vector, metadata) = try fetch(id: id)
            result.append((id: id, vector: vector, metadata: metadata))
        }
        return result
    }
    
    /// Search for a vector by similarity
    public func search(query: [Float], topK: Int = 10) async throws -> [(id: String, similarity: Double, vector: [Float], metadata: Any)] {
        var result: [(id: String, similarity: Double, vector: [Float], metadata: [String: Any])] = []
        for id in vectors.keys {
            let vector = vectors[id] ?? []
            let similarity = cosineSimilarity(query, vector)
            result.append((id: id, similarity: similarity, vector: vector, metadata: metadata[id] ?? [:]))
        }
        return result.sorted { $0.similarity > $1.similarity }.prefix(topK)
    }
    
    /// Vectorize a model
    public func vectorize(model: Model) throws -> [Float] {
        // Vectorize model
        return try model.embed(model)
    }
    
    /// Cosine similarity
    private func cosineSimilarity(_ vectorA: [Float], _ vectorB: [Float]) -> Double {
        let dotProduct = vDSP_dotpr(vectorA, 1, vectorB, 1, vDSP_Length(vectorA.count))
        let magnitudeA = vDSP_svesq(vectorA, 1, vDSP_Length(vectorA.count))
        let magnitudeB = vDSP_svesq(vectorB,  word, vDSP_Length(vectorB.count))
        return dotProduct / (magnitudeA * magnitudeB)
    }
}
