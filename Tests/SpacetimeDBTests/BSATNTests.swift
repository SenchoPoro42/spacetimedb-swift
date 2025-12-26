//
//  BSATNTests.swift
//  SpacetimeDBTests
//
//  Unit tests for BSATN encoding and decoding.
//

import XCTest
@testable import SpacetimeDB

final class BSATNTests: XCTestCase {
    
    // MARK: - Boolean Tests
    
    func testBoolTrue() throws {
        let original = true
        let data = try BSATNEncoder.encode(original)
        
        XCTAssertEqual(data.count, 1)
        XCTAssertEqual(data[0], 0x01)
        
        let decoded = try BSATNDecoder.decode(Bool.self, from: data)
        XCTAssertEqual(decoded, original)
    }
    
    func testBoolFalse() throws {
        let original = false
        let data = try BSATNEncoder.encode(original)
        
        XCTAssertEqual(data.count, 1)
        XCTAssertEqual(data[0], 0x00)
        
        let decoded = try BSATNDecoder.decode(Bool.self, from: data)
        XCTAssertEqual(decoded, original)
    }
    
    // MARK: - Unsigned Integer Tests
    
    func testUInt8() throws {
        let values: [UInt8] = [0, 1, 127, 128, 255]
        
        for original in values {
            let data = try BSATNEncoder.encode(original)
            XCTAssertEqual(data.count, 1)
            
            let decoded = try BSATNDecoder.decode(UInt8.self, from: data)
            XCTAssertEqual(decoded, original)
        }
    }
    
    func testUInt16() throws {
        let values: [UInt16] = [0, 1, 255, 256, 0x1234, UInt16.max]
        
        for original in values {
            let data = try BSATNEncoder.encode(original)
            XCTAssertEqual(data.count, 2)
            
            // Verify little-endian encoding
            let expectedLow = UInt8(original & 0xFF)
            let expectedHigh = UInt8((original >> 8) & 0xFF)
            XCTAssertEqual(data[0], expectedLow)
            XCTAssertEqual(data[1], expectedHigh)
            
            let decoded = try BSATNDecoder.decode(UInt16.self, from: data)
            XCTAssertEqual(decoded, original)
        }
    }
    
    func testUInt32() throws {
        let values: [UInt32] = [0, 1, 0x12345678, UInt32.max]
        
        for original in values {
            let data = try BSATNEncoder.encode(original)
            XCTAssertEqual(data.count, 4)
            
            let decoded = try BSATNDecoder.decode(UInt32.self, from: data)
            XCTAssertEqual(decoded, original)
        }
    }
    
    func testUInt64() throws {
        let values: [UInt64] = [0, 1, 0x123456789ABCDEF0, UInt64.max]
        
        for original in values {
            let data = try BSATNEncoder.encode(original)
            XCTAssertEqual(data.count, 8)
            
            let decoded = try BSATNDecoder.decode(UInt64.self, from: data)
            XCTAssertEqual(decoded, original)
        }
    }
    
    // MARK: - Signed Integer Tests
    
    func testInt8() throws {
        let values: [Int8] = [Int8.min, -1, 0, 1, Int8.max]
        
        for original in values {
            let data = try BSATNEncoder.encode(original)
            XCTAssertEqual(data.count, 1)
            
            let decoded = try BSATNDecoder.decode(Int8.self, from: data)
            XCTAssertEqual(decoded, original)
        }
    }
    
    func testInt16() throws {
        let values: [Int16] = [Int16.min, -1, 0, 1, Int16.max]
        
        for original in values {
            let data = try BSATNEncoder.encode(original)
            XCTAssertEqual(data.count, 2)
            
            let decoded = try BSATNDecoder.decode(Int16.self, from: data)
            XCTAssertEqual(decoded, original)
        }
    }
    
    func testInt32() throws {
        let values: [Int32] = [Int32.min, -1, 0, 1, Int32.max]
        
        for original in values {
            let data = try BSATNEncoder.encode(original)
            XCTAssertEqual(data.count, 4)
            
            let decoded = try BSATNDecoder.decode(Int32.self, from: data)
            XCTAssertEqual(decoded, original)
        }
    }
    
    func testInt64() throws {
        let values: [Int64] = [Int64.min, -1, 0, 1, Int64.max]
        
        for original in values {
            let data = try BSATNEncoder.encode(original)
            XCTAssertEqual(data.count, 8)
            
            let decoded = try BSATNDecoder.decode(Int64.self, from: data)
            XCTAssertEqual(decoded, original)
        }
    }
    
    // MARK: - Floating Point Tests
    
    func testFloat() throws {
        let values: [Float] = [0.0, 1.0, -1.0, Float.pi, Float.greatestFiniteMagnitude]
        
        for original in values {
            let data = try BSATNEncoder.encode(original)
            XCTAssertEqual(data.count, 4)
            
            let decoded = try BSATNDecoder.decode(Float.self, from: data)
            XCTAssertEqual(decoded, original)
        }
    }
    
    func testDouble() throws {
        let values: [Double] = [0.0, 1.0, -1.0, Double.pi, Double.greatestFiniteMagnitude]
        
        for original in values {
            let data = try BSATNEncoder.encode(original)
            XCTAssertEqual(data.count, 8)
            
            let decoded = try BSATNDecoder.decode(Double.self, from: data)
            XCTAssertEqual(decoded, original)
        }
    }
    
    // MARK: - String Tests
    
    func testEmptyString() throws {
        let original = ""
        let data = try BSATNEncoder.encode(original)
        
        // Should be 4 bytes (u32 length = 0) + 0 content bytes
        XCTAssertEqual(data.count, 4)
        
        let decoded = try BSATNDecoder.decode(String.self, from: data)
        XCTAssertEqual(decoded, original)
    }
    
    func testAsciiString() throws {
        let original = "Hello, World!"
        let data = try BSATNEncoder.encode(original)
        
        // 4 bytes length + 13 bytes content
        XCTAssertEqual(data.count, 4 + 13)
        
        let decoded = try BSATNDecoder.decode(String.self, from: data)
        XCTAssertEqual(decoded, original)
    }
    
    func testUnicodeString() throws {
        let original = "Hello, 世界! 🚀"
        let data = try BSATNEncoder.encode(original)
        
        let decoded = try BSATNDecoder.decode(String.self, from: data)
        XCTAssertEqual(decoded, original)
    }
    
    // MARK: - Array Tests
    
    func testEmptyArray() throws {
        let original: [Int32] = []
        let data = try BSATNEncoder.encode(original)
        
        // Should be 4 bytes (u32 length = 0)
        XCTAssertEqual(data.count, 4)
        
        let decoded = try BSATNDecoder.decode([Int32].self, from: data)
        XCTAssertEqual(decoded, original)
    }
    
    func testInt32Array() throws {
        let original: [Int32] = [1, 2, 3, 4, 5]
        let data = try BSATNEncoder.encode(original)
        
        // 4 bytes length + 5 * 4 bytes elements
        XCTAssertEqual(data.count, 4 + 5 * 4)
        
        let decoded = try BSATNDecoder.decode([Int32].self, from: data)
        XCTAssertEqual(decoded, original)
    }
    
    func testStringArray() throws {
        let original = ["Hello", "World"]
        let data = try BSATNEncoder.encode(original)
        
        let decoded = try BSATNDecoder.decode([String].self, from: data)
        XCTAssertEqual(decoded, original)
    }
    
    // MARK: - Optional Tests
    
    func testOptionalNone() throws {
        let original: Int32? = nil
        let data = try BSATNEncoder.encode(original)
        
        // Should be 1 byte (tag = 0)
        XCTAssertEqual(data.count, 1)
        XCTAssertEqual(data[0], 0)
        
        let decoded = try BSATNDecoder.decode(Int32?.self, from: data)
        XCTAssertNil(decoded)
    }
    
    func testOptionalSome() throws {
        let original: Int32? = 42
        let data = try BSATNEncoder.encode(original)
        
        // Should be 1 byte (tag = 1) + 4 bytes (Int32)
        XCTAssertEqual(data.count, 5)
        XCTAssertEqual(data[0], 1)
        
        let decoded = try BSATNDecoder.decode(Int32?.self, from: data)
        XCTAssertEqual(decoded, 42)
    }
    
    func testOptionalString() throws {
        let original: String? = "test"
        let data = try BSATNEncoder.encode(original)
        
        let decoded = try BSATNDecoder.decode(String?.self, from: data)
        XCTAssertEqual(decoded, "test")
    }
    
    // MARK: - UInt128 Tests
    
    func testUInt128Zero() throws {
        let original = UInt128.zero
        let data = try BSATNEncoder.encode(original)
        
        XCTAssertEqual(data.count, 16)
        
        let decoded = try BSATNDecoder.decode(UInt128.self, from: data)
        XCTAssertEqual(decoded, original)
    }
    
    func testUInt128Max() throws {
        let original = UInt128.max
        let data = try BSATNEncoder.encode(original)
        
        XCTAssertEqual(data.count, 16)
        
        let decoded = try BSATNDecoder.decode(UInt128.self, from: data)
        XCTAssertEqual(decoded, original)
    }
    
    func testUInt128LittleEndian() throws {
        // Test that low bytes come first in BSATN
        let original = UInt128(low: 0x0102030405060708, high: 0x1112131415161718)
        let data = try BSATNEncoder.encode(original)
        
        // First 8 bytes should be the low part
        XCTAssertEqual(data[0], 0x08)  // LSB of low
        XCTAssertEqual(data[7], 0x01)  // MSB of low
        
        // Next 8 bytes should be the high part
        XCTAssertEqual(data[8], 0x18)  // LSB of high
        XCTAssertEqual(data[15], 0x11) // MSB of high
        
        let decoded = try BSATNDecoder.decode(UInt128.self, from: data)
        XCTAssertEqual(decoded, original)
    }
    
    // MARK: - UInt256 Tests
    
    func testUInt256Zero() throws {
        let original = UInt256.zero
        let data = try BSATNEncoder.encode(original)
        
        XCTAssertEqual(data.count, 32)
        
        let decoded = try BSATNDecoder.decode(UInt256.self, from: data)
        XCTAssertEqual(decoded, original)
    }
    
    func testUInt256Max() throws {
        let original = UInt256.max
        let data = try BSATNEncoder.encode(original)
        
        XCTAssertEqual(data.count, 32)
        
        let decoded = try BSATNDecoder.decode(UInt256.self, from: data)
        XCTAssertEqual(decoded, original)
    }
    
    func testUInt256HexString() throws {
        let hexString = "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef"
        guard let original = UInt256(hexString: hexString) else {
            XCTFail("Failed to parse hex string")
            return
        }
        
        XCTAssertEqual(original.hexString, hexString)
        
        let data = try BSATNEncoder.encode(original)
        let decoded = try BSATNDecoder.decode(UInt256.self, from: data)
        XCTAssertEqual(decoded, original)
        XCTAssertEqual(decoded.hexString, hexString)
    }
    
    // MARK: - Identity Tests
    
    func testIdentityZero() throws {
        let original = Identity.zero
        let data = try BSATNEncoder.encode(original)
        
        XCTAssertEqual(data.count, 32)
        XCTAssertTrue(original.isZero)
        
        let decoded = try BSATNDecoder.decode(Identity.self, from: data)
        XCTAssertEqual(decoded, original)
        XCTAssertTrue(decoded.isZero)
    }
    
    func testIdentityFromHex() throws {
        let hexString = "c200d2c69b4524292b91822afac8ab016c15968ac993c28711f68c6bc40b89d5"
        guard let original = Identity(hexString: hexString) else {
            XCTFail("Failed to parse identity hex string")
            return
        }
        
        XCTAssertEqual(original.hexString, hexString)
        XCTAssertFalse(original.isZero)
        
        let data = try BSATNEncoder.encode(original)
        let decoded = try BSATNDecoder.decode(Identity.self, from: data)
        XCTAssertEqual(decoded, original)
        XCTAssertEqual(decoded.hexString, hexString)
    }
    
    func testIdentityShortHex() throws {
        let hexString = "c200d2c69b4524292b91822afac8ab016c15968ac993c28711f68c6bc40b89d5"
        guard let identity = Identity(hexString: hexString) else {
            XCTFail("Failed to parse identity hex string")
            return
        }
        
        XCTAssertEqual(identity.shortHexString, "c200d2c69b452429")
    }
    
    // MARK: - Timestamp Tests
    
    func testTimestampEpoch() throws {
        let original = Timestamp.epoch
        let data = try BSATNEncoder.encode(original)
        
        XCTAssertEqual(data.count, 8)
        XCTAssertEqual(original.microseconds, 0)
        
        let decoded = try BSATNDecoder.decode(Timestamp.self, from: data)
        XCTAssertEqual(decoded, original)
    }
    
    func testTimestampFromDate() throws {
        let date = Date(timeIntervalSince1970: 1703620800.123456) // 2023-12-26 00:00:00.123456 UTC
        let original = Timestamp(date)
        
        let data = try BSATNEncoder.encode(original)
        let decoded = try BSATNDecoder.decode(Timestamp.self, from: data)
        
        XCTAssertEqual(decoded.microseconds, original.microseconds)
        
        // Check roundtrip to Date (with microsecond precision)
        let decodedDate = decoded.toDate()
        XCTAssertEqual(decodedDate.timeIntervalSince1970, date.timeIntervalSince1970, accuracy: 0.000001)
    }
    
    // MARK: - ConnectionId Tests
    
    func testConnectionId() throws {
        let original = ConnectionId(12345678901234567890)
        let data = try BSATNEncoder.encode(original)
        
        XCTAssertEqual(data.count, 8)
        
        let decoded = try BSATNDecoder.decode(ConnectionId.self, from: data)
        XCTAssertEqual(decoded, original)
    }
    
    // MARK: - Complex Structure Tests
    
    func testNestedArrays() throws {
        let original: [[Int32]] = [[1, 2, 3], [4, 5], [6]]
        let data = try BSATNEncoder.encode(original)
        
        let decoded = try BSATNDecoder.decode([[Int32]].self, from: data)
        XCTAssertEqual(decoded, original)
    }
    
    // MARK: - Error Cases
    
    func testDecodingUnexpectedEndOfData() {
        let incompleteData = Data([0x01, 0x02])  // Not enough bytes for Int32
        
        var decoder = BSATNDecoder(data: incompleteData)
        XCTAssertThrowsError(try decoder.decode(Int32.self)) { error in
            guard case BSATNDecodingError.unexpectedEndOfData = error else {
                XCTFail("Expected unexpectedEndOfData error")
                return
            }
        }
    }
    
    func testDecodingInvalidBool() {
        let invalidData = Data([0x02])  // Invalid boolean value
        
        var decoder = BSATNDecoder(data: invalidData)
        XCTAssertThrowsError(try decoder.decode(Bool.self)) { error in
            guard case BSATNDecodingError.invalidData = error else {
                XCTFail("Expected invalidData error")
                return
            }
        }
    }
    
    func testDecodingInvalidOptionalTag() {
        let invalidData = Data([0x02])  // Invalid optional tag
        
        var decoder = BSATNDecoder(data: invalidData)
        XCTAssertThrowsError(try decoder.decode(Int32?.self)) { error in
            guard case BSATNDecodingError.invalidData = error else {
                XCTFail("Expected invalidData error")
                return
            }
        }
    }
}
