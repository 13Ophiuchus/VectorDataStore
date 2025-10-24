//
//  PersistentIdentifierTests.swift
//  VectorDataStore
//
//  Created by Nicholas Reich on 10/24/25.
//

import Testing

@Suite("PersistentIdentifier Tests")
struct PersistentIdentifierTests {
    
    @Test("Identifier creation and parsing")
    func testIdentifierCreation() {
        let id = PersistentIdentifier(modelID: "test-123", version: 2)
        
        #expect(id.modelID == "test-123")
        #expect(id.version == 2)
        #expect(id.description.contains("test-123"))
        #expect(id.description.contains("v=2"))
    }
    
    @Test("Identifier round-trip")
    func testIdentifierRoundTrip() {
        let original = PersistentIdentifier(modelID: "doc-456", version: 3)
        let urlString = original.description
        
        let parsed = PersistentIdentifier(urlString: urlString)
        
        #expect(parsed != nil)
        #expect(parsed?.modelID == original.modelID)
        #expect(parsed?.version == original.version)
    }
    
    @Test("Invalid URL string returns nil")
    func testInvalidURLString() {
        let invalid = PersistentIdentifier(urlString: "not-a-valid-url")
        #expect(invalid == nil)
        
        let wrongScheme = PersistentIdentifier(urlString: "https://example.com")
        #expect(wrongScheme == nil)
    }
    
    @Test("Default version is 1")
    func testDefaultVersion() {
        let id = PersistentIdentifier(modelID: "test")
        #expect(id.version == 1)
    }
}
