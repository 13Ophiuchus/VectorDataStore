//
//  DataStoreConfigurationTests.swift
//  VectorDataStore
//
//  Created by Nicholas Reich on 10/24/25.
//

import Testing

@Suite("DataStoreConfiguration Tests")
struct DataStoreConfigurationTests {
    
    @Test("Configuration initialization")
    func testConfigurationInit() {
        let schema = DataStoreConfiguration<[Float]>.Schema(vectorDimensions: 768)
        let config = DataStoreConfiguration<[Float]>(
            storeName: "test-store",
            schema: schema,
            endpoint: URL(string: "http://localhost:6333"),
            apiKey: "test-key"
        )
        
        #expect(config.storeName == "test-store")
        #expect(config.schema.vectorDimensions == 768)
        #expect(config.endpoint?.absoluteString == "http://localhost:6333")
        #expect(config.apiKey == "test-key")
    }
    
    @Test("Configuration with nil optional parameters")
    func testConfigurationNilOptionals() {
        let schema = DataStoreConfiguration<[Float]>.Schema(vectorDimensions: 384)
        let config = DataStoreConfiguration<[Float]>(
            storeName: "local-store",
            schema: schema
        )
        
        #expect(config.endpoint == nil)
        #expect(config.apiKey == nil)
    }
    
    @Test("Schema metric defaults to cosine")
    func testSchemaDefaultMetric() {
        let schema = DataStoreConfiguration<[Float]>.Schema(vectorDimensions: 1536)
        #expect(schema.metric == .cosine)
    }
}
