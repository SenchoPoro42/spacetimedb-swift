//
//  BSATNEncoder.swift
//  SpacetimeDB
//
//  Streaming encoder for BSATN binary format.
//  All multi-byte values are encoded in little-endian byte order.
//

import Foundation

/// Encodes values to BSATN binary format.
///
/// BSATN encoding rules:
/// - All integers: little-endian
/// - bool: 1 byte (0x00 = false, 0x01 = true)
/// - String: u32 length prefix + UTF-8 bytes
/// - Array: u32 length prefix + concatenated element encodings
/// - ProductValue (struct): concatenated field encodings (no field names)
/// - SumValue (enum): u8 tag + variant data
/// - Option<T>: tag 0 = None, tag 1 = Some(T)
public struct BSATNEncoder {
    
    /// The encoded binary data.
    public private(set) var data: Data
    
    /// Create a new encoder with empty data.
    public init() {
        self.data = Data()
    }
    
    /// Create a new encoder with pre-allocated capacity.
    public init(capacity: Int) {
        self.data = Data(capacity: capacity)
    }
    
    // MARK: - Raw Data Operations
    
    /// Append raw bytes to the output.
    public mutating func appendRaw(_ bytes: Data) {
        data.append(bytes)
    }
    
    /// Append raw bytes from a buffer pointer.
    public mutating func appendRaw(_ bytes: UnsafeRawBufferPointer) {
        data.append(contentsOf: bytes)
    }
    
    /// Append a single byte.
    public mutating func appendByte(_ byte: UInt8) {
        data.append(byte)
    }
    
    // MARK: - Primitive Encoding (Little-Endian)
    
    /// Encode a boolean value.
    /// BSATN: 1 byte, 0x00 = false, 0x01 = true
    public mutating func encode(_ value: Bool) {
        data.append(value ? 0x01 : 0x00)
    }
    
    /// Encode an unsigned 8-bit integer.
    public mutating func encode(_ value: UInt8) {
        data.append(value)
    }
    
    /// Encode a signed 8-bit integer.
    public mutating func encode(_ value: Int8) {
        data.append(UInt8(bitPattern: value))
    }
    
    /// Encode an unsigned 16-bit integer (little-endian).
    public mutating func encode(_ value: UInt16) {
        withUnsafeBytes(of: value.littleEndian) { bytes in
            data.append(contentsOf: bytes)
        }
    }
    
    /// Encode a signed 16-bit integer (little-endian).
    public mutating func encode(_ value: Int16) {
        withUnsafeBytes(of: value.littleEndian) { bytes in
            data.append(contentsOf: bytes)
        }
    }
    
    /// Encode an unsigned 32-bit integer (little-endian).
    public mutating func encode(_ value: UInt32) {
        withUnsafeBytes(of: value.littleEndian) { bytes in
            data.append(contentsOf: bytes)
        }
    }
    
    /// Encode a signed 32-bit integer (little-endian).
    public mutating func encode(_ value: Int32) {
        withUnsafeBytes(of: value.littleEndian) { bytes in
            data.append(contentsOf: bytes)
        }
    }
    
    /// Encode an unsigned 64-bit integer (little-endian).
    public mutating func encode(_ value: UInt64) {
        withUnsafeBytes(of: value.littleEndian) { bytes in
            data.append(contentsOf: bytes)
        }
    }
    
    /// Encode a signed 64-bit integer (little-endian).
    public mutating func encode(_ value: Int64) {
        withUnsafeBytes(of: value.littleEndian) { bytes in
            data.append(contentsOf: bytes)
        }
    }
    
    /// Encode a 32-bit floating point number (IEEE 754, little-endian).
    public mutating func encode(_ value: Float) {
        withUnsafeBytes(of: value.bitPattern.littleEndian) { bytes in
            data.append(contentsOf: bytes)
        }
    }
    
    /// Encode a 64-bit floating point number (IEEE 754, little-endian).
    public mutating func encode(_ value: Double) {
        withUnsafeBytes(of: value.bitPattern.littleEndian) { bytes in
            data.append(contentsOf: bytes)
        }
    }
    
    // MARK: - String Encoding
    
    /// Encode a string.
    /// BSATN: u32 length prefix + UTF-8 bytes
    public mutating func encode(_ value: String) throws {
        guard let utf8Data = value.data(using: .utf8) else {
            throw BSATNEncodingError.invalidStringEncoding("Failed to encode string as UTF-8")
        }
        
        guard utf8Data.count <= UInt32.max else {
            throw BSATNEncodingError.overflow("String too long: \(utf8Data.count) bytes exceeds u32 max")
        }
        
        // Length prefix (u32)
        encode(UInt32(utf8Data.count))
        // UTF-8 bytes
        data.append(utf8Data)
    }
    
    // MARK: - Array Encoding
    
    /// Encode an array of encodable values.
    /// BSATN: u32 length prefix + concatenated element encodings
    public mutating func encode<T: BSATNEncodable>(_ array: [T]) throws {
        guard array.count <= UInt32.max else {
            throw BSATNEncodingError.overflow("Array too long: \(array.count) elements exceeds u32 max")
        }
        
        // Length prefix (u32)
        encode(UInt32(array.count))
        
        // Elements
        for element in array {
            try element.encode(to: &self)
        }
    }
    
    // MARK: - Optional Encoding
    
    /// Encode an optional value.
    /// BSATN: tag 0 = None (no data), tag 1 = Some(T)
    public mutating func encode<T: BSATNEncodable>(_ optional: T?) throws {
        if let value = optional {
            encode(UInt8(1))  // Some tag
            try value.encode(to: &self)
        } else {
            encode(UInt8(0))  // None tag
        }
    }
    
    // MARK: - Raw Bytes Encoding
    
    /// Encode raw bytes (Data).
    /// BSATN: u32 length prefix + raw bytes
    public mutating func encode(_ value: Data) throws {
        guard value.count <= UInt32.max else {
            throw BSATNEncodingError.overflow("Data too long: \(value.count) bytes exceeds u32 max")
        }
        
        // Length prefix (u32)
        encode(UInt32(value.count))
        // Raw bytes
        data.append(value)
    }
    
    // MARK: - Convenience
    
    /// Encode a value and return the encoded data.
    public static func encode<T: BSATNEncodable>(_ value: T) throws -> Data {
        var encoder = BSATNEncoder()
        try value.encode(to: &encoder)
        return encoder.data
    }
    
    /// Reset the encoder for reuse.
    public mutating func reset() {
        data.removeAll(keepingCapacity: true)
    }
}
