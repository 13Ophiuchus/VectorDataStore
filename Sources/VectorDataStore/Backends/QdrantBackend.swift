	//
	// QdrantBackend.swift
	// VectorDataStore/Backends
	//
	// Production-ready Qdrant vector database backend
	//

import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

	/// Qdrant vector database backend implementation
	/// Supports both REST API and self-hosted Qdrant instances
public final class QdrantBackend<Vector: VectorProtocol>: VectorDBBackend {

	private let endpoint: URL
	private let apiKey: String?
	private let collectionName: String
	private let vectorDimensions: Int
	private let session: URLSession

	public enum QdrantError: Error, LocalizedError {
		case invalidURL
		case invalidResponse
		case httpError(statusCode: Int, message: String)
		case encodingError
		case decodingError(Error)
		case collectionNotFound
		case networkError(Error)

		public var errorDescription: String? {
			switch self {
				case .invalidURL:
					return "Invalid Qdrant endpoint URL"
				case .invalidResponse:
					return "Invalid response from Qdrant server"
				case .httpError(let code, let message):
					return "HTTP \(code): \(message)"
				case .encodingError:
					return "Failed to encode request payload"
				case .decodingError(let error):
					return "Failed to decode response: \(error.localizedDescription)"
				case .collectionNotFound:
					return "Collection not found. Please create it first."
				case .networkError(let error):
					return "Network error: \(error.localizedDescription)"
			}
		}
	}

		/// Initialize Qdrant backend
		/// - Parameters:
		///   - endpoint: Qdrant server URL (e.g., http://localhost:6333)
		///   - apiKey: Optional API key for Qdrant Cloud
		///   - collectionName: Name of the collection to use
		///   - vectorDimensions: Dimension of vectors
	public init(endpoint: URL, apiKey: String? = nil, collectionName: String, vectorDimensions: Int) {
		self.endpoint = endpoint
		self.apiKey = apiKey
		self.collectionName = collectionName
		self.vectorDimensions = vectorDimensions

		let config = URLSessionConfiguration.default
		config.timeoutIntervalForRequest = 30
		config.timeoutIntervalForResource = 300
		self.session = URLSession(configuration: config)
	}

		/// Create collection if it doesn't exist
	public func createCollectionIfNeeded() async throws {
		let url = endpoint.appendingPathComponent("collections/\(collectionName)")
		var request = URLRequest(url: url)
		request.httpMethod = "PUT"
		request.setValue("application/json", forHTTPHeaderField: "Content-Type")

		if let apiKey = apiKey {
			request.setValue(apiKey, forHTTPHeaderField: "api-key")
		}

		let createPayload: [String: Any] = [
			"vectors": [
				"size": vectorDimensions,
				"distance": "Cosine"
			]
		]

		guard let jsonData = try? JSONSerialization.data(withJSONObject: createPayload) else {
			throw QdrantError.encodingError
		}

		request.httpBody = jsonData

		do {
			let (data, response) = try await session.data(for: request)

			guard let httpResponse = response as? HTTPURLResponse else {
				throw QdrantError.invalidResponse
			}

				// 200 = created, 409 = already exists (both OK)
			if httpResponse.statusCode != 200 && httpResponse.statusCode != 409 {
				let message = String(data: data, encoding: .utf8) ?? "Unknown error"
				throw QdrantError.httpError(statusCode: httpResponse.statusCode, message: message)
			}
		} catch let error as QdrantError {
			throw error
		} catch {
			throw QdrantError.networkError(error)
		}
	}

		/// Upsert vectors into Qdrant
	public func upsert(_ payloads: [VectorPayload<Vector>]) async throws {
		let url = endpoint.appendingPathComponent("collections/\(collectionName)/points")
		var request = URLRequest(url: url)
		request.httpMethod = "PUT"
		request.setValue("application/json", forHTTPHeaderField: "Content-Type")

		if let apiKey = apiKey {
			request.setValue(apiKey, forHTTPHeaderField: "api-key")
		}

			// Convert to Qdrant point format
		let points = payloads.enumerated().map { (index, payload) in
			return [
				"id": index, // Use hash of metadata['id'] in production
				"vector": payload.vector,
				"payload": payload.metadata
			] as [String: Any]
		}

		let upsertPayload: [String: Any] = ["points": points]

		guard let jsonData = try? JSONSerialization.data(withJSONObject: upsertPayload) else {
			throw QdrantError.encodingError
		}

		request.httpBody = jsonData

		do {
			let (data, response) = try await session.data(for: request)

			guard let httpResponse = response as? HTTPURLResponse else {
				throw QdrantError.invalidResponse
			}

			if httpResponse.statusCode != 200 {
				let message = String(data: data, encoding: .utf8) ?? "Unknown error"
				throw QdrantError.httpError(statusCode: httpResponse.statusCode, message: message)
			}
		} catch let error as QdrantError {
			throw error
		} catch {
			throw QdrantError.networkError(error)
		}
	}

		/// Search for nearest vectors
	public func search(vector: Vector, topK: Int, threshold: Float?) async throws -> [[String: String]] {
		let url = endpoint.appendingPathComponent("collections/\(collectionName)/points/search")
		var request = URLRequest(url: url)
		request.httpMethod = "POST"
		request.setValue("application/json", forHTTPHeaderField: "Content-Type")

		if let apiKey = apiKey {
			request.setValue(apiKey, forHTTPHeaderField: "api-key")
		}

		var searchPayload: [String: Any] = [
			"vector": vector,
			"limit": topK,
			"with_payload": true
		]

		if let threshold = threshold {
			searchPayload["score_threshold"] = threshold
		}

		guard let jsonData = try? JSONSerialization.data(withJSONObject: searchPayload) else {
			throw QdrantError.encodingError
		}

		request.httpBody = jsonData

		do {
			let (data, response) = try await session.data(for: request)

			guard let httpResponse = response as? HTTPURLResponse else {
				throw QdrantError.invalidResponse
			}

			if httpResponse.statusCode == 404 {
				throw QdrantError.collectionNotFound
			}

			if httpResponse.statusCode != 200 {
				let message = String(data: data, encoding: .utf8) ?? "Unknown error"
				throw QdrantError.httpError(statusCode: httpResponse.statusCode, message: message)
			}

				// Parse response
			guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
				  let result = json["result"] as? [[String: Any]] else {
				throw QdrantError.decodingError(NSError(domain: "QdrantBackend", code: -1))
			}

			return result.compactMap { point in
				guard let payload = point["payload"] as? [String: Any] else { return nil }
				return payload.compactMapValues { String(describing: $0) }
			}

		} catch let error as QdrantError {
			throw error
		} catch {
			throw QdrantError.networkError(error)
		}
	}

		/// Delete vectors by filter
	public func delete(ids: [String]) async throws {
		let url = endpoint.appendingPathComponent("collections/\(collectionName)/points/delete")
		var request = URLRequest(url: url)
		request.httpMethod = "POST"
		request.setValue("application/json", forHTTPHeaderField: "Content-Type")

		if let apiKey = apiKey {
			request.setValue(apiKey, forHTTPHeaderField: "api-key")
		}

		let deletePayload: [String: Any] = [
			"filter": [
				"must": ids.map { id in
					["key": "id", "match": ["value": id]]
				}
			]
		]

		guard let jsonData = try? JSONSerialization.data(withJSONObject: deletePayload) else {
			throw QdrantError.encodingError
		}

		request.httpBody = jsonData

		do {
			let (data, response) = try await session.data(for: request)

			guard let httpResponse = response as? HTTPURLResponse else {
				throw QdrantError.invalidResponse
			}

			if httpResponse.statusCode != 200 {
				let message = String(data: data, encoding: .utf8) ?? "Unknown error"
				throw QdrantError.httpError(statusCode: httpResponse.statusCode, message: message)
			}
		} catch let error as QdrantError {
			throw error
		} catch {
			throw QdrantError.networkError(error)
		}
	}
}
