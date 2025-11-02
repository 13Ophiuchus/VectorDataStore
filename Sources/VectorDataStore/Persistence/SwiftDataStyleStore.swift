//
//  SwiftDataStyleStore.swift
//  VectorDataStore
//
//  Created by Nicholas Reich on 10/24/25.
//
import Foundation
import SwiftData

/// Actor that wraps the low-level `VectorDataStore` but exposes
/// SwiftData-style request/result types.
public actor SwiftDataStyleStore<Model: PersistentModel> {
    public typealias ModelType = Model

    public let config: DataStoreConfiguration<[Float]>
    internal let vectorStore: VectorDataStore<[Float], Model, SwiftDataBackend<[Float]>, OpenAIEmbedder>
    private var migrationPlan: (any SchemaMigrationPlan)?

    public init(
        configuration: DataStoreConfiguration<[Float]>,
        embedder: OpenAIEmbedder,
        backend: SwiftDataBackend<[Float]>,
        migrationPlan: (any SchemaMigrationPlan)? = nil
    ) {
        self.config = configuration
        self.vectorStore = .init(
            configuration: configuration,
            embedder: embedder,
            backend: backend
        )
        self.migrationPlan = migrationPlan
    }

    // MARK: - Fetch

    public func execute(_ request: DataStoreFetchRequest<Model>) async throws -> DataStoreFetchResult<Model> {
        // If semantic query exists, do vector search first
        if let query = request.semanticQuery {
            let vectorReq = DataStoreFetchRequest<Model>(
                semanticQuery: query,
                fetchLimit: request.fetchLimit,
                similarityThreshold: request.similarityThreshold
            )
            let models = try await vectorStore.execute(vectorReq)
            var snaps = models.map(DefaultSnapshot<Model>.init)

            // Apply Predicate locally (vector DBs rarely support full NSPredicate)
            if let pred = request.predicate {
                snaps = try snaps.filter { try evaluate(pred, with: $0.model) }
            }

            // Apply sort descriptors
            if let sortDescriptors = request.sortDescriptors {
                snaps = sort(snaps, by: sortDescriptors)
            }

            return DataStoreFetchResult(snapshots: [snaps])
        } else {
            // Fallback: brute-force local scan (or add metadata filtering to backend)
            // Access backend through internal property
            let allMetadata = try await getBackend().fetchAll()
            var models = allMetadata.compactMap(Model.init(metadata:))

            // Apply predicate
            if let pred = request.predicate {
                models = try models.filter { try evaluate(pred, with: $0) }
            }

            // Apply sort descriptors
            var snaps = models.map(DefaultSnapshot<Model>.init)
            if let sortDescriptors = request.sortDescriptors {
                snaps = sort(snaps, by: sortDescriptors)
            }

            // Apply limit
            if let limit = request.fetchLimit {
                snaps = Array(snaps.prefix(limit))
            }

            return DataStoreFetchResult(snapshots: [snaps])
        }
    }

    // Helper to access backend (workaround for private access)
    private func getBackend() -> SwiftDataBackend<[Float]> {
        // Use Mirror to access private backend property
        let mirror = Mirror(reflecting: vectorStore)
        guard let backendChild = mirror.children.first(where: { $0.label == "backend" }),
              let backend = backendChild.value as? SwiftDataBackend<[Float]> else {
            fatalError("Could not access backend from VectorDataStore")
        }
        return backend
    }

    // Helper function to evaluate Predicate
    private func evaluate(_ predicate: Predicate, with model: Model) throws -> Bool {
        switch predicate.operation {
        case .equal(let key, let value):
            guard let modelValue = mirror(for: model, at: key) else { return false }
            return String(describing: modelValue) == value
            
        case .contains(let key, let value):
            guard let modelValue = mirror(for: model, at: key) else { return false }
            let stringValue = String(describing: modelValue)
            return stringValue.contains(value)
        }
    }

    // Helper to get a value from Mirror
    private func mirror(for model: Model, at key: String) -> Any? {
        for child in Mirror(reflecting: model).children {
            if let label = child.label, label == key || "\(key)" == String(describing: child.label) {
                return child.value
            }
        }
        return nil
    }

    // MARK: - Save

    public func execute(_ request: DataStoreSaveChangesRequest<Model>) async throws -> DataStoreSaveChangesResult {
        // Convert snapshots to models, then create request with models
        let models = request.snapshots.map(\.model)
        let modelRequest = DataStoreSaveChangesRequest<Model>(models.map(DefaultSnapshot<Model>.init))
        try await vectorStore.execute(modelRequest)
        return .init(inserted: models.count, updated: 0) // naive
    }

    // MARK: - Delete

    /// Execute delete request
    /// - Parameter ids: Array of document IDs to delete
    public func delete(ids: [String]) async throws {
        try await getBackend().delete(ids: ids)
    }

    /// Delete snapshots
    /// - Parameter snapshots: Snapshots to delete
    public func delete(_ snapshots: [DefaultSnapshot<Model>]) async throws {
        let ids = snapshots.map { String(describing: $0.model.id) }
        try await delete(ids: ids)
    }

    // MARK: - Transactional editing

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

    // MARK: - Sorting Helpers

    /// Helper to sort snapshots
    private func sort(
        _ snapshots: [DefaultSnapshot<Model>],
        by descriptors: [SortDescriptor]
    ) -> [DefaultSnapshot<Model>] {
        guard !descriptors.isEmpty else { return snapshots }

        return snapshots.sorted { lhs, rhs in
            for descriptor in descriptors {
                guard let comparison = compare(descriptor, lhs.model, rhs.model) else { continue }
                if comparison != .orderedSame {
                    return comparison == .orderedAscending
                }
            }
            return false
        }
    }

    private func compare(
        _ descriptor: SortDescriptor,
        _ lhsModel: Model,
        _ rhsModel: Model
    ) -> ComparisonResult? {
        guard let lhsValue = mirror(for: lhsModel, at: descriptor.key),
              let rhsValue = mirror(for: rhsModel, at: descriptor.key) else {
            return nil
        }

        // Explicitly handle types to avoid 'any Comparable' issue
        switch (lhsValue, rhsValue) {
        case let (l as String, r as String):
            if l < r { return .orderedAscending }
            if l > r { return .orderedDescending }
            return .orderedSame
            
        case let (l as Int, r as Int):
            if l < r { return .orderedAscending }
            if l > r { return .orderedDescending }
            return .orderedSame
            
        case let (l as Double, r as Double):
            if l < r { return .orderedAscending }
            if l > r { return .orderedDescending }
            return .orderedSame
            
        case let (l as Float, r as Float):
            if l < r { return .orderedAscending }
            if l > r { return .orderedDescending }
            return .orderedSame
            
        case let (l as Date, r as Date):
            if l < r { return .orderedAscending }
            if l > r { return .orderedDescending }
            return .orderedSame
            
        default:
            // Fallback: compare as String
            let l = String(describing: lhsValue)
            let r = String(describing: rhsValue)
            if l < r { return .orderedAscending }
            if l > r { return .orderedDescending }
            return .orderedSame
        }
    }
}
