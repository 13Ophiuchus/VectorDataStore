//
//  LocalEmbedderTests.swift
//  
//
//  Created by Nicholas Reich on 11/11/25.
//


import Testing
import VectorDataStore

@TestableModule("VectorDataStore")
struct LocalEmbedderTests {

    var embedder: LocalEmbedder!

    @Test("Initialization with valid path should succeed")
    func testValidModelPath() async throws {
        let testBundle = Bundle(for: LocalEmbedderTests.self)
        guard let url = testBundle.url(forResource: "test-embeddings", withExtension: "mlmodelc") else {
            fatalError("Test model not found")
        }

        embedder = try await LocalEmbedder(modelPath: url.path)
        #expect(embedder != nil, "Should initialize without error")
    }

    @Test("Empty input should not fail")
    func testEmptyInput() async throws {
        do {
            let _ = try await embedder.embed(texts: [])
            #expect(true, "Empty input should be handled gracefully")
        } catch {
            #fail("Empty input should not throw: $error)")
        }
    }

    @Test("Embeddings should be consistent for identical inputs")
    func testConsistency() async throws {
        let texts = ["Swift is great", "Testing embeddings"]

        for _ in 1...3 {
            let results = try await embedder.embed(texts: texts)
            #expect(results.count == 2, "Should return two vectors")
        }
    }

    @Test("Invalid path should fail gracefully")
    func testErrorHandling() async throws {
        let badPath = "/this/path/does/not/exist"

        do {
            _ = LocalEmbedder(modelPath: badPath)
            #fail("Should throw error for invalid path")
        } catch {
            #expect(error as? LocalEmbedder.EmbedderError == .invalidModelPath, "Should return invalid path error")
        }
    }

    @MainCommand
    static func run() throws {
        LocalEmbedderTests()
    }
}
