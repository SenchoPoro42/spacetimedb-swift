//
//  SpacetimeDB.swift
//  SpacetimeDB
//
//  Main module exports for the SpacetimeDB Swift SDK.
//

import Foundation

// MARK: - Module Version

/// The version of the SpacetimeDB Swift SDK.
public let spacetimeDBSDKVersion = "0.1.0"

// MARK: - Re-exports

// All public types are automatically exported from their respective files.
// This file serves as documentation of what's available and provides
// any top-level utility functions.

// BSATN Serialization:
// - BSATNEncoder: Encode values to binary format
// - BSATNDecoder: Decode values from binary format
// - BSATNEncodable, BSATNDecodable, BSATNCodable: Protocol conformance
// - BSATNEncodingError, BSATNDecodingError: Error types

// SpacetimeDB Types:
// - Identity: 256-bit user identity
// - ConnectionId: 64-bit connection identifier
// - Timestamp: Microsecond-precision timestamp
// - TimeDelta: Duration in microseconds
// - UInt128: 128-bit unsigned integer
// - UInt256: 256-bit unsigned integer

// MARK: - Convenience

/// Encode a value to BSATN binary format.
public func bsatnEncode<T: BSATNEncodable>(_ value: T) throws -> Data {
    try BSATNEncoder.encode(value)
}

/// Decode a value from BSATN binary format.
public func bsatnDecode<T: BSATNDecodable>(_ type: T.Type, from data: Data) throws -> T {
    try BSATNDecoder.decode(type, from: data)
}
