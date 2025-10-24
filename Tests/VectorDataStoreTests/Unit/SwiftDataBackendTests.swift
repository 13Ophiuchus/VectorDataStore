//
//  SwiftDataBackendTests.swift
//  VectorDataStore
//
//  Created by Nicholas Reich on 10/24/25.
//

import Testing

@Suite("SwiftDataBackend Tests")
@MainActor
struct SwiftDataBackendTests {
    
    @Test("SwiftDataBackend insert and search")
    func testSwiftDataBackendInsertSearch() async throws {
        let backend = try SwiftDataBackend<[Float]>.createInMemory()
        
        // Insert documents
        let payloads = [
            VectorPayload(vector: [1.0, 0.0, 0.0], metadata: ["id": "1", "title": "First"]),
            VectorPayload(vector: [0.0, 1.0, 0.0], metadata: ["id": "2", "title": "Second"])
        ]
        
        try await backend.upsert(payloads)
        
        // Search
        let results = try await backend.search(
            vector: [0.9, 0.1, 0.0],
            topK: 1,
            threshold: nil
        )
        
        #expect(results.count == 1)
        #expect(results.first?["id"] == "1")
    }
    
    @Test("SwiftDataBackend delete")
    func testSwiftDataBackendDelete() async throws {
        let backend = try SwiftDataBackend<[Float]>.createInMemory()
        
        let payloads = [
            VectorPayload(vector: [1.0, 0.0], metadata: ["id": "1"]),
            VectorPayload(vector: [0.0, 1.0], metadata: ["id": "2"])
        ]
        
        try await backend.upsert(payloads)
        
        var count = try backend.count()
        #expect(count == 2)
        
        try await backend.delete(ids: ["1"])
        
        count = try backend.count()
        #expect(count == 1)
    }
    
    @Test("SwiftDataBackend persistence")
    func testSwiftDataBackendPersistence() async throws {
        // Create backend with file storage
        let backend = try SwiftDataBackend<[Float]>.createDefault(storeName: "test-persistence")
        
        let payload = VectorPayload(vector: [1.0, 2.0], metadata: ["id": "persist-1"])
        try await backend.upsert([payload])
        
        // Verify it was saved
        let count = try backend.count()
        #expect(count == 1)
        
        // Clean up
        try backend.clear()
    }
}
