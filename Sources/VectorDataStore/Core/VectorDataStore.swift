//
//  VectorDataStore.swift
//  VectorDataStore
//
//  Created by Nicholas Reich on 10/23/25.
//

import Foundation

/// Generic vector store. Thread-safe, actor-isolated.
public actor VectorDataStore<
    Vector: VectorProtocol,
    Model: PersistentVectorModel,
    Backend: VectorDBBackend,
    Embedder: EmbeddingModel
> where Backend.Vector == Vector, Embedder.Vector == Vector {

    public let config: DataStoreConfiguration<Vector>
	private let embedder: Embedder
	internal let backend: Backend

    // Security-related limits
    private let maxBatchUpsert = 1_000
    private let maxFetchLimit  = 100
    private let maxMetadataKeys = 64
    private let maxMetadataValueLength = 1024

    enum DataStoreError: Error {
        case emptyBatch
        case batchTooLarge(limit: Int)
        case vectorCountMismatch
        case invalidVectorDimensions(expected: Int, got: Int)
        case missingIDInMetadata
        case metadataTooLarge
        case invalidThreshold
    }

    public init(configuration: DataStoreConfiguration<Vector>,
				embedder: Embedder,
				backend: Backend) {
        self.config   = configuration
        self.embedder = embedder
        self.backend  = backend
    }

    /// Upsert embeddings + metadata.
    public func execute(_ request: DataStoreSaveChangesRequest<Model>) async throws {
        // Extract models from snapshots
		let models = request.snapshots.map { $0.model }

        // Security: enforce batch limits
        guard !models.isEmpty else { throw DataStoreError.emptyBatch }
        guard models.count <= maxBatchUpsert else { throw DataStoreError.batchTooLarge(limit: maxBatchUpsert) }

        // Build texts in order and embed
		let texts = models.map(\.embeddingText)
        let vectors: [Vector] = try await embedder.embed(texts: texts)

        // Validate counts
        guard vectors.count == models.count else { throw DataStoreError.vectorCountMismatch }

        // Validate vector dimensions
        let expectedDims = config.schema.vectorDimensions
        for v in vectors {
            guard v.dimensions == expectedDims else {
                throw DataStoreError.invalidVectorDimensions(expected: expectedDims, got: v.dimensions)
            }
        }

        // Zip vectors with models by index; build metadata safely
        let payloads: [VectorPayload<Vector>] = zip(vectors, models).map { vector, model in
            let raw = Self.metadataRepresentation(for: model)
            let meta = Self.sanitizedMetadata(raw,
                                              maxKeys: maxMetadataKeys,
                                              maxValueLen: maxMetadataValueLength)
            return VectorPayload(vector: vector, metadata: meta)
        }

        // Require an "id" in metadata for integrity
        guard payloads.allSatisfy({ $0.metadata["id"]?.isEmpty == false }) else {
            throw DataStoreError.missingIDInMetadata
        }

        try await backend.upsert(payloads)
    }

    /// Semantic search.
	public func execute(_ request: DataStoreFetchRequest<Model>) async throws -> [Model] {
        // Compute a safe topK
        let topK = min(request.fetchLimit ?? 10, maxFetchLimit)

        // Validate threshold (for L2 metric we accept non-negative distances)
        if let threshold = request.similarityThreshold, threshold < 0 {
            throw DataStoreError.invalidThreshold
        }

        // Map the new fetch request to the backend’s search call if semanticQuery is provided
        guard let query = request.semanticQuery else {
            // If no semantic query, fall back to metadata-only fetch
            let all = try await backend.fetchAll()
            // Apply simple predicate filtering client-side (basic support)
            let filtered = try Self.applyPredicate(request.predicate, to: all)
            // Apply limit
            let limited = Array(filtered.prefix(topK))
            return limited.compactMap(Model.init(metadata:))
        }

        // Embed the query
        let embedded = try await embedder.embed(texts: [query])
        guard let queryVector: Vector = embedded.first else {
            return []
        }

        // Validate query vector dimensions
        let expectedDims = config.schema.vectorDimensions
        guard queryVector.dimensions == expectedDims else {
            throw DataStoreError.invalidVectorDimensions(expected: expectedDims, got: queryVector.dimensions)
        }

        let matches = try await backend.search(vector: queryVector,
                                               topK: topK,
                                               threshold: request.similarityThreshold)
        return matches.compactMap(Model.init(metadata:))
    }

    // MARK: - Helpers

    // Default metadata encoding from Codable model
    private static func metadataRepresentation(for model: Model) -> [String: String] {
        guard let data = try? JSONEncoder().encode(model),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return [:]
        }
        return json.reduce(into: [String: String]()) { dict, pair in
            dict[pair.key] = String(describing: pair.value)
        }
    }

    // Sanitize metadata: cap key count and value lengths; drop non-stringifiable entries
    private static func sanitizedMetadata(_ metadata: [String: String],
                                          maxKeys: Int,
                                          maxValueLen: Int) -> [String: String] {
        var result: [String: String] = [:]
        for (k, v) in metadata.prefix(maxKeys) {
            // Truncate overly long values
            let trimmed = v.count > maxValueLen ? String(v.prefix(maxValueLen)) : v
            result[k] = trimmed
        }
        return result
    }

    private static func applyPredicate(_ predicate: Predicate?, to items: [[String: String]]) throws -> [[String: String]] {
        guard let predicate else { return items }
        switch predicate.operation {
        case .equal(let key, let value):
            return items.filter { $0[key] == value }
        case .contains(let key, let value):
            return items.filter { ($0[key] ?? "").contains(value) }
        }
    }
}
