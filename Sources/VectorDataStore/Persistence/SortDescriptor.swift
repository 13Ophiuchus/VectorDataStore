//
//  SortDescriptor.swift
//  VectorDataStore
//
//  Created by Nicholas Reich on 10/24/25.
//
import Foundation

// MARK: - Sort Descriptor Support ---------------------------------------------

public struct SortDescriptor: Sendable {
    public enum Order: Sendable {
        case ascending
        case descending
    }

    public let key: String
    public let order: Order

    public init(key: String, order: Order = .ascending) {
        self.key = key
        self.order = order
    }
}

public enum SortOrder: Sendable {
    case forward
    case reverse
}
