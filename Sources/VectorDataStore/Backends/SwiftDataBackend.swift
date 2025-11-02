//
//
//  SwiftDataBackend.swift
//  VectorDataStore
//
//
//
//

import Foundation
import SwiftData
import Spatial

/// Local persistence backend using SwiftData
/// Provides on-device vector storage for iOS/macOS apps
@MainActor
public final class SwiftDataBackend<Vector: VectorProtocol>: VectorDBBackend {

    private let modelContainer: ModelContainer
    private let modelContext: ModelContext

    public enum SwiftDataBackendError: Error, LocalizedError {
        case encodingError
        case decodingError
        case containerError
        case notFound

        public var errorDescription: String? {
            switch self {
            case .encodingError:
                return "Failed to encode vector data"
            case .decodingError:
                return "Failed to decode vector data"
            case .containerError:
                return "SwiftData container error"
            case .notFound:
                return "Document not found"
            }
        }
    }

    /// Initialize with model container
    public init(modelContainer: ModelContainer) throws {
        self.modelContainer = modelContainer
        self.modelContext = ModelContext(modelContainer)
        self.modelContext.autosaveEnabled = true
    }

    /// Convenience initializer with default configuration
    public static func createDefault(storeName: String = "VectorStore") throws -> SwiftDataBackend {
        let schema = Schema([VectorEntry.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        let container = try ModelContainer(for: schema, configurations: [config])
        return try SwiftDataBackend(modelContainer: container)
    }

    /// Convenience initializer for in-memory only (testing)
    public static func createInMemory() throws -> SwiftDataBackend {
        let schema = Schema([VectorEntry.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        return try SwiftDataBackend(modelContainer: container)
    }

    // MARK: - VectorDBBackend Protocol

    public func upsert(_ payloads: [VectorPayload<Vector>]) async throws {
        for payload in payloads {
            // Encode vector
            guard let vectorData = try? JSONEncoder().encode(payload.vector) else {
                throw SwiftDataBackendError.encodingError
            }

            // Encode metadata
            guard let metadataJSON = try? JSONEncoder().encode(payload.metadata),
                  let metadataString = String(data: metadataJSON, encoding: .utf8) else {
                throw SwiftDataBackendError.encodingError
            }

            let id = payload.metadata["id"] ?? UUID().uuidString

            // Check if entry exists
            let descriptor = FetchDescriptor<VectorEntry>(
                predicate: #Predicate { $0.id == id }
            )

            if let existing = try modelContext.fetch(descriptor).first {
                // Update existing
                existing.vectorData = vectorData
                existing.metadataJSON = metadataString
                existing.timestamp = Date()
            } else {
                // Insert new
                let entry = VectorEntry(
                    id: id,
                    vectorData: vectorData,
                    metadataJSON: metadataString
                )
                modelContext.insert(entry)
            }
        }

        try modelContext.save()
    }

    public func search(vector: Vector, topK: Int, threshold: Float?) async throws -> [[String: String]] {
        // Fetch all entries
        let descriptor = FetchDescriptor<VectorEntry>()
        let entries = try modelContext.fetch(descriptor)

        // Calculate distances and score
        let scored: [(metadata: [String: String], distance: Float)] = entries.compactMap { entry in
            // Decode metadata first since it's usually smaller and more likely to succeed
            guard let metadataData = entry.metadataJSON.data(using: .utf8),
                  let metadata = try? JSONDecoder().decode([String: String].self, from: metadataData) else {
                // Skip this entry if metadata decoding fails
                return nil
            }

            do {
                // Try to decode the vector - if this fails, we skip the entry
                let entryVector = try JSONDecoder().decode(Vector.self, from: entry.vectorData)
                let distance = entryVector.l2distance(to: vector)
                return (metadata: metadata, distance: distance)
            } catch {
                // Skip this entry if vector decoding fails
                return nil
            }
        }

        // Sort by distance (ascending = closest first)
        let sorted = scored.sorted { $0.distance < $1.distance }

        // Apply threshold filter
        let filtered: [[String: String]]
        if let threshold = threshold {
            filtered = sorted
                .filter { $0.distance <= threshold }
                .prefix(topK)
                .map { $0.metadata }
        } else {
            filtered = sorted
                .prefix(topK)
                .map { $0.metadata }
        }

        return Array(filtered)
    }

    public func delete(ids: [String]) async throws {
        for id in ids {
            let descriptor = FetchDescriptor<VectorEntry>(
                predicate: #Predicate { $0.id == id }
            )

            if let entry = try modelContext.fetch(descriptor).first {
                modelContext.delete(entry)
            }
        }

        try modelContext.save()
    }

    public func fetchAll() async throws -> [[String: String]] {
        let descriptor = FetchDescriptor<VectorEntry>()
        let entries = try modelContext.fetch(descriptor)

        return entries.compactMap { entry in
            guard let metadataData = entry.metadataJSON.data(using: .utf8),
                  let metadata = try? JSONDecoder().decode([String: String].self, from: metadataData) else {
                return nil
            }
            return metadata
        }
    }

    // MARK: - Additional Helpers

    /// Count total entries
    public func count() throws -> Int {
        let descriptor = FetchDescriptor<VectorEntry>()
        return try modelContext.fetchCount(descriptor)
    }

    /// Clear all entries
    public func clear() throws {
        let descriptor = FetchDescriptor<VectorEntry>()
        let entries = try modelContext.fetch(descriptor)
        for entry in entries {
            modelContext.delete(entry)
        }
        try modelContext.save()
    }
}
