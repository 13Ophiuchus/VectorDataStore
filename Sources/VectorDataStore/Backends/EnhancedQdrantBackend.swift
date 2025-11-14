//
//
//  EnhancedQdrantBackend.swift
//  VectorDataStore
//
//
//  Created by Nicholas Reich on 10/24/25.
//
import Foundation

/// Qdrant search response model (file-scope to avoid nesting in generic closures)
private struct QdrantSearchResponse: Decodable {
    struct Point: Decodable {
        let payload: [String: String]?
    }
    let result: [Point]
}

/// Updated QdrantBackend with retry logic and proper ID hashing
public final class EnhancedQdrantBackend<V: VectorProtocol & Codable>: VectorDBBackend {
    public typealias Vector = V

    private let endpoint: URL
    private let apiKey: String?
    private let collectionName: String
    private let vectorDimensions: Int
    private let session: URLSession
    private let retryPolicy: RetryPolicy

    public init(
        endpoint: URL,
        apiKey: String? = nil,
        collectionName: String,
        vectorDimensions: Int,
        retryPolicy: RetryPolicy = RetryPolicy()
    ) {
        self.endpoint = endpoint
        self.apiKey = apiKey
        self.collectionName = collectionName
        self.vectorDimensions = vectorDimensions
        self.retryPolicy = retryPolicy

        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 300
        self.session = URLSession(configuration: config)
    }

    /// Hash document ID to stable integer for Qdrant point ID
    private func hashID(_ id: String) -> Int {
        var hasher = Hasher()
        hasher.combine(id)
        let hash = hasher.finalize()
        return abs(hash)
    }

    public func upsert(_ payloads: [VectorPayload<Vector>]) async throws {
        try await retryPolicy.execute {
            let url = self.endpoint.appendingPathComponent("collections/\(self.collectionName)/points")
            var request = URLRequest(url: url)
            request.httpMethod = "PUT"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")

            if let apiKey = self.apiKey {
                request.setValue(apiKey, forHTTPHeaderField: "api-key")
            }

            // Build Qdrant points
            let points: [[String: Any]] = payloads.map { payload in
                let docId = payload.metadata["id"] ?? UUID().uuidString
                let pointId = self.hashID(docId)

                return [
                    "id": pointId,
                    "vector": payload.vector,
                    "payload": payload.metadata
                ]
            }

            let upsertPayload: [String: Any] = ["points": points]
            let jsonData = try JSONSerialization.data(withJSONObject: upsertPayload)
            request.httpBody = jsonData

            let (data, response) = try await self.session.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw HTTPError(statusCode: -1)
            }

            guard httpResponse.statusCode == 200 else {
                _ = String(data: data, encoding: .utf8)
                throw HTTPError(statusCode: httpResponse.statusCode)
            }
        }
    }

    public func search(vector: Vector, topK: Int, threshold: Float?) async throws -> [[String: String]] {
        try await retryPolicy.execute {
            let url = self.endpoint.appendingPathComponent("collections/\(self.collectionName)/points/search")
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            if let apiKey = self.apiKey {
                request.setValue(apiKey, forHTTPHeaderField: "api-key")
            }

            var payload: [String: Any] = [
                "vector": vector,
                "limit": topK
            ]
            if let threshold { payload["score_threshold"] = threshold }

            request.httpBody = try JSONSerialization.data(withJSONObject: payload)

            let (data, response) = try await self.session.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw HTTPError(statusCode: -1)
            }
            guard httpResponse.statusCode == 200 else {
                throw HTTPError(statusCode: httpResponse.statusCode)
            }

            let decoded = try JSONDecoder().decode(QdrantSearchResponse.self, from: data)
            return decoded.result.compactMap { $0.payload }
        }
    }

    public func delete(ids: [String]) async throws {
        try await retryPolicy.execute {
            let url = self.endpoint.appendingPathComponent("collections/\(self.collectionName)/points/delete")
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")

            if let apiKey = self.apiKey {
                request.setValue(apiKey, forHTTPHeaderField: "api-key")
            }

            // Convert string IDs to hashed point IDs
            let pointIds = ids.map { self.hashID($0) }
            let deletePayload: [String: Any] = ["points": pointIds]
            request.httpBody = try JSONSerialization.data(withJSONObject: deletePayload)

            let (_, response) = try await self.session.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw HTTPError(statusCode: -1)
            }
            guard httpResponse.statusCode == 200 else {
                throw HTTPError(statusCode: httpResponse.statusCode)
            }
        }
    }

    public func fetchAll() async throws -> [[String: String]] {
        // TODO: Minimal stub; implement Qdrant scroll if needed.
        // TODO: Qdrant's scroll endpoint: POST /collections/{name}/points/scroll
        return []
    }
}

/// The backend holds non-Sendable members (URLSession); we assert safe cross-actor use.
extension EnhancedQdrantBackend: @unchecked Sendable {}
