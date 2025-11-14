//
//  EmbeddingModel.swift
//  VectorDataStore
//
//  Created by Nicholas Reich on 10/21/25.
//
// 

import Foundation

// MARK: - Embedding contract --------------------------------------------------

/// A tiny abstraction over any sentence-transformer or LLM embedding service.
/// Conform your remote (OpenAI, Cohere, …) or local model to this.
public protocol EmbeddingModel: Sendable {
    associatedtype Vector: VectorProtocol
    func embed(texts: [String]) async throws -> [Vector]
}



//// MARK: - Configuration -------------------------------------------------------
//
/// Immutable value describing *where* and *how* the store lives.
public struct DataStoreConfiguration<Vector: VectorProtocol>: Sendable {
    public let storeName: String
    public let schema: Schema
    public let endpoint: URL?          // e.g. http://localhost:6333 for Qdrant
    public let apiKey: String?
    
    public struct Schema: Sendable {
        public let vectorDimensions: Int
        public let metric: Metric = .cosine   // fixed in this sample
        
        public enum Metric: String, Sendable { case cosine, dot, euclid }
    }
    
    public init(storeName: String,
                schema: Schema,
                endpoint: URL? = nil,
                apiKey: String? = nil) {
        self.storeName = storeName
        self.schema    = schema
        self.endpoint  = endpoint
        self.apiKey    = apiKey
    }
}

// MARK: - Requests ------------------------------------------------------------

/// Carries one or more models → will be converted to embeddings → stored.
public struct DataStoreSaveChangesRequest<Model: VectorModel>: Sendable {
    public let models: [Model]
    public init(_ models: [Model]) { self.models = models }
}

/// Semantic search request.
public struct DataStoreFetchRequest: Sendable {
    public let queryText: String
    public let topK: Int
    public let threshold: Float?          // optional minimum score
    public init(queryText: String, topK: Int = 10, threshold: Float? = nil) {
        self.queryText = queryText
        self.topK      = topK
        self.threshold = threshold
    }
}

// MARK: - VectorModel constraint ----------------------------------------------

/// Your document type must be able to:
/// 1. produce the text that has to be embedded
/// 2. init itself from metadata returned by the DB




//// MARK: - Backend abstraction -------------------------------------------------
//
///// You implement this for your concrete DB (Pinecone, Weaviate, Qdrant …).
///// All methods are async and can throw networking errors.
//public protocol VectorDBBackend<Vector>: Sendable {
//    associatedtype Vector: VectorProtocol
//    
//    /// Write or update vectors.
//    func upsert(_ payloads: [VectorPayload<Vector>]) async throws
//    
//    /// Nearest-neighbour search.
//    func search(vector: Vector, topK: Int, threshold: Float?) async throws -> [[String: String]]
//}



// MARK: - Model helpers -------------------------------------------------------
