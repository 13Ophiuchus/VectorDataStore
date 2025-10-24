//
//  File.swift
//  VectorDataStore
//
//  Created by Nicholas Reich on 10/24/25.
//
import Foundation
import SwiftData
	// MARK: - SwiftDataStyleStore -----------------------------------------------

	/// Actor that wraps the low-level `VectorDataStore` but exposes
	/// SwiftData-style request/result types.
public actor SwiftDataStyleStore<Vector: VectorProtocol, Model: PersistentModel> where Model.Vector == Vector {

	public let config: DataStoreConfiguration<Vector>
	private let vectorStore: VectorDataStore<Vector, Model>
	private var migrationPlan: (any SchemaMigrationPlan<Model>)?

	public init(configuration: DataStoreConfiguration<Vector>,
				embedder: some EmbeddingModel<Vector>,
				backend: some VectorDBBackend<Vector>,
				migrationPlan: (any SchemaMigrationPlan<Model>)? = nil) {
		self.config = configuration
		self.vectorStore = .init(configuration: configuration,
								 embedder: embedder,
								 backend: backend)
		self.migrationPlan = migrationPlan
	}

		// MARK: - Fetch

	public func execute(_ request: DataStoreFetchRequest) async throws -> DataStoreFetchResult<Model> {
			// If semantic query exists, do vector search first
		if let query = request.semanticQuery {
			let vectorReq = VectorDataStoreFetchRequest(queryText: query,
														topK: request.fetchLimit ?? 10,
														threshold: request.similarityThreshold)
			let models = try await vectorStore.execute(vectorReq)
			var snaps = models.map(DefaultSnapshot.init)
				// Apply NSPredicate locally (vector DBs rarely support full NSPredicate)
			if let pred = request.predicate {
				snaps = snaps.filter { pred.evaluate(with: $0.model) }
			}
			return DataStoreFetchResult(snapshots: snaps)
		} else {
				// Fallback: brute-force local scan (or add metadata filtering to backend)
			fatalError("Metadata-only fetch not implemented in sample")
		}
	}

		// MARK: - Save

	public func execute(_ request: DataStoreSaveChangesRequest<Model>) async throws -> DataStoreSaveChangesResult {
		let models = request.snapshots.map(\.model)
		try await vectorStore.execute(DataStoreSaveChangesRequest(models))
		return .init(inserted: models.count, updated: 0) // naive
	}

		// MARK: - Transactional editing

	public func transaction<T>(_ body: (inout EditingState<Model>) async throws -> T) async throws -> T {
		var state = EditingState<Model>()
		let value = try await body(&state)
			// Apply changes
		let inserts = state.changes.filter { $0.kind == .insert }.map(\.snapshot)
		let updates = state.changes.filter { $0.kind == .update }.map(\.snapshot)
		let deletes = state.changes.filter { $0.kind == .delete }.map(\.snapshot)

		if !inserts.isEmpty {
			try await execute(DataStoreSaveChangesRequest(inserts))
		}
		if !updates.isEmpty {
			try await execute(DataStoreSaveChangesRequest(updates))
		}
			// deletes: add method to backend if required
		_ = deletes
		return value
	}
}

extension SwiftDataStyleStore {
    
    /// Execute delete request
    /// - Parameter ids: Array of document IDs to delete
    /// - Throws: Backend errors
    public func delete(ids: [String]) async throws {
        try await vectorStore.backend.delete(ids: ids)
    }
    
    /// Delete snapshots
    /// - Parameter snapshots: Snapshots to delete
    /// - Throws: Backend errors
    public func delete(_ snapshots: [DefaultSnapshot<Model>]) async throws {
        let ids = snapshots.map { String($0.model.id) }
        try await delete(ids: ids)
    }
    
    /// Transactional editing with full CRUD support
    /// **UPDATED**: Now properly processes delete operations
    public func transaction<T>(_ body: (inout EditingState<Model>) async throws -> T) async throws -> T {
        var state = EditingState<Model>()
        let value = try await body(&state)
        
        // Apply changes in order: deletes first, then updates, then inserts
        let deletes = state.changes.filter { $0.kind == .delete }.map(\.snapshot)
        let updates = state.changes.filter { $0.kind == .update }.map(\.snapshot)
        let inserts = state.changes.filter { $0.kind == .insert }.map(\.snapshot)
        
        // Process deletes
        if !deletes.isEmpty {
            try await delete(deletes)
        }
        
        // Process updates
        if !updates.isEmpty {
            try await execute(DataStoreSaveChangesRequest(updates))
        }
        
        // Process inserts
        if !inserts.isEmpty {
            try await execute(DataStoreSaveChangesRequest(inserts))
        }
        
        return value
    }
}
extension SwiftDataStyleStore {

		/// Execute fetch request with full metadata filtering support
		/// **UPDATED**: Replaces fatalError with actual implementation
	public func execute(_ request: DataStoreFetchRequest<Model>) async throws -> DataStoreFetchResult<Model> {

			// Path 1: Semantic/vector search
		if let query = request.semanticQuery {
			let vectorReq = VectorDataStore<Vector, Model>.FetchRequest(
				queryText: query,
				topK: request.fetchLimit ?? 10,
				threshold: request.similarityThreshold
			)
			let models = try await vectorStore.execute(vectorReq)
			var snaps = models.map(DefaultSnapshot.init)

				// Apply NSPredicate locally (vector DBs rarely support full NSPredicate)
			if let pred = request.predicate {
				snaps = snaps.filter { pred.evaluate(with: $0.model) }
			}

				// Apply sort descriptors
			if let sortDescriptors = request.sortDescriptors {
				snaps = sort(snaps, by: sortDescriptors)
			}

			return DataStoreFetchResult(snapshots: snaps)
		}

			// Path 2: Metadata-only fetch (no vector search)
		else {
				// Fetch all documents from backend
			let allMetadata = try await vectorStore.backend.fetchAll()
			var models = allMetadata.compactMap(Model.init(metadata:))

				// Apply predicate
			if let pred = request.predicate {
				models = models.filter { pred.evaluate(with: $0) }
			}

				// Apply sort descriptors
			var snaps = models.map(DefaultSnapshot.init)
			if let sortDescriptors = request.sortDescriptors {
				snaps = sort(snaps, by: sortDescriptors)
			}

				// Apply limit
			if let limit = request.fetchLimit {
				snaps = Array(snaps.prefix(limit))
			}

			return DataStoreFetchResult(snapshots: snaps)
		}
	}

		/// Helper to sort snapshots
	private func sort(_ snapshots: [DefaultSnapshot<Model>],
					  by descriptors: [SortDescriptor<Model>]) -> [DefaultSnapshot<Model>] {
		guard !descriptors.isEmpty else { return snapshots }

		return snapshots.sorted { lhs, rhs in
			for descriptor in descriptors {
				let comparison = descriptor.compare(lhs.model, rhs.model)
				if comparison != .orderedSame {
					return comparison == .orderedAscending
				}
			}
			return false
		}
	}
}
