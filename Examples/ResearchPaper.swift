//
//  ResearchPaper.swift
//  MyLibrary
//
//  Created by Nicholas Reich on 10/21/25.
//


import VectorDataStore

// 1. Define your document type
struct ResearchPaper: VectorModel, Codable, Equatable {
    let id: String
    let title: String
    let abstract: String
    
    var embeddingText: String { "\(title). \(abstract)" }
    
    init?(metadata: [String: String]) {
        guard let data = try? JSONSerialization.data(withJSONObject: metadata),
              let decoded = try? JSONDecoder().decode(Self.self, from: data)
        else { return nil }
        self = decoded
    }
}

// 2. Bring an embedding model (OpenAI wrapper shown)
actor OpenAIEmbedder: EmbeddingModel {
    typealias Vector = [Float]
    func embed(texts: [String]) async throws -> [Vector] {
        // call OpenAI /embeddings endpoint …
        return texts.map { _ in Array(repeating: Float.random(in: -1...1), count: 1536) }
    }
}

// 3. Wire everything up
let cfg = DataStoreConfiguration<[Float]>(
    storeName: "research",
    schema: .init(vectorDimensions: 1536)
)

let embedder = OpenAIEmbedder()
let backend  = MemoryBackend<[Float]>()   // swap for real backend

let store = VectorDataStore<[Float], ResearchPaper>(
    configuration: cfg,
    embedder: embedder,
    backend: backend
)

// 4. Save
let papers = [
    ResearchPaper(id: "1", title: "Attention is all you need", abstract: "We propose the Transformer …"),
    ResearchPaper(id: "2", title: "BERT", abstract: "Pre-training of deep bidirectional …")
]
try await store.execute(DataStoreSaveChangesRequest(papers))

// 5. Search
let matches = try await store.execute(DataStoreFetchRequest(queryText: "transformer architecture", topK: 3))
print(matches.map(\.title))   // → ["Attention is all you need"]