//
//  ConnectionId.swift
//  SpacetimeDB
//
//  Represents a unique identifier for a client connection.
//

import Foundation

/// A unique identifier for a client connection to a SpacetimeDB database.
///
/// ConnectionIds are used to distinguish between multiple connections from
/// the same Identity. They are session-scoped and only have meaning within
/// a single connection session.
public struct ConnectionId: Hashable, Sendable {
    /// The underlying 64-bit value.
    public var value: UInt64
    
    /// Create a ConnectionId from a UInt64 value.
    public init(_ value: UInt64) {
        self.value = value
    }
    
    /// Create a zero connection ID.
    public static var zero: ConnectionId {
        ConnectionId(0)
    }
    
    /// Check if this is the zero connection ID.
    public var isZero: Bool {
        value == 0
    }
}

// MARK: - BSATN

extension ConnectionId: BSATNCodable {
    public func encode(to encoder: inout BSATNEncoder) throws {
        encoder.encode(value)
    }
    
    public init(from decoder: inout BSATNDecoder) throws {
        self.value = try decoder.decode(UInt64.self)
    }
}

// MARK: - CustomStringConvertible

extension ConnectionId: CustomStringConvertible {
    public var description: String {
        String(value)
    }
}

// MARK: - Codable (JSON)

extension ConnectionId: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        self.value = try container.decode(UInt64.self)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(value)
    }
}

// MARK: - ExpressibleByIntegerLiteral

extension ConnectionId: ExpressibleByIntegerLiteral {
    public init(integerLiteral value: UInt64) {
        self.init(value)
    }
}
