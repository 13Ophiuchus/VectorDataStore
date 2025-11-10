//
//  VectorPayload.swift
//  
//
//  Created by Nicholas Reich on 11/9/25.
//

import Foundation

/// Convenience wrapper so the store never sees raw vectors alone.
public struct VectorPayload<Vector: VectorProtocol>: Sendable {
    public let vector: Vector
    public let metadata: [String: String]

    public init(vector: Vector, metadata: [String: String]) {
        self.vector = vector
        self.metadata = metadata
    }
}
