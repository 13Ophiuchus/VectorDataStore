//
//  BatchProcessorTests.swift
//  VectorDataStore
//
//  Created by Nicholas Reich on 10/24/25.
//

import Testing

@Suite("Batch Processor Tests")
struct BatchProcessorTests {
    
    @Test("Batch processing with multiple batches")
    func testBatchProcessing() async throws {
        let processor = BatchProcessor(batchSize: 3)
        let items = Array(1...10)
        
        let results = try await processor.process(items: items) { batch in
            return batch.count
        }
        
        // Should have 4 batches: [1,2,3], [4,5,6], [7,8,9], [10]
        #expect(results == [3, 3, 3, 1])
    }
}
