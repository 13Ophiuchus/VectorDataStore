//
//  Snapshot.swift
//  VectorDataStore
//
//  Created by Nicholas Reich on 11/10/25.
//

import Foundation

/// Cross-platform snapshot wrapper that can represent different snapshot forms
/// but always exposes the underlying model.
public enum Snapshot<Model: PersistentVectorModel>: Sendable {
    case value(Model)
    case defaultSnapshot(DefaultSnapshot<Model>)
    case vectorSnapshot(VectorSnapshot<Model>)

    /// Access the underlying model regardless of the wrapped snapshot form.
    public var model: Model {
        switch self {
        case .value(let m):
            return m
        case .defaultSnapshot(let s):
            return s.model
        case .vectorSnapshot(let s):
            return s.model
        }
    }

    /// Convenience initializer from a model value.
    public init(of model: Model) {
        self = .value(model)
    }

    /// Convenience initializer from a DefaultSnapshot (VectorDataStore-style).
    public init(_ snapshot: DefaultSnapshot<Model>) {
        self = .defaultSnapshot(snapshot)
    }

    /// Convenience initializer from a VectorSnapshot (lightweight).
    public init(_ snapshot: VectorSnapshot<Model>) {
        self = .vectorSnapshot(snapshot)
    }
}
