//
//  MetadataOnlyFetchTests.swift
//  VectorDataStore
//
//  Created by Nicholas Reich on 10/24/25.
//

import Testing

@Suite("Metadata-Only Fetch Tests")
struct MetadataOnlyFetchTests {
    
    struct TestDoc: VectorModel, Codable, Equatable, Identifiable {
        let id: String
        let title: String
        var category: String?
        
        var embeddingText: String { title }
        
        init?(metadata: [String: String]) {
            guard let data = try? JSONSerialization.data(withJSONObject: metadata),
                  let decoded = try? JSONDecoder().decode(Self.self, from: data) else {
                return nil
            }
            self = decoded
        }
        
        init(id: String, title: String, category: String? = nil) {
            self.id = id
            self.title = title
            self.category = category
        }
    }
    
    @Test("Fetch all documents without semantic query")
    @MainActor
    func testFetchAll() async throws {
        let config = DataStoreConfiguration<[Float]>(
            storeName: "test-fetch-all",
            schema: .init(vectorDimensions: 10)
        )
        let embedder = MockEmbedder(dimension: 10)
        let backend = MemoryBackend<[Float]>()
        let store = SwiftDataStyleStore<[Float], TestDoc>(
            configuration: config,
            embedder: embedder,
            backend: backend
        )
        
        // Insert documents
        for i in 1...5 {
            await embedder.setEmbedding("Doc \(i)", vector: Array(repeating: Float(i), count: 10))
        }
        
        try await store.transaction { tx in
            for i in 1...5 {
                let doc = TestDoc(id: "\(i)", title: "Doc \(i)")
                tx.insert(DefaultSnapshot(of: doc))
            }
        }
        
        // Fetch all (no semantic query)
        let request = DataStoreFetchRequest<TestDoc>(fetchLimit: nil, semanticQuery: nil)
        let result = try await store.execute(request)
        
        #expect(result.count == 5)
    }
    
    @Test("Metadata filtering with NSPredicate")
    @MainActor
    func testMetadataFiltering() async throws {
        let config = DataStoreConfiguration<[Float]>(
            storeName: "test-predicate",
            schema: .init(vectorDimensions: 10)
        )
        let embedder = MockEmbedder(dimension: 10)
        let backend = MemoryBackend<[Float]>()
        let store = SwiftDataStyleStore<[Float], TestDoc>(
            configuration: config,
            embedder: embedder,
            backend: backend
        )
        
        // Insert documents with categories
        for i in 1...5 {
            await embedder.setEmbedding("Doc \(i)", vector: Array(repeating: Float(i), count: 10))
        }
        
        try await store.transaction { tx in
            tx.insert(DefaultSnapshot(of: TestDoc(id: "1", title: "Doc 1", category: "A")))
            tx.insert(DefaultSnapshot(of: TestDoc(id: "2", title: "Doc 2", category: "B")))
            tx.insert(DefaultSnapshot(of: TestDoc(id: "3", title: "Doc 3", category: "A")))
        }
        
        // Filter by category
        let predicate = NSPredicate(format: "category == %@", "A")
        let request = DataStoreFetchRequest<TestDoc>(
            predicate: predicate,
            fetchLimit: nil,
            semanticQuery: nil
        )
        let result = try await store.execute(request)
        
        #expect(result.count == 2)
        #expect(result.snapshots.allSatisfy { $0.model.category == "A" })
    }
}
