//
//  VectorEntry.swift
//  VectorDataStore
//
//  Created by Nicholas Reich on 10/24/25.
//
#if canImport(SwiftData)

import Foundation
import SwiftData

@Model
final class VectorEntry {
    @Attribute(.unique) var id: String
    var vectorData: Data
    var metadataJSON: String
    var timestamp: Date

    init(id: String, vectorData: Data, metadataJSON: String, timestamp: Date = Date()) {
        self.id = id
        self.vectorData = vectorData
        self.metadataJSON = metadataJSON
        self.timestamp = timestamp
    }
}

#endif
