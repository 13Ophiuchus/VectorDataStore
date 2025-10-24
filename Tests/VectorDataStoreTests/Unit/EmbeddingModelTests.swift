//
//  EmbeddingModelTests.swift
//  VectorDataStore
//
//  Created by Nicholas Reich on 10/24/25.
//

import Testing

@Suite("EmbeddingModel Tests")
struct EmbeddingModelTests {
    
    @Test("MockEmbedder returns configured embeddings")
    func testMockEmbedderConfiguredEmbeddings() async throws {
        let embedder = MockEmbedder(dimension: 3)
        
        await embedder.setEmbedding("hello", vector: [1.0, 2.0, 3.0])
        await embedder.setEmbedding("world", vector: [4.0, 5.0, 6.0])
        
        let results = try await embedder.embed(texts: ["hello", "world"])
        
        #expect(results.count == 2)
        #expect(results[0] == [1.0, 2.0, 3.0])
        #expect(results[1] == [4.0, 5.0, 6.0])
    }
    
    @Test("MockEmbedder returns zero vector for unknown text")
    func testMockEmbedderUnknownText() async throws {
        let embedder = MockEmbedder(dimension: 3)
        
        let results = try await embedder.embed(texts: ["unknown"])
        
        #expect(results.count == 1)
        #expect(results[0] == [0.0, 0.0, 0.0])
    }
    
    @Test("MockEmbedder tracks call count")
    func testMockEmbedderCallCount() async throws {
        let embedder = MockEmbedder(dimension: 3)
        
        var count = await embedder.getCallCount()
        #expect(count == 0)
        
        _ = try await embedder.embed(texts: ["test"])
        count = await embedder.getCallCount()
        #expect(count == 1)
        
        _ = try await embedder.embed(texts: ["test1", "test2"])
        count = await embedder.getCallCount()
        #expect(count == 2)
        
        await embedder.resetCallCount()
        count = await embedder.getCallCount()
        #expect(count == 0)
    }
}

