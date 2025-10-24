//
//  MemoryBackend.swift
//  MyLibrary
//
//  Created by Nicholas Reich on 10/21/25.
//


import Foundation

public final class MemoryBackend<Vector: VectorProtocol>: VectorDBBackend {

	private struct Entry: Sendable {
		let vector: Vector
		let meta: [String: String]
	}

	private var storage: [Entry] = []
	private let lock = NSLock()

	public init() {}

	public func upsert(_ payloads: [VectorPayload<Vector>]) async throws {
		lock.withLock {
			for p in payloads {
					// Remove existing entry with same ID
				if let existingId = p.metadata["id"] {
					storage.removeAll { $0.meta["id"] == existingId }
				}
				storage.append(.init(vector: p.vector, meta: p.metadata))
			}
		}
	}

	public func search(vector: Vector, topK: Int, threshold: Float?) async throws -> [[String: String]] {
		lock.withLock {
			let scored = storage.map { e in
				let d = e.vector.l2distance(to: vector)
				return (meta: e.meta, score: d)
			}
				.sorted { $0.score < $1.score }
				.prefix(topK)
				.compactMap { threshold == nil || $0.score <= threshold! ? $0.meta : nil }

			return Array(scored)
		}
	}

		/// Delete vectors by document IDs
		/// - Parameter ids: Array of document IDs to remove
	public func delete(ids: [String]) async throws {
		lock.withLock {
			storage.removeAll { entry in
				guard let entryId = entry.meta["id"] else { return false }
				return ids.contains(entryId)
			}
		}
	}

		/// Fetch all documents (for metadata-only filtering)
	public func fetchAll() async throws -> [[String: String]] {
		lock.withLock {
			return storage.map { $0.meta }
		}
	}

		/// Get current storage count (useful for testing)
	public func count() async -> Int {
		lock.withLock {
			return storage.count
		}
	}

		/// Clear all storage (useful for testing)
	public func clear() async {
		lock.withLock {
			storage.removeAll()
		}
	}
}
