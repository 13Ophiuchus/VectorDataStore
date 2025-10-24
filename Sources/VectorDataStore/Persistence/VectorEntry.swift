//
//  VectorEntry.swift
//  VectorDataStore
//
//  Created by Nicholas Reich on 10/24/25.
//


import Foundation
import SwiftData

// MARK: - SwiftData Vector Entry Model ----------------------------------------

@Model
final class VectorEntry {
    @Attribute(.unique) var id: String
    var vectorData: Data // Encoded [Float]
    var metadataJSON: String // JSON-encoded metadata
    var timestamp: Date
    
    init(id: String, vectorData: Data, metadataJSON: String, timestamp: Date = Date()) {
        self.id = id
        self.vectorData = vectorData
        self.metadataJSON = metadataJSON
        self.timestamp = timestamp
    }
}
