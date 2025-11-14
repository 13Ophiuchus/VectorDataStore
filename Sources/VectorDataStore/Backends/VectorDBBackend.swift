//
//  VectorDBBackend.swift
//  VectorDataStore
//
//  Created by Nicholas Reich on 10/23/25.
//

import Foundation

// MARK: - VectorDBBackend Protocol

public protocol VectorDBBackend: Sendable {
    associatedtype Vector: VectorProtocol

    /// Write or update vectors with metadata.
    func upsert(_ payloads: [VectorPayload<Vector>]) async throws

    /// Nearest-neighbour search.
    func search(vector: Vector, topK: Int, threshold: Float?) async throws -> [[String: String]]

    /// Delete vectors by IDs.
    /// - Parameter ids: Array of document IDs to delete
    /// - Throws: Backend-specific errors (network, not found, etc.)
    func delete(ids: [String]) async throws

    /// Optional: Fetch all documents (for metadata-only filtering)
    /// Default implementation returns empty array
    func fetchAll() async throws -> [[String: String]]
}
