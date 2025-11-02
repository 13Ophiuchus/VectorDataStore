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
    Model: PersistentModel,
    Backend: VectorDBBackend,
    Embedder: EmbeddingModel
> where Backend.Vector == Vector, Embedder.Vector == Vector {

    public let config: DataStoreConfiguration<Vector>
	private let embedder: Embedder
	internal let backend: Backend

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
        let models = request.snapshots.map(\.model)

        // Build texts in order and embed
		let texts = models.map(\.embeddingText)
        let vectors: [Vector] = try await embedder.embed(texts: texts)

        // Zip vectors with models by index to avoid Equatable requirement
        let payloads: [VectorPayload<Vector>] = zip(vectors, models).map { vector, model in
            VectorPayload(vector: vector,
                          metadata: Self.metadataRepresentation(for: model))
        }
        try await backend.upsert(payloads)
    }

    /// Semantic search.
	public func execute(_ request: DataStoreFetchRequest<Model>) async throws -> [Model] {
        // Map the new fetch request to the backend’s search call if semanticQuery is provided
        guard let query = request.semanticQuery else {
            // If no semantic query, fall back to metadata-only fetch
            let all = try await backend.fetchAll()
            // Apply simple predicate filtering client-side (basic support)
            let filtered = try Self.applyPredicate(request.predicate, to: all)
            // Apply limit
            let limited = request.fetchLimit.map { Array(filtered.prefix($0)) } ?? filtered
            return limited.compactMap(Model.init(metadata:))
        }

        let queryVector: Vector = try await embedder.embed(texts: [query])[0]
        let matches = try await backend.search(vector: queryVector,
                                               topK: request.fetchLimit ?? 10,
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
