import Foundation

public protocol VectorProtocol: Sendable, Encodable, Decodable {
	var dimensions: Int { get }
	func l2distance(to other: Self) -> Float
}

extension Array: VectorProtocol where Element == Float {
	public var dimensions: Int { count }
	public func l2distance(to other: Self) -> Float {
		precondition(count == other.count)
		return sqrt(zip(self, other).reduce(0) { $0 + ($1.0 - $1.1) * ($1.0 - $1.1) })
	}

}
