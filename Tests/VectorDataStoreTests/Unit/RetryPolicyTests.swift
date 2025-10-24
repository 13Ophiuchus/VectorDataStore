//
//  RetryPolicyTests.swift
//  VectorDataStore
//
//  Created by Nicholas Reich on 10/24/25.
//

import Testing

@Suite("Retry Policy Tests")
struct RetryPolicyTests {
    
    @Test("Retry succeeds on second attempt")
    func testRetrySuccess() async throws {
        let policy = RetryPolicy(maxAttempts: 3, baseDelay: 0.1)
        
        actor FailCounter {
            var count = 0
            func increment() -> Int {
                count += 1
                return count
            }
        }
        
        let counter = FailCounter()
        
        let result = try await policy.execute {
            let attempt = await counter.increment()
            if attempt == 1 {
                throw URLError(.timedOut)
            }
            return "success"
        }
        
        #expect(result == "success")
    }
    
    @Test("Retry fails after max attempts")
    func testRetryFailure() async throws {
        let policy = RetryPolicy(maxAttempts: 2, baseDelay: 0.1)
        
        await #expect(throws: URLError.self) {
            try await policy.execute {
                throw URLError(.timedOut)
            }
        }
    }
}
