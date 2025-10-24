//
//  EmbeddingModel.swift
//  MyLibrary
//
//  Created by Nicholas Reich on 10/21/25.
//


// VectorDataStore.swift
// Created for Swift 6 strict concurrency

import Foundation

// MARK: - Embedding contract --------------------------------------------------

/// A tiny abstraction over any sentence-transformer or LLM embedding service.
/// Conform your remote (OpenAI, Cohere, …) or local model to this.
public protocol EmbeddingModel: Sendable {
    associatedtype Vector: VectorProtocol
    func embed(texts: [String]) async throws -> [Vector]
}

/// Vector must be `Sendable` value type (e.g. `[Float]`).
public protocol VectorProtocol: Sendable {
    var dimensions: Int { get }
    func l2distance(to other: Self) -> Float
}

extension Array: VectorProtocol where Element == Float {
    public var dimensions: Int { count }
    public func l2distance(to other: Self) -> Float {
        precondition(count == other.count)
        return zip(self, other).reduce(0) { $0 + ($1.0 - $1.1) * ($1.0 - $1.1) }
    }
}

// MARK: - Configuration -------------------------------------------------------

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
public protocol VectorModel: Sendable, Identifiable where ID: StringProtocol {
    var embeddingText: String { get }
    init?(metadata: [String: String])
}

// MARK: - Store implementation ------------------------------------------------

/// Generic vector store. Thread-safe, actor-isolated.
public actor VectorDataStore<Vector: VectorProtocol, Model: VectorModel> {
    
    public let config: DataStoreConfiguration<Vector>
    private let embedder: any EmbeddingModel<Vector>
    private let backend: any VectorDBBackend<Vector>
    
    public init(configuration: DataStoreConfiguration<Vector>,
                embedder: some EmbeddingModel<Vector>,
                backend: some VectorDBBackend<Vector>) {
        self.config   = configuration
        self.embedder = embedder
        self.backend  = backend
    }
    
    /// Upsert embeddings + metadata.
    public func execute(_ request: DataStoreSaveChangesRequest<Model>) async throws {
        let texts = request.models.map(\.embeddingText)
        let vectors = try await embedder.embed(texts: texts)
        
        let payloads = request.models.map { model in
            VectorPayload(vector: vectors[request.models.firstIndex(of: model)!],
                          metadata: model.metadataRepresentation)
        }
        try await backend.upsert(payloads)
    }
    
    /// Semantic search.
    public func execute(_ request: DataStoreFetchRequest) async throws -> [Model] {
        let queryVector = try await embedder.embed(texts: [request.queryText])[0]
        let matches = try await backend.search(vector: queryVector,
                                               topK: request.topK,
                                               threshold: request.threshold)
        return matches.compactMap(Model.init(metadata:))
    }
}

// MARK: - Backend abstraction -------------------------------------------------

/// You implement this for your concrete DB (Pinecone, Weaviate, Qdrant …).
/// All methods are async and can throw networking errors.
public protocol VectorDBBackend<Vector>: Sendable {
    associatedtype Vector: VectorProtocol
    
    /// Write or update vectors.
    func upsert(_ payloads: [VectorPayload<Vector>]) async throws
    
    /// Nearest-neighbour search.
    func search(vector: Vector, topK: Int, threshold: Float?) async throws -> [[String: String]]
}

/// Convenience wrapper so the store never sees raw vectors alone.
public struct VectorPayload<Vector: VectorProtocol>: Sendable {
    public let vector: Vector
    public let metadata: [String: String]
}

// MARK: - Model helpers -------------------------------------------------------

extension VectorModel {
    /// Default mirror of Codable or custom dictionary.
    fileprivate var metadataRepresentation: [String: String] {
        let data = (try? JSONEncoder().encode(self)) ?? Data()
        let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
        return json?.compactMapValues { String(describing: $0) } ?? [:]
    }
}