//
//  UInt128.swift
//  SpacetimeDB
//
//  128-bit unsigned integer for BSATN compatibility.
//  Stored as two 64-bit values (low, high) in little-endian order.
//

import Foundation

/// A 128-bit unsigned integer.
///
/// In BSATN, u128 is encoded as 16 bytes in little-endian order.
/// This means the low 64 bits come first, followed by the high 64 bits.
public struct UInt128: Hashable, Sendable {
    /// The low 64 bits.
    public var low: UInt64
    
    /// The high 64 bits.
    public var high: UInt64
    
    /// Create a UInt128 from low and high 64-bit parts.
    public init(low: UInt64, high: UInt64) {
        self.low = low
        self.high = high
    }
    
    /// Create a UInt128 from a single UInt64 value.
    public init(_ value: UInt64) {
        self.low = value
        self.high = 0
    }
    
    /// Create a zero value.
    public static var zero: UInt128 {
        UInt128(low: 0, high: 0)
    }
    
    /// Create the maximum value.
    public static var max: UInt128 {
        UInt128(low: .max, high: .max)
    }
    
    /// Create from raw bytes (16 bytes, little-endian).
    public init(littleEndianBytes bytes: Data) {
        precondition(bytes.count == 16, "UInt128 requires exactly 16 bytes")
        
        let low = bytes.withUnsafeBytes { ptr in
            UInt64(littleEndian: ptr.load(fromByteOffset: 0, as: UInt64.self))
        }
        let high = bytes.withUnsafeBytes { ptr in
            UInt64(littleEndian: ptr.load(fromByteOffset: 8, as: UInt64.self))
        }
        
        self.low = low
        self.high = high
    }
    
    /// Get the raw bytes (16 bytes, little-endian).
    public var littleEndianBytes: Data {
        var data = Data(capacity: 16)
        withUnsafeBytes(of: low.littleEndian) { data.append(contentsOf: $0) }
        withUnsafeBytes(of: high.littleEndian) { data.append(contentsOf: $0) }
        return data
    }
}

// MARK: - BSATN

extension UInt128: BSATNCodable {
    public func encode(to encoder: inout BSATNEncoder) throws {
        // Little-endian: low bytes first, then high bytes
        encoder.encode(low)
        encoder.encode(high)
    }
    
    public init(from decoder: inout BSATNDecoder) throws {
        // Little-endian: low bytes first, then high bytes
        let low = try decoder.decode(UInt64.self)
        let high = try decoder.decode(UInt64.self)
        self.init(low: low, high: high)
    }
}

// MARK: - CustomStringConvertible

extension UInt128: CustomStringConvertible {
    public var description: String {
        if high == 0 {
            return String(low)
        }
        // For full 128-bit display, use hex
        return String(format: "0x%016llx%016llx", high, low)
    }
}

// MARK: - Comparable

extension UInt128: Comparable {
    public static func < (lhs: UInt128, rhs: UInt128) -> Bool {
        if lhs.high != rhs.high {
            return lhs.high < rhs.high
        }
        return lhs.low < rhs.low
    }
}

// MARK: - Equatable

extension UInt128: Equatable {
    public static func == (lhs: UInt128, rhs: UInt128) -> Bool {
        lhs.low == rhs.low && lhs.high == rhs.high
    }
}

// MARK: - ExpressibleByIntegerLiteral

extension UInt128: ExpressibleByIntegerLiteral {
    public init(integerLiteral value: UInt64) {
        self.init(value)
    }
}
