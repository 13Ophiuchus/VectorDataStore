//
//  VectorProtocolTests.swift
//  VectorDataStore
//
//  Created by Nicholas Reich on 10/24/25.
//

import Testing
@testable import VectorDataStore

@Suite("Vector Protocol Tests")
struct VectorProtocolTests {
    
    @Test("L2 distance calculation")
    func testL2Distance() {
        let vec1: [Float] = [1.0, 2.0, 3.0]
        let vec2: [Float] = [4.0, 5.0, 6.0]
        
        let distance = vec1.l2distance(to: vec2)
        // Distance = sqrt((3^2) + (3^2) + (3^2)) = sqrt(27) ≈ 5.196
        let expected: Float = sqrt(27.0)
        
        #expect(abs(distance - expected) < 0.001)
    }
    
    @Test("Zero distance for identical vectors")
    func testIdenticalVectors() {
        let vec: [Float] = [1.0, 2.0, 3.0]
        
        let distance = vec.l2distance(to: vec)
        
        #expect(distance == 0.0)
    }
    
    @Test("Vector dimensions")
    func testDimensions() {
        let vec: [Float] = [1.0, 2.0, 3.0]
        #expect(vec.dimensions == 3)
        
        let largeVec: [Float] = Array(repeating: 1.0, count: 1536)
        #expect(largeVec.dimensions == 1536)
    }
    
    @Test("Distance symmetry")
    func testDistanceSymmetry() {
        let vec1: [Float] = [1.0, 2.0, 3.0]
        let vec2: [Float] = [4.0, 5.0, 6.0]
        
        let dist1 = vec1.l2distance(to: vec2)
        let dist2 = vec2.l2distance(to: vec1)
        
        #expect(abs(dist1 - dist2) < 0.001)
    }
}

