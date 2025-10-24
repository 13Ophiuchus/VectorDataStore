//
//  MemoryBackendTests.swift
//  VectorDataStore
//
//  Created by Nicholas Reich on 10/24/25.
//

import Testing

@Suite("MemoryBackend Tests")
struct MemoryBackendTests {
    
    @Test("Upsert and search single vector")
    func testUpsertAndSearch() async throws {
        let backend = MemoryBackend<[Float]>()
        
        let payload = VectorPayload(
            vector: [1.0, 0.0, 0.0],
            metadata: ["id": "1", "title": "First Document"]
        )
        
        try await backend.upsert([payload])
        
        // Search for closest match
        let results = try await backend.search(
            vector: [0.9, 0.1, 0.0],
            topK: 1,
            threshold: nil
        )
        
        #expect(results.count == 1)
        #expect(results.first?["id"] == "1")
        #expect(results.first?["title"] == "First Document")
    }
    
    @Test("Search with multiple vectors")
    func testMultipleVectors() async throws {
        let backend = MemoryBackend<[Float]>()
        
        let payloads = [
            VectorPayload(vector: [1.0, 0.0, 0.0], metadata: ["id": "1", "category": "A"]),
            VectorPayload(vector: [0.0, 1.0, 0.0], metadata: ["id": "2", "category": "B"]),
            VectorPayload(vector: [0.0, 0.0, 1.0], metadata: ["id": "3", "category": "C"])
        ]
        
        try await backend.upsert(payloads)
        
        // Search for vector closest to first one
        let results = try await backend.search(
            vector: [0.9, 0.1, 0.0],
            topK: 2,
            threshold: nil
        )
        
        #expect(results.count == 2)
        #expect(results.first?["id"] == "1")
    }
    
    @Test("Threshold filtering")
    func testThresholdFiltering() async throws {
        let backend = MemoryBackend<[Float]>()
        
        let payload = VectorPayload(
            vector: [1.0, 0.0, 0.0],
            metadata: ["id": "1"]
        )
        
        try await backend.upsert([payload])
        
        // Search with strict threshold - orthogonal vectors have distance sqrt(2) ≈ 1.414
        let results = try await backend.search(
            vector: [0.0, 1.0, 0.0],
            topK: 10,
            threshold: 0.1
        )
        
        #expect(results.isEmpty)
    }
    
    @Test("TopK limit")
    func testTopKLimit() async throws {
        let backend = MemoryBackend<[Float]>()
        
        // Insert 10 vectors
        let payloads = (1...10).map { i in
            VectorPayload(
                vector: [Float(i), 0.0, 0.0],
                metadata: ["id": "\(i)"]
            )
        }
        
        try await backend.upsert(payloads)
        
        // Search with topK=3
        let results = try await backend.search(
            vector: [5.0, 0.0, 0.0],
            topK: 3,
            threshold: nil
        )
        
        #expect(results.count == 3)
    }
    
    @Test("Empty backend search")
    func testEmptyBackendSearch() async throws {
        let backend = MemoryBackend<[Float]>()
        
        let results = try await backend.search(
            vector: [1.0, 0.0, 0.0],
            topK: 10,
            threshold: nil
        )
        
        #expect(results.isEmpty)
    }
}
