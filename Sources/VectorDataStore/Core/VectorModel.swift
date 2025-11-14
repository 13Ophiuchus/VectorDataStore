//
//  VectorModel.swift
//  
//
//  Created by Nicholas Reich on 11/11/25.
//


public protocol VectorModel: Sendable, Identifiable where ID: StringProtocol {
    var embeddingText: String { get }
    init?(metadata: [String: String])
}