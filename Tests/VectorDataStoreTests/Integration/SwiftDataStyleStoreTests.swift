//
//  SwiftDataStyleStoreTests.swift
//  VectorDataStore
//
//  Created by Nicholas Reich on 10/24/25.
//

import Foundation
import Testing

@Suite("SwiftDataStyleStore Integration Tests")
@MainActor
struct SwiftDataStyleStoreTests {
    
    final class TestNote: PersistentModel, Codable, Equatable, Identifiable {
        static var schemaVersion: Int { 1 }
        
        var id: String
        var title: String
        var content: String
        
        var embeddingText: String {
            "\(title). \(content)"
        }
        
        init(id: String, title: String, content: String) {
            self.id = id
            self.title = title
            self.content = content
        }
        
        required init?(metadata: [String: String]) {
            guard let data = try? JSONSerialization.data(withJSONObject: metadata),
                  let decoded = try? JSONDecoder().decode(TestNote.self, from: data) else {
                return nil
            }
            self = decoded
        }
        
        static func migrate(_ old: [String: Any], from version: Int) -> TestNote? {
            return nil
        }
        
        static func == (lhs: TestNote, rhs: TestNote) -> Bool {
            lhs.id == rhs.id && lhs.title == rhs.title && lhs.content == rhs.content
        }
    }
    
    @Test("Transaction insert and fetch")
    func testTransactionInsertAndFetch() async throws {
        let config = DataStoreConfiguration<[Float]>(
            storeName: "notes",
            schema: .init(vectorDimensions: 768)
        )
        let embedder = MockEmbedder(dimension: 768)
        let backend = MemoryBackend<[Float]>()
        let store = SwiftDataStyleStore(configuration: config, embedder: embedder, backend: backend)
        
        // Configure embedding
        let noteVec = Array(repeating: Float(1.0), count: 768)
        await embedder.setEmbedding("Swift 6. Concurrency", vector: noteVec)
        
        // Insert via transaction
        try await store.transaction { tx in
            let note = TestNote(id: "note-1", title: "Swift 6", content: "Concurrency")
            tx.insert(DefaultSnapshot(of: note))
        }
        
        // Fetch back
        await embedder.setEmbedding("concurrency", vector: noteVec)
        let result = try await store.execute(DataStoreFetchRequest(
            semanticQuery: "concurrency",
            fetchLimit: 1
        ))
        
        #expect(result.count > 0)
        #expect(result.snapshots.first?.model.title == "Swift 6")
    }
    
    @Test("Transaction with multiple inserts")
    func testMultipleInserts() async throws {
        let config = DataStoreConfiguration<[Float]>(
            storeName: "multi-notes",
            schema: .init(vectorDimensions: 384)
        )
        let embedder = MockEmbedder(dimension: 384)
        let backend = MemoryBackend<[Float]>()
        let store = SwiftDataStyleStore<[Float], TestNote>(
            configuration: config,
            embedder: embedder,
            backend: backend
        )
        
        // Configure embeddings
        for i in 1...3 {
            let vec = Array(repeating: Float(i), count: 384)
            await embedder.setEmbedding("Note \(i). Content \(i)", vector: vec)
        }
        
        // Insert multiple notes
        try await store.transaction { tx in
            for i in 1...3 {
                let note = TestNote(id: "note-\(i)", title: "Note \(i)", content: "Content \(i)")
                tx.insert(DefaultSnapshot(of: note))
            }
        }
        
        // Verify we can fetch them
        let vec = Array(repeating: Float(1.0), count: 384)
        await embedder.setEmbedding("query", vector: vec)
        let result = try await store.execute(DataStoreFetchRequest(
            semanticQuery: "query",
            fetchLimit: 10
        ))
        
        #expect(result.count == 3)
    }
    
    @Test("Update operation in transaction")
    func testUpdateOperation() async throws {
        let config = DataStoreConfiguration<[Float]>(
            storeName: "update-test",
            schema: .init(vectorDimensions: 384)
        )
        let embedder = MockEmbedder(dimension: 384)
        let backend = MemoryBackend<[Float]>()
        let store = SwiftDataStyleStore<[Float], TestNote>(
            configuration: config,
            embedder: embedder,
            backend: backend
        )
        
        let vec = Array(repeating: Float(1.0), count: 384)
        await embedder.setEmbedding("Original. Content", vector: vec)
        
        // Insert original
        try await store.transaction { tx in
            let note = TestNote(id: "1", title: "Original", content: "Content")
            tx.insert(DefaultSnapshot(of: note))
        }
        
        // Update
        await embedder.setEmbedding("Updated. New content", vector: vec)
        try await store.transaction { tx in
            let updated = TestNote(id: "1", title: "Updated", content: "New content")
            tx.update(DefaultSnapshot(of: updated))
        }
        
        // Fetch and verify
        await embedder.setEmbedding("query", vector: vec)
        let result = try await store.execute(DataStoreFetchRequest(
            semanticQuery: "query",
            fetchLimit: 1
        ))
        
        #expect(result.count > 0)
    }
}
