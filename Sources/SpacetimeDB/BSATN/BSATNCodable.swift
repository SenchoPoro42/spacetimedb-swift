//
//  BSATNCodable.swift
//  SpacetimeDB
//
//  BSATN (Binary Spacetime Algebraic Type Notation) protocol definitions.
//  https://spacetimedb.com/docs/bsatn
//

import Foundation

// MARK: - Protocols

/// A type that can encode itself to BSATN binary format.
public protocol BSATNEncodable {
    /// Encode this value to the given encoder.
    func encode(to encoder: inout BSATNEncoder) throws
}

/// A type that can decode itself from BSATN binary format.
public protocol BSATNDecodable {
    /// Decode a value from the given decoder.
    init(from decoder: inout BSATNDecoder) throws
}

/// A type that can both encode and decode itself in BSATN format.
public typealias BSATNCodable = BSATNEncodable & BSATNDecodable

// MARK: - Errors

/// Errors that can occur during BSATN encoding.
public enum BSATNEncodingError: Error, LocalizedError {
    case invalidStringEncoding(String)
    case overflow(String)
    
    public var errorDescription: String? {
        switch self {
        case .invalidStringEncoding(let message):
            return "BSATN encoding error: \(message)"
        case .overflow(let message):
            return "BSATN encoding overflow: \(message)"
        }
    }
}

/// Errors that can occur during BSATN decoding.
public enum BSATNDecodingError: Error, LocalizedError {
    case unexpectedEndOfData
    case invalidData(String)
    case invalidStringEncoding
    case typeMismatch(expected: String, actual: String)
    case invalidEnumTag(tag: UInt8, typeName: String)
    
    public var errorDescription: String? {
        switch self {
        case .unexpectedEndOfData:
            return "BSATN decoding error: Unexpected end of data"
        case .invalidData(let message):
            return "BSATN decoding error: \(message)"
        case .invalidStringEncoding:
            return "BSATN decoding error: Invalid UTF-8 string encoding"
        case .typeMismatch(let expected, let actual):
            return "BSATN decoding error: Type mismatch - expected \(expected), got \(actual)"
        case .invalidEnumTag(let tag, let typeName):
            return "BSATN decoding error: Invalid enum tag \(tag) for type \(typeName)"
        }
    }
}

// MARK: - Encoding Helpers

/// Helper to encode sum types (enums with associated values).
/// BSATN encodes sum types as: u8 tag + variant data
public struct SumTypeEncoder {
    public var tag: UInt8
    public var encoder: BSATNEncoder
    
    public init(tag: UInt8) {
        self.tag = tag
        self.encoder = BSATNEncoder()
    }
    
    /// Encode the sum type to a parent encoder.
    public func encode(to parent: inout BSATNEncoder) throws {
        try tag.encode(to: &parent)
        parent.appendRaw(encoder.data)
    }
}

/// Helper to decode sum types (enums with associated values).
public struct SumTypeDecoder {
    public let tag: UInt8
    public var decoder: BSATNDecoder
    
    public init(from decoder: inout BSATNDecoder) throws {
        self.tag = try UInt8(from: &decoder)
        self.decoder = decoder
    }
    
    /// Consume bytes from the parent decoder after decoding variant data.
    public mutating func finalize(in parent: inout BSATNDecoder) {
        parent = decoder
    }
}
