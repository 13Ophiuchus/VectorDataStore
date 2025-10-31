//
//  VectorDataStore.swift
//  VectorDataStore
//
//  Created by Nicholas Reich on 10/23/25.
//

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
