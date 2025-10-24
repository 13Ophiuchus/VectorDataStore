//
//  DeleteOperationTests.swift
//  VectorDataStore
//
//  Created by Nicholas Reich on 10/24/25.
//

import Testing

@Suite("Delete Operation Tests")
struct DeleteOperationTests {
    
    @Test("MemoryBackend delete by IDs")
    func testMemoryBackendDelete() async throws {
        let backend = MemoryBackend<[Float]>()
        
        // Insert documents
        let payloads = [
            VectorPayload(vector: [1.0, 0.0], metadata: ["id": "1", "title": "First"]),
            VectorPayload(vector: [0.0, 1.0], metadata: ["id": "2", "title": "Second"]),
            VectorPayload(vector: [1.0, 1.0], metadata: ["id": "3", "title": "Third"])
        ]
        try await backend.upsert(payloads)
        
        var count = await backend.count()
        #expect(count == 3)
        
        // Delete one document
        try await backend.delete(ids: ["2"])
        
        count = await backend.count()
        #expect(count == 2)
        
        // Verify the right one was deleted
        let results = try await backend.search(vector: [0.0, 1.0], topK: 10, threshold: nil)
        #expect(!results.contains(where: { $0["id"] == "2" }))
        #expect(results.contains(where: { $0["id"] == "1" }))
        #expect(results.contains(where: { $0["id"] == "3" }))
    }
    
    @Test("MemoryBackend delete multiple IDs")
    func testMemoryBackendDeleteMultiple() async throws {
        let backend = MemoryBackend<[Float]>()
        
        let payloads = (1...10).map { i in
            VectorPayload(vector: [Float(i), 0.0], metadata: ["id": "\(i)"])
        }
        try await backend.upsert(payloads)
        
        // Delete multiple
        try await backend.delete(ids: ["1", "3", "5", "7", "9"])
        
        let count = await backend.count()
        #expect(count == 5)
    }
    
    @Test("MemoryBackend delete non-existent ID")
    func testMemoryBackendDeleteNonExistent() async throws {
        let backend = MemoryBackend<[Float]>()
        
        let payload = VectorPayload(vector: [1.0, 0.0], metadata: ["id": "1"])
        try await backend.upsert([payload])
        
        // Should not throw when deleting non-existent ID
        try await backend.delete(ids: ["999"])
        
        let count = await backend.count()
        #expect(count == 1) // Original still there
    }
    
    @Test("SwiftDataStyleStore transaction with delete")
    @MainActor
    func testTransactionWithDelete() async throws {
        let config = DataStoreConfiguration<[Float]>(
            storeName: "test-delete",
            schema: .init(vectorDimensions: 10)
        )
        let embedder = MockEmbedder(dimension: 10)
        let backend = MemoryBackend<[Float]>()
        let store = SwiftDataStyleStore(
            configuration: config,
            embedder: embedder,
            backend: backend
        )
        
        // Setup embeddings
        for i in 1...3 {
            await embedder.setEmbedding("Doc \(i)", vector: Array(repeating: Float(i), count: 10))
        }
        
        // Insert documents
        try await store.transaction { tx in
            for i in 1...3 {
                let doc = TestDoc(id: "\(i)", title: "Doc \(i)")
                tx.insert(DefaultSnapshot(of: doc))
            }
        }
        
        var count = await backend.count()
        #expect(count == 3)
        
        // Delete one in transaction
        try await store.transaction { tx in
            let doc = TestDoc(id: "2", title: "Doc 2")
            tx.delete(DefaultSnapshot(of: doc))
        }
        
        count = await backend.count()
        #expect(count == 2)
    }
}
