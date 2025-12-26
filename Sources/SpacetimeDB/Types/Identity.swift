//
//  Identity.swift
//  SpacetimeDB
//
//  Represents a SpacetimeDB user identity.
//  In BSATN, an Identity is represented as a LITTLE-ENDIAN number 32 bytes long.
//

import Foundation

/// A unique identifier for a user or entity in SpacetimeDB.
///
/// In BSATN, an Identity is represented as a LITTLE-ENDIAN number 32 bytes long.
/// When displayed as a hexadecimal string, it follows big-endian convention
/// (most significant byte first), which is the standard way of writing hex numbers.
public struct Identity: Hashable, Sendable {
    /// The underlying 256-bit value.
    private var value: UInt256
    
    /// Create an Identity from a UInt256 value.
    public init(_ value: UInt256) {
        self.value = value
    }
    
    /// Create a zero identity.
    public static var zero: Identity {
        Identity(UInt256.zero)
    }
    
    /// Check if this is the zero identity.
    public var isZero: Bool {
        value.isZero
    }
    
    /// Create an Identity from a little-endian byte array.
    ///
    /// Use this when you have raw BSATN-encoded bytes.
    public init(littleEndianBytes bytes: Data) {
        precondition(bytes.count == 32, "Identity requires exactly 32 bytes")
        self.value = UInt256(littleEndianBytes: bytes)
    }
    
    /// Create an Identity from a big-endian byte array.
    ///
    /// Use this when parsing a hexadecimal string representation.
    /// The standard way of writing hexadecimal numbers follows big-endian convention.
    public init(bigEndianBytes bytes: Data) {
        precondition(bytes.count == 32, "Identity requires exactly 32 bytes")
        self.value = UInt256(bigEndianBytes: bytes)
    }
    
    /// Get the raw bytes in little-endian order (for BSATN encoding).
    public var littleEndianBytes: Data {
        value.littleEndianBytes
    }
    
    /// Get the raw bytes in big-endian order (for hex string display).
    public var bigEndianBytes: Data {
        value.bigEndianBytes
    }
    
    /// Create an Identity from a hexadecimal string.
    ///
    /// The string should be 64 hexadecimal characters, optionally prefixed with "0x".
    /// Hexadecimal strings follow big-endian convention (MSB first).
    public init?(hexString: String) {
        guard let value = UInt256(hexString: hexString) else {
            return nil
        }
        self.value = value
    }
    
    /// Get the hexadecimal string representation (64 characters).
    ///
    /// Returns a lowercase hex string without the "0x" prefix.
    public var hexString: String {
        value.hexString
    }
    
    /// Get a shortened hex string for display purposes.
    ///
    /// Returns the first 16 characters of the hex representation.
    public var shortHexString: String {
        String(hexString.prefix(16))
    }
    
    /// Check equality with another identity.
    public func isEqual(to other: Identity) -> Bool {
        self == other
    }
}

// MARK: - BSATN

extension Identity: BSATNCodable {
    public func encode(to encoder: inout BSATNEncoder) throws {
        try value.encode(to: &encoder)
    }
    
    public init(from decoder: inout BSATNDecoder) throws {
        self.value = try UInt256(from: &decoder)
    }
}

// MARK: - CustomStringConvertible

extension Identity: CustomStringConvertible {
    public var description: String {
        hexString
    }
}

// MARK: - CustomDebugStringConvertible

extension Identity: CustomDebugStringConvertible {
    public var debugDescription: String {
        "Identity(\(shortHexString)...)"
    }
}

// MARK: - LosslessStringConvertible

extension Identity: LosslessStringConvertible {
    public init?(_ description: String) {
        self.init(hexString: description)
    }
}

// MARK: - Codable (JSON)

extension Identity: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let hexString = try container.decode(String.self)
        guard let identity = Identity(hexString: hexString) else {
            throw DecodingError.dataCorrupted(
                DecodingError.Context(
                    codingPath: decoder.codingPath,
                    debugDescription: "Invalid identity hex string: \(hexString)"
                )
            )
        }
        self = identity
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(hexString)
    }
}
