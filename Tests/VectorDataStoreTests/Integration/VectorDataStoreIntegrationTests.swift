//
//  VectorDataStoreIntegrationTests.swift
//  VectorDataStore
//
//  Created by Nicholas Reich on 10/24/25.
//

import Testing
@testable import VectorDataStore
import Foundation

@Suite("VectorDataStore Integration Tests")
struct VectorDataStoreIntegrationTests {
    
    // Test model for integration tests
    struct TestDocument: VectorModel, Codable, Equatable {
        let id: String
        let title: String
        let content: String
        
        var embeddingText: String {
            "\(title). \(content)"
        }
        
        init(id: String, title: String, content: String) {
            self.id = id
            self.title = title
            self.content = content
        }
        
        init?(metadata: [String: String]) {
            guard let data = try? JSONSerialization.data(withJSONObject: metadata),
                  let decoded = try? JSONDecoder().decode(TestDocument.self, from: data) else {
                return nil
            }
            self = decoded
        }
    }
    
    @Test("Complete workflow: insert and search documents")
    func testCompleteWorkflow() async throws {
        // Setup
        let config = DataStoreConfiguration<[Float]>(
            storeName: "test-workflow",
            schema: .init(vectorDimensions: 384)
        )
        let embedder = MockEmbedder(dimension: 384)
        let backend = MemoryBackend<[Float]>()
        let store = VectorDataStore(configuration: config, embedder: embedder, backend: backend)
        
        // Configure embeddings
        let doc1Vec = Array(repeating: Float(1.0), count: 384)
        let doc2Vec = Array(repeating: Float(0.5), count: 384)
        
        await embedder.setEmbedding("Swift Programming. Modern language", vector: doc1Vec)
        await embedder.setEmbedding("Python ML. Machine learning", vector: doc2Vec)
        
        // Insert documents
        let doc1 = TestDocument(id: "1", title: "Swift Programming", content: "Modern language")
        let doc2 = TestDocument(id: "2", title: "Python ML", content: "Machine learning")
        
        try await store.execute(DataStoreSaveChangesRequest([doc1, doc2]))
        
        // Search
        await embedder.setEmbedding("Swift", vector: doc1Vec)
        let results = try await store.execute(DataStoreFetchRequest(queryText: "Swift", topK: 2))
        
        #expect(results.count >= 1)
        #expect(results.first?.id == "1")
    }
    
    @Test("Search returns empty array when no documents match")
    func testEmptySearchResults() async throws {
        let config = DataStoreConfiguration<[Float]>(
            storeName: "empty-test",
            schema: .init(vectorDimensions: 10)
        )
        let embedder = MockEmbedder(dimension: 10)
        let backend = MemoryBackend<[Float]>()
        let store = VectorDataStore(configuration: config, embedder: embedder, backend: backend)
        
        let results = try await store.execute(DataStoreFetchRequest(queryText: "nonexistent", topK: 10))
        
        #expect(results.isEmpty)
    }
    
    @Test("Threshold filtering in search")
    func testThresholdFiltering() async throws {
        let config = DataStoreConfiguration<[Float]>(
            storeName: "threshold-test",
            schema: .init(vectorDimensions: 3)
        )
        let embedder = MockEmbedder(dimension: 3)
        let backend = MemoryBackend<[Float]>()
        let store = VectorDataStore(configuration: config, embedder: embedder, backend: backend)
        
        // Insert document with specific vector
        await embedder.setEmbedding("Document. Content", vector: [1.0, 0.0, 0.0])
        let doc = TestDocument(id: "1", title: "Document", content: "Content")
        try await store.execute(DataStoreSaveChangesRequest([doc]))
        
        // Search with orthogonal vector and strict threshold
        await embedder.setEmbedding("Query", vector: [0.0, 1.0, 0.0])
        let results = try await store.execute(
            DataStoreFetchRequest(queryText: "Query", topK: 10, threshold: 0.1)
        )
        
        #expect(results.isEmpty)
    }
}

