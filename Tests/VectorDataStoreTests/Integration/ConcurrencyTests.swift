//
//  ConcurrencyTests.swift
//  VectorDataStore
//
//  Created by Nicholas Reich on 10/24/25.
//

import Foundation
import Testing

@Suite("Concurrency Safety Tests")
@MainActor
struct ConcurrencyTests {
    
    struct ConcurrentDoc: VectorModel, Codable, Equatable {
        let id: String
        let data: String
        
        var embeddingText: String { data }
        
        init?(metadata: [String: String]) {
            guard let data = try? JSONSerialization.data(withJSONObject: metadata),
                  let decoded = try? JSONDecoder().decode(ConcurrentDoc.self, from: data) else {
                return nil
            }
            self = decoded
        }
        
        init(id: String, data: String) {
            self.id = id
            self.data = data
        }
    }
    
    @Test("Concurrent inserts")
    func testConcurrentInserts() async throws {
        let config = DataStoreConfiguration<[Float]>(
            storeName: "concurrent",
            schema: .init(vectorDimensions: 384)
        )
        let embedder = MockEmbedder(dimension: 384)
        let backend = MemoryBackend<[Float]>()
        let store = SwiftDataStyleStore<[Float], ConcurrentDoc>(
            configuration: config,
            embedder: embedder,
            backend: backend
        )
        
        // Configure embeddings for all documents
        for i in 1...10 {
            let vec = Array(repeating: Float(i) / 10.0, count: 384)
            await embedder.setEmbedding("Data \(i)", vector: vec)
        }
        
        // Perform concurrent inserts
        try await withThrowingTaskGroup(of: Void.self) { group in
            for i in 1...10 {
                group.addTask {
                    try await store.transaction { tx in
                        let doc = ConcurrentDoc(id: "\(i)", data: "Data \(i)")
                        tx.insert(DefaultSnapshot(of: doc))
                    }
                }
            }
            try await group.waitForAll()
        }
        
        // Verify all were inserted (embedder should have been called 10 times for inserts)
        let callCount = await embedder.getCallCount()
        #expect(callCount >= 10)
    }
    
    @Test("Concurrent reads")
    func testConcurrentReads() async throws {
        let config = DataStoreConfiguration<[Float]>(
            storeName: "concurrent-reads",
            schema: .init(vectorDimensions: 384)
        )
        let embedder = MockEmbedder(dimension: 384)
        let backend = MemoryBackend<[Float]>()
        let store = SwiftDataStyleStore<[Float], ConcurrentDoc>(
            configuration: config,
            embedder: embedder,
            backend: backend
        )
        
        // Insert some data first
        let vec = Array(repeating: Float(1.0), count: 384)
        await embedder.setEmbedding("Test data", vector: vec)
        
        try await store.transaction { tx in
            let doc = ConcurrentDoc(id: "1", data: "Test data")
            tx.insert(DefaultSnapshot(of: doc))
        }
        
        // Perform concurrent reads
        await embedder.setEmbedding("query", vector: vec)
        
        try await withThrowingTaskGroup(of: Int.self) { group in
            for _ in 1...5 {
                group.addTask {
                    let result = try await store.execute(DataStoreFetchRequest(
                        semanticQuery: "query",
                        fetchLimit: 1
                    ))
                    return result.count
                }
            }
            
            for try await count in group {
                #expect(count > 0)
            }
        }
    }
}
