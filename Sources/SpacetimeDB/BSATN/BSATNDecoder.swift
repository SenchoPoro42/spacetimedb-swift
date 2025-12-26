//
//  BSATNDecoder.swift
//  SpacetimeDB
//
//  Streaming decoder for BSATN binary format.
//  All multi-byte values are decoded from little-endian byte order.
//

import Foundation

/// Decodes values from BSATN binary format.
///
/// BSATN decoding rules:
/// - All integers: little-endian
/// - bool: 1 byte (0x00 = false, 0x01 = true)
/// - String: u32 length prefix + UTF-8 bytes
/// - Array: u32 length prefix + concatenated element encodings
/// - ProductValue (struct): concatenated field encodings (no field names)
/// - SumValue (enum): u8 tag + variant data
/// - Option<T>: tag 0 = None, tag 1 = Some(T)
public struct BSATNDecoder {
    
    /// The data being decoded.
    private var data: Data
    
    /// Current read position.
    private var position: Data.Index
    
    /// Create a decoder from binary data.
    public init(data: Data) {
        self.data = data
        self.position = data.startIndex
    }
    
    /// Number of bytes remaining to be read.
    public var remainingBytes: Int {
        data.endIndex - position
    }
    
    /// Whether there is more data to read.
    public var hasMoreData: Bool {
        position < data.endIndex
    }
    
    // MARK: - Raw Data Operations
    
    /// Read exactly `count` bytes from the decoder.
    public mutating func readBytes(_ count: Int) throws -> Data {
        guard remainingBytes >= count else {
            throw BSATNDecodingError.unexpectedEndOfData
        }
        
        let endPosition = data.index(position, offsetBy: count)
        let bytes = data[position..<endPosition]
        position = endPosition
        return Data(bytes)
    }
    
    /// Read a single byte.
    public mutating func readByte() throws -> UInt8 {
        guard remainingBytes >= 1 else {
            throw BSATNDecodingError.unexpectedEndOfData
        }
        
        let byte = data[position]
        position = data.index(after: position)
        return byte
    }
    
    /// Peek at the next byte without consuming it.
    public func peekByte() throws -> UInt8 {
        guard remainingBytes >= 1 else {
            throw BSATNDecodingError.unexpectedEndOfData
        }
        return data[position]
    }
    
    // MARK: - Primitive Decoding (Little-Endian)
    
    /// Decode a boolean value.
    /// BSATN: 1 byte, 0x00 = false, 0x01 = true
    public mutating func decode(_ type: Bool.Type) throws -> Bool {
        let byte = try readByte()
        switch byte {
        case 0x00: return false
        case 0x01: return true
        default:
            throw BSATNDecodingError.invalidData("Invalid boolean value: \(byte)")
        }
    }
    
    /// Decode an unsigned 8-bit integer.
    public mutating func decode(_ type: UInt8.Type) throws -> UInt8 {
        return try readByte()
    }
    
    /// Decode a signed 8-bit integer.
    public mutating func decode(_ type: Int8.Type) throws -> Int8 {
        let byte = try readByte()
        return Int8(bitPattern: byte)
    }
    
    /// Decode an unsigned 16-bit integer (little-endian).
    public mutating func decode(_ type: UInt16.Type) throws -> UInt16 {
        let bytes = try readBytes(2)
        return bytes.withUnsafeBytes { ptr in
            UInt16(littleEndian: ptr.load(as: UInt16.self))
        }
    }
    
    /// Decode a signed 16-bit integer (little-endian).
    public mutating func decode(_ type: Int16.Type) throws -> Int16 {
        let bytes = try readBytes(2)
        return bytes.withUnsafeBytes { ptr in
            Int16(littleEndian: ptr.load(as: Int16.self))
        }
    }
    
    /// Decode an unsigned 32-bit integer (little-endian).
    public mutating func decode(_ type: UInt32.Type) throws -> UInt32 {
        let bytes = try readBytes(4)
        return bytes.withUnsafeBytes { ptr in
            UInt32(littleEndian: ptr.load(as: UInt32.self))
        }
    }
    
    /// Decode a signed 32-bit integer (little-endian).
    public mutating func decode(_ type: Int32.Type) throws -> Int32 {
        let bytes = try readBytes(4)
        return bytes.withUnsafeBytes { ptr in
            Int32(littleEndian: ptr.load(as: Int32.self))
        }
    }
    
    /// Decode an unsigned 64-bit integer (little-endian).
    public mutating func decode(_ type: UInt64.Type) throws -> UInt64 {
        let bytes = try readBytes(8)
        return bytes.withUnsafeBytes { ptr in
            UInt64(littleEndian: ptr.load(as: UInt64.self))
        }
    }
    
    /// Decode a signed 64-bit integer (little-endian).
    public mutating func decode(_ type: Int64.Type) throws -> Int64 {
        let bytes = try readBytes(8)
        return bytes.withUnsafeBytes { ptr in
            Int64(littleEndian: ptr.load(as: Int64.self))
        }
    }
    
    /// Decode a 32-bit floating point number (IEEE 754, little-endian).
    public mutating func decode(_ type: Float.Type) throws -> Float {
        let bytes = try readBytes(4)
        let bitPattern = bytes.withUnsafeBytes { ptr in
            UInt32(littleEndian: ptr.load(as: UInt32.self))
        }
        return Float(bitPattern: bitPattern)
    }
    
    /// Decode a 64-bit floating point number (IEEE 754, little-endian).
    public mutating func decode(_ type: Double.Type) throws -> Double {
        let bytes = try readBytes(8)
        let bitPattern = bytes.withUnsafeBytes { ptr in
            UInt64(littleEndian: ptr.load(as: UInt64.self))
        }
        return Double(bitPattern: bitPattern)
    }
    
    // MARK: - String Decoding
    
    /// Decode a string.
    /// BSATN: u32 length prefix + UTF-8 bytes
    public mutating func decode(_ type: String.Type) throws -> String {
        let length = try decode(UInt32.self)
        let utf8Data = try readBytes(Int(length))
        
        guard let string = String(data: utf8Data, encoding: .utf8) else {
            throw BSATNDecodingError.invalidStringEncoding
        }
        
        return string
    }
    
    // MARK: - Array Decoding
    
    /// Decode an array of decodable values.
    /// BSATN: u32 length prefix + concatenated element encodings
    public mutating func decode<T: BSATNDecodable>(_ type: [T].Type) throws -> [T] {
        let count = try decode(UInt32.self)
        var array = [T]()
        array.reserveCapacity(Int(count))
        
        for _ in 0..<count {
            let element = try T(from: &self)
            array.append(element)
        }
        
        return array
    }
    
    // MARK: - Optional Decoding
    
    /// Decode an optional value.
    /// BSATN: tag 0 = None (no data), tag 1 = Some(T)
    public mutating func decode<T: BSATNDecodable>(_ type: T?.Type) throws -> T? {
        let tag = try decode(UInt8.self)
        switch tag {
        case 0:
            return nil
        case 1:
            return try T(from: &self)
        default:
            throw BSATNDecodingError.invalidData("Invalid optional tag: \(tag)")
        }
    }
    
    // MARK: - Raw Bytes Decoding
    
    /// Decode raw bytes (Data).
    /// BSATN: u32 length prefix + raw bytes
    public mutating func decode(_ type: Data.Type) throws -> Data {
        let length = try decode(UInt32.self)
        return try readBytes(Int(length))
    }
    
    // MARK: - Convenience
    
    /// Decode a value from binary data.
    public static func decode<T: BSATNDecodable>(_ type: T.Type, from data: Data) throws -> T {
        var decoder = BSATNDecoder(data: data)
        return try T(from: &decoder)
    }
}
