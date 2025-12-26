//
//  UInt256.swift
//  SpacetimeDB
//
//  256-bit unsigned integer for BSATN compatibility.
//  Used by Identity type (32 bytes).
//

import Foundation

/// A 256-bit unsigned integer.
///
/// In BSATN, u256 is encoded as 32 bytes in little-endian order.
/// The bytes are stored from least significant to most significant.
public struct UInt256: Sendable {
    /// The raw bytes (32 bytes, stored in little-endian order).
    public var bytes: (
        UInt64, UInt64, UInt64, UInt64  // 4 x 64-bit = 256-bit
    )
    
    /// Create a UInt256 from four 64-bit parts (little-endian order: b0 is LSB).
    public init(b0: UInt64, b1: UInt64, b2: UInt64, b3: UInt64) {
        self.bytes = (b0, b1, b2, b3)
    }
    
    /// Create a UInt256 from a single UInt64 value.
    public init(_ value: UInt64) {
        self.bytes = (value, 0, 0, 0)
    }
    
    /// Create a zero value.
    public static var zero: UInt256 {
        UInt256(b0: 0, b1: 0, b2: 0, b3: 0)
    }
    
    /// Create the maximum value.
    public static var max: UInt256 {
        UInt256(b0: .max, b1: .max, b2: .max, b3: .max)
    }
    
    /// Create from raw bytes (32 bytes, little-endian).
    public init(littleEndianBytes data: Data) {
        precondition(data.count == 32, "UInt256 requires exactly 32 bytes")
        
        self.bytes = data.withUnsafeBytes { ptr in
            (
                UInt64(littleEndian: ptr.load(fromByteOffset: 0, as: UInt64.self)),
                UInt64(littleEndian: ptr.load(fromByteOffset: 8, as: UInt64.self)),
                UInt64(littleEndian: ptr.load(fromByteOffset: 16, as: UInt64.self)),
                UInt64(littleEndian: ptr.load(fromByteOffset: 24, as: UInt64.self))
            )
        }
    }
    
    /// Create from raw bytes (32 bytes, big-endian — for hex string parsing).
    public init(bigEndianBytes data: Data) {
        precondition(data.count == 32, "UInt256 requires exactly 32 bytes")
        
        // Big-endian means MSB first, so we need to reverse the order
        self.bytes = data.withUnsafeBytes { ptr in
            (
                UInt64(bigEndian: ptr.load(fromByteOffset: 24, as: UInt64.self)),
                UInt64(bigEndian: ptr.load(fromByteOffset: 16, as: UInt64.self)),
                UInt64(bigEndian: ptr.load(fromByteOffset: 8, as: UInt64.self)),
                UInt64(bigEndian: ptr.load(fromByteOffset: 0, as: UInt64.self))
            )
        }
    }
    
    /// Get the raw bytes (32 bytes, little-endian).
    public var littleEndianBytes: Data {
        var data = Data(capacity: 32)
        withUnsafeBytes(of: bytes.0.littleEndian) { data.append(contentsOf: $0) }
        withUnsafeBytes(of: bytes.1.littleEndian) { data.append(contentsOf: $0) }
        withUnsafeBytes(of: bytes.2.littleEndian) { data.append(contentsOf: $0) }
        withUnsafeBytes(of: bytes.3.littleEndian) { data.append(contentsOf: $0) }
        return data
    }
    
    /// Get the raw bytes (32 bytes, big-endian — for hex string output).
    public var bigEndianBytes: Data {
        var data = Data(capacity: 32)
        withUnsafeBytes(of: bytes.3.bigEndian) { data.append(contentsOf: $0) }
        withUnsafeBytes(of: bytes.2.bigEndian) { data.append(contentsOf: $0) }
        withUnsafeBytes(of: bytes.1.bigEndian) { data.append(contentsOf: $0) }
        withUnsafeBytes(of: bytes.0.bigEndian) { data.append(contentsOf: $0) }
        return data
    }
    
    /// Check if this value is zero.
    public var isZero: Bool {
        bytes.0 == 0 && bytes.1 == 0 && bytes.2 == 0 && bytes.3 == 0
    }
}

// MARK: - BSATN

extension UInt256: BSATNCodable {
    public func encode(to encoder: inout BSATNEncoder) throws {
        // Little-endian: encode from LSB to MSB
        encoder.encode(bytes.0)
        encoder.encode(bytes.1)
        encoder.encode(bytes.2)
        encoder.encode(bytes.3)
    }
    
    public init(from decoder: inout BSATNDecoder) throws {
        let b0 = try decoder.decode(UInt64.self)
        let b1 = try decoder.decode(UInt64.self)
        let b2 = try decoder.decode(UInt64.self)
        let b3 = try decoder.decode(UInt64.self)
        self.init(b0: b0, b1: b1, b2: b2, b3: b3)
    }
}

// MARK: - Hex String

extension UInt256 {
    /// Create from a hexadecimal string (64 characters, big-endian convention).
    public init?(hexString: String) {
        var hex = hexString
        if hex.hasPrefix("0x") || hex.hasPrefix("0X") {
            hex = String(hex.dropFirst(2))
        }
        
        guard hex.count == 64 else { return nil }
        
        var bytes = Data(capacity: 32)
        var index = hex.startIndex
        
        for _ in 0..<32 {
            let nextIndex = hex.index(index, offsetBy: 2)
            guard let byte = UInt8(hex[index..<nextIndex], radix: 16) else {
                return nil
            }
            bytes.append(byte)
            index = nextIndex
        }
        
        self.init(bigEndianBytes: bytes)
    }
    
    /// Get the hexadecimal string representation (64 characters, big-endian convention).
    public var hexString: String {
        bigEndianBytes.map { String(format: "%02x", $0) }.joined()
    }
}

// MARK: - CustomStringConvertible

extension UInt256: CustomStringConvertible {
    public var description: String {
        hexString
    }
}

// MARK: - Equatable & Hashable

extension UInt256: Equatable {
    public static func == (lhs: UInt256, rhs: UInt256) -> Bool {
        lhs.bytes == rhs.bytes
    }
}

extension UInt256: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(bytes.0)
        hasher.combine(bytes.1)
        hasher.combine(bytes.2)
        hasher.combine(bytes.3)
    }
}

// MARK: - ExpressibleByIntegerLiteral

extension UInt256: ExpressibleByIntegerLiteral {
    public init(integerLiteral value: UInt64) {
        self.init(value)
    }
}
