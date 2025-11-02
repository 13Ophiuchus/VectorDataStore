//
//  SortDescriptor.swift
//  VectorDataStore
//
//  Created by Nicholas Reich on 10/24/25.
//
import Foundation
import SwiftData

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

///// Sort descriptor for metadata-only queries
//public struct SortDescriptor<Model>: Sendable {
//    private let _compare: @Sendable (Model, Model) -> ComparisonResult
//    
//    public init<Value: Comparable>(
//        _ keyPath: KeyPath<Model, Value>,
//        order: SortOrder = .forward
//    ) {
//        self._compare = { lhs, rhs in
//            let lValue = lhs[keyPath: keyPath]
//            let rValue = rhs[keyPath: keyPath]
//            
//            if lValue < rValue {
//                return order == .forward ? .orderedAscending : .orderedDescending
//            } else if lValue > rValue {
//                return order == .forward ? .orderedDescending : .orderedAscending
//            } else {
//                return .orderedSame
//            }
//        }
//    }
//    
//    func compare(_ lhs: Model, _ rhs: Model) -> ComparisonResult {
//        return _compare(lhs, rhs)
//    }
//}

public enum SortOrder: Sendable {
    case forward
    case reverse
}
