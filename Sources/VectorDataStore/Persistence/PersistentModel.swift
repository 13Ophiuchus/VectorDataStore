//
//  PersistentModel.swift
//  MyLibrary
//
//  Created by Nicholas Reich on 10/21/25.
//

//  swift-tools-version:6.0
//  SwiftDataStyleVectorStore.swift
//  Re-implements requested SwiftData surface area atop our VectorDataStore.

import Foundation

// MARK: - PersistentModel -----------------------------------------------------

/// SwiftData-style model base. Conforming types are *not* backed by SQLite
/// but by the vector DB;  still we give them `PersistentIdentifier`,
/// snapshotting, migration, etc.
public protocol PersistentModel: VectorModel, Codable, Sendable {
    /// Current schema version for this model type.
    static var schemaVersion: Int { get }
    /// Called by the migration plan to upgrade an outdated payload.
    static func migrate(_ old: [String: Any], from version: Int) -> Self?
}

// MARK: - PersistentIdentifier ----------------------------------------------

/// Opaque, Sendable identifier (same shape as SwiftData’s).
public struct PersistentIdentifier: Sendable, Hashable, CustomStringConvertible {
    public let url: URL                     // scheme = "vectorstore"
    public var description: String { url.absoluteString }
    public init?(urlString: String) {
        guard let u = URL(string: urlString), u.scheme == "vectorstore" else { return nil }
        self.url = u
    }
    public init(modelID: some StringProtocol, version: Int = 1) {
        self.url = URL(string: "vectorstore://\(modelID)?v=\(version)")!
    }
    public var modelID: String { url.host ?? "" }
    public var version: Int    { Int(URLComponents(url: url, resolvingAgainstBaseURL: false)?
                                        .queryItems?.first(where: { $0.name == "v" })?.value ?? "1") ?? 1 }
}

// MARK: - Snapshotting --------------------------------------------------------

/// Immutable value of the model at a point in time.
public struct DefaultSnapshot<Model: PersistentModel>: Sendable {
    public let model: Model
    public let id: PersistentIdentifier
    public init(of model: Model) {
        self.model = model
        self.id = PersistentIdentifier(modelID: model.id, version: Model.schemaVersion)
    }
}

// MARK: - Migration -----------------------------------------------------------

/// Describes how to move between schema versions.
public protocol SchemaMigrationPlan: Sendable {
    associatedtype Model: PersistentModel
    static var versions: [Int] { get }               // ascending
    static func migrate(_ payload: [String: Any], from: Int, to: Int) -> Model?
}

// MARK: - Requests / Results --------------------------------------------------
public struct Predicate: Sendable {
    public enum Operation: Sendable {
        case equal(key: String, value: String)
        case contains(key: String, value: String)
    }

    public let operation: Operation

    public init(_ operation: Operation) {
        self.operation = operation
    }
}

public struct DataStoreFetchRequest<Model: VectorModel>: Sendable {
    public let semanticQuery: String?
    public let fetchLimit: Int?
    public let similarityThreshold: Float?
    public let predicate: Predicate?
	public let sortDescriptors: [SortDescriptor]?  // ← make generic over Model

    public init(
        semanticQuery: String? = nil,
        fetchLimit: Int? = nil,
        similarityThreshold: Float? = nil,
        predicate: Predicate? = nil,
		sortDescriptors: [SortDescriptor]? = nil   // ← make generic over Model
    ) {
        self.semanticQuery = semanticQuery
        self.fetchLimit = fetchLimit
        self.similarityThreshold = similarityThreshold
        self.predicate = predicate
        self.sortDescriptors = sortDescriptors
    }
}

public struct DataStoreFetchResult<Model: PersistentModel>: Sendable {
	public let snapshots: [[DefaultSnapshot<Model>]]
    public var count: Int { snapshots.count }
}

public struct DataStoreSaveChangesRequest<Model: PersistentModel>: Sendable {
    public let snapshots: [DefaultSnapshot<Model>]
    public init(_ snapshots: [DefaultSnapshot<Model>]) { self.snapshots = snapshots }
}

public struct DataStoreSaveChangesResult: Sendable {
    public let inserted: Int
    public let updated:  Int
}

// MARK: - EditingState --------------------------------------------------------

/// Mirrors SwiftData’s `EditingTransaction` (but we do not need undo).
public struct EditingState<Model: PersistentModel>: Sendable {
    public enum ChangeKind : Sendable{ case insert, update, delete }
    public struct Change: Sendable {
        public let kind: ChangeKind
        public let snapshot: DefaultSnapshot<Model>
    }
    fileprivate(set) public var changes: [Change] = []
    public mutating func insert(_ s: DefaultSnapshot<Model>) { changes.append(.init(kind: .insert, snapshot: s)) }
    public mutating func update(_ s: DefaultSnapshot<Model>) { changes.append(.init(kind: .update, snapshot: s)) }
    public mutating func delete(_ s: DefaultSnapshot<Model>) { changes.append(.init(kind: .delete, snapshot: s)) }
}

// MARK: - Sample concrete model ----------------------------------------------

struct ResearchNote: PersistentModel, Codable, Equatable, Identifiable {
    static var schemaVersion: Int { 2 }
    
    var id: String
    var title: String
    var content: String
    
    var embeddingText: String { "\(title). \(content)" }
    
    init(id: String, title: String, content: String) {
        self.id = id; self.title = title; self.content = content
    }
    
    init?(metadata: [String: String]) {
        guard let data = try? JSONSerialization.data(withJSONObject: metadata),
              let decoded = try? JSONDecoder().decode(ResearchNote.self, from: data)
        else { return nil }
        self = decoded
    }
    
    static func migrate(_ old: [String: Any], from version: Int) -> ResearchNote? {
        guard version == 1 else { return nil }
        // v1 → v2: rename key "body" → "content"
        var dict = old
        if let body = dict["body"] as? String {
            dict["content"] = body
            dict.removeValue(forKey: "body")
        }
        return try? JSONDecoder().decode(ResearchNote.self,
                                         from: JSONSerialization.data(withJSONObject: dict))
    }
}
