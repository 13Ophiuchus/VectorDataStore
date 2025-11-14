//
//  DefaultSnapshot.swift
//  VectorDataStore
//
//  Created by Nicholas Reich on 11/10/25.
//

import Foundation

/// Lightweight, generic snapshot used across platforms (no SwiftData dependency).
public struct DefaultSnapshot<Model: VectorModel>: Sendable {
    public let model: Model

    public init(of model: Model) {
        self.model = model
    }
}
