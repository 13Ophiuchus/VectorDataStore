//
// MemoryBackend.swift
// VectorDataStore
//
// Created by Nicholas Reich on 10/21/25.
//

import Foundation

/// In-memory vector storage backend
/// Thread-safe using NSLock for synchronization
public final class MemoryBackend: VectorDBBackend {

    public typealias Vector = [Float]

    private struct Entry: Sendable {
        let vector: [Float]
        let meta: [String: String]
    }

    // Use nonisolated(unsafe) to satisfy Sendable while protecting with lock
    nonisolated(unsafe) private var storage: [Entry] = []
    nonisolated(unsafe) private let lock: NSLock = NSLock()

    public init() {}

    // MARK: - VectorDBBackend Protocol Implementation

    public func upsert(_ payloads: [VectorPayload<[Float]>]) async throws {
        lock.withLock {
            for p in payloads {
                // Remove existing entry with same ID
                if let existingId = p.metadata["id"] {
                    storage.removeAll { $0.meta["id"] == existingId }
                }
                // Add new entry
                storage.append(.init(vector: p.vector, meta: p.metadata))
            }
        }
    }

    public func search(vector: [Float], topK: Int, threshold: Float?) async throws -> [[String: String]] {
        let scored = lock.withLock {
            storage.map { e in
                let d = e.vector.l2distance(to: vector)
                return (meta: e.meta, distance: d)
            }
        }

        let sorted = scored.sorted { $0.distance < $1.distance }

        let filtered: [[String: String]]
        if let threshold = threshold {
            filtered = sorted
                .filter { $0.distance <= threshold }
                .prefix(topK)
                .map { $0.meta }
        } else {
            filtered = sorted
                .prefix(topK)
                .map { $0.meta }
        }

        return Array(filtered)
    }

    public func delete(ids: [String]) async throws {
        lock.withLock {
            storage.removeAll { entry in
                guard let entryId = entry.meta["id"] else { return false }
                return ids.contains(entryId)
            }
        }
    }

    public func fetchAll() async throws -> [[String: String]] {
        lock.withLock {
            storage.map { $0.meta }
        }
    }

    // MARK: - Testing Helpers

    /// Get current storage count (useful for testing)
    public func count() async -> Int {
        lock.withLock { storage.count }
    }

    /// Clear all storage (useful for testing)
    public func clear() async {
        lock.withLock { storage.removeAll() }
    }
}

// If you don’t already have this helper, add it somewhere in your module:
private extension NSLock {
    @inline(__always)
    func withLock<T>(_ body: () -> T) -> T {
        lock(); defer { unlock() }
        return body()
    }
}
