//
//  OpenAIEmbedder.swift
//  VectorDataStore
//
//  Created by Nicholas Reich on 10/24/25.
//



//
// OpenAIEmbedder.swift
// VectorDataStore/Embedders
//
// Production OpenAI embeddings integration
//

import Foundation

/// OpenAI embeddings provider
public actor OpenAIEmbedder: EmbeddingModel {
    public typealias Vector = [Float]
    
    private let apiKey: String
    private let model: String
    private let endpoint: URL
    private let session: URLSession
    
    public enum OpenAIError: Error, LocalizedError {
        case invalidAPIKey
        case invalidResponse
        case httpError(statusCode: Int, message: String)
        case rateLimitExceeded
        case networkError(Error)
        case decodingError(Error)
        
        public var errorDescription: String? {
            switch self {
            case .invalidAPIKey:
                return "Invalid OpenAI API key"
            case .invalidResponse:
                return "Invalid response from OpenAI API"
            case .httpError(let code, let message):
                return "HTTP \(code): \(message)"
            case .rateLimitExceeded:
                return "Rate limit exceeded. Please try again later."
            case .networkError(let error):
                return "Network error: \(error.localizedDescription)"
            case .decodingError(let error):
                return "Failed to decode response: \(error.localizedDescription)"
            }
        }
    }
    
    /// Initialize OpenAI embedder
    /// - Parameters:
    ///   - apiKey: OpenAI API key
    ///   - model: Embedding model (default: text-embedding-3-small)
    public init(apiKey: String, model: String = "text-embedding-3-small") {
        self.apiKey = apiKey
        self.model = model
        self.endpoint = URL(string: "https://api.openai.com/v1/embeddings")!
        
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 60
        config.timeoutIntervalForResource = 300
        self.session = URLSession(configuration: config)
    }
    
    public func embed(texts: [String]) async throws -> [[Float]] {
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
        let payload: [String: Any] = [
            "input": texts,
            "model": model,
            "encoding_format": "float"
        ]
        
        guard let jsonData = try? JSONSerialization.data(withJSONObject: payload) else {
            throw OpenAIError.invalidResponse
        }
        
        request.httpBody = jsonData
        
        do {
            let (data, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw OpenAIError.invalidResponse
            }
            
            if httpResponse.statusCode == 401 {
                throw OpenAIError.invalidAPIKey
            }
            
            if httpResponse.statusCode == 429 {
                throw OpenAIError.rateLimitExceeded
            }
            
            if httpResponse.statusCode != 200 {
                let message = String(data: data, encoding: .utf8) ?? "Unknown error"
                throw OpenAIError.httpError(statusCode: httpResponse.statusCode, message: message)
            }
            
            // Parse response
            struct OpenAIResponse: Codable {
                struct EmbeddingData: Codable {
                    let embedding: [Float]
                }
                let data: [EmbeddingData]
            }
            
            let decoder = JSONDecoder()
            let apiResponse = try decoder.decode(OpenAIResponse.self, from: data)
            
            return apiResponse.data.map { $0.embedding }
            
        } catch let error as OpenAIError {
            throw error
        } catch let error as DecodingError {
            throw OpenAIError.decodingError(error)
        } catch {
            throw OpenAIError.networkError(error)
        }
    }
}
