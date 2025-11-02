//
//  DataStoreConfiguration.swift
//  VectorDataStore
//
//  Created by Nicholas Reich on 10/21/25.
//

import Foundation

/// Immutable value describing where and how the store lives.
public struct DataStoreConfiguration<Vector: VectorProtocol>: Sendable {
    public let storeName: String
    public let schema: Schema
    public let endpoint: URL?          // e.g. http://localhost:6333 for Qdrant
    public let apiKey: String?

    public struct Schema: Sendable, Equatable {
        public let vectorDimensions: Int
        public let metric: Metric

        public enum Metric: String, Sendable {
            case cosine
            case dot
            case euclid
        }

        public init(vectorDimensions: Int, metric: Metric = .cosine) {
            self.vectorDimensions = vectorDimensions
            self.metric = metric
        }
    }

    public init(storeName: String,
                schema: Schema,
                endpoint: URL? = nil,
                apiKey: String? = nil) {
        self.storeName = storeName
        self.schema    = schema
        self.endpoint  = endpoint
        self.apiKey    = apiKey
    }
}
