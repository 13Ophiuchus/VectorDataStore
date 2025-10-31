//
//  VectorProtocol.swift
//  VectorDataStore
//
//  Created by Nicholas Reich on 10/23/25.
//
import Foundation

	/// Vector must be `Sendable` value type (e.g. `[Float]`).
public protocol VectorProtocol: Sendable {
	var dimensions: Int { get }
	func l2distance(to other: Self) -> Float
}

extension Array: VectorProtocol where Element == Float {
	public var dimensions: Int { count }
	public func l2distance(to other: Self) -> Float {
		precondition(count == other.count)
		return zip(self, other).reduce(0) { $0 + ($1.0 - $1.1) * ($1.0 - $1.1) }
	}
}
