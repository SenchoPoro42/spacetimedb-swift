//
//  Primitives+BSATN.swift
//  SpacetimeDB
//
//  BSATNCodable conformances for Swift primitive types.
//

import Foundation

// MARK: - Boolean

extension Bool: BSATNCodable {
    public func encode(to encoder: inout BSATNEncoder) throws {
        encoder.encode(self)
    }
    
    public init(from decoder: inout BSATNDecoder) throws {
        self = try decoder.decode(Bool.self)
    }
}

// MARK: - Unsigned Integers

extension UInt8: BSATNCodable {
    public func encode(to encoder: inout BSATNEncoder) throws {
        encoder.encode(self)
    }
    
    public init(from decoder: inout BSATNDecoder) throws {
        self = try decoder.decode(UInt8.self)
    }
}

extension UInt16: BSATNCodable {
    public func encode(to encoder: inout BSATNEncoder) throws {
        encoder.encode(self)
    }
    
    public init(from decoder: inout BSATNDecoder) throws {
        self = try decoder.decode(UInt16.self)
    }
}

extension UInt32: BSATNCodable {
    public func encode(to encoder: inout BSATNEncoder) throws {
        encoder.encode(self)
    }
    
    public init(from decoder: inout BSATNDecoder) throws {
        self = try decoder.decode(UInt32.self)
    }
}

extension UInt64: BSATNCodable {
    public func encode(to encoder: inout BSATNEncoder) throws {
        encoder.encode(self)
    }
    
    public init(from decoder: inout BSATNDecoder) throws {
        self = try decoder.decode(UInt64.self)
    }
}

// MARK: - Signed Integers

extension Int8: BSATNCodable {
    public func encode(to encoder: inout BSATNEncoder) throws {
        encoder.encode(self)
    }
    
    public init(from decoder: inout BSATNDecoder) throws {
        self = try decoder.decode(Int8.self)
    }
}

extension Int16: BSATNCodable {
    public func encode(to encoder: inout BSATNEncoder) throws {
        encoder.encode(self)
    }
    
    public init(from decoder: inout BSATNDecoder) throws {
        self = try decoder.decode(Int16.self)
    }
}

extension Int32: BSATNCodable {
    public func encode(to encoder: inout BSATNEncoder) throws {
        encoder.encode(self)
    }
    
    public init(from decoder: inout BSATNDecoder) throws {
        self = try decoder.decode(Int32.self)
    }
}

extension Int64: BSATNCodable {
    public func encode(to encoder: inout BSATNEncoder) throws {
        encoder.encode(self)
    }
    
    public init(from decoder: inout BSATNDecoder) throws {
        self = try decoder.decode(Int64.self)
    }
}

// MARK: - Platform-sized Integers
// Note: BSATN uses fixed-width integers. Map Int/UInt to 64-bit.

extension Int: BSATNCodable {
    public func encode(to encoder: inout BSATNEncoder) throws {
        encoder.encode(Int64(self))
    }
    
    public init(from decoder: inout BSATNDecoder) throws {
        let value = try decoder.decode(Int64.self)
        guard let result = Int(exactly: value) else {
            throw BSATNDecodingError.invalidData("Int64 value \(value) does not fit in Int")
        }
        self = result
    }
}

extension UInt: BSATNCodable {
    public func encode(to encoder: inout BSATNEncoder) throws {
        encoder.encode(UInt64(self))
    }
    
    public init(from decoder: inout BSATNDecoder) throws {
        let value = try decoder.decode(UInt64.self)
        guard let result = UInt(exactly: value) else {
            throw BSATNDecodingError.invalidData("UInt64 value \(value) does not fit in UInt")
        }
        self = result
    }
}

// MARK: - Floating Point

extension Float: BSATNCodable {
    public func encode(to encoder: inout BSATNEncoder) throws {
        encoder.encode(self)
    }
    
    public init(from decoder: inout BSATNDecoder) throws {
        self = try decoder.decode(Float.self)
    }
}

extension Double: BSATNCodable {
    public func encode(to encoder: inout BSATNEncoder) throws {
        encoder.encode(self)
    }
    
    public init(from decoder: inout BSATNDecoder) throws {
        self = try decoder.decode(Double.self)
    }
}

// MARK: - String

extension String: BSATNCodable {
    public func encode(to encoder: inout BSATNEncoder) throws {
        try encoder.encode(self)
    }
    
    public init(from decoder: inout BSATNDecoder) throws {
        self = try decoder.decode(String.self)
    }
}

// MARK: - Data (Raw Bytes)

extension Data: BSATNCodable {
    public func encode(to encoder: inout BSATNEncoder) throws {
        try encoder.encode(self)
    }
    
    public init(from decoder: inout BSATNDecoder) throws {
        self = try decoder.decode(Data.self)
    }
}

// MARK: - Arrays

extension Array: BSATNEncodable where Element: BSATNEncodable {
    public func encode(to encoder: inout BSATNEncoder) throws {
        try encoder.encode(self)
    }
}

extension Array: BSATNDecodable where Element: BSATNDecodable {
    public init(from decoder: inout BSATNDecoder) throws {
        self = try decoder.decode([Element].self)
    }
}

// MARK: - Optionals

extension Optional: BSATNEncodable where Wrapped: BSATNEncodable {
    public func encode(to encoder: inout BSATNEncoder) throws {
        try encoder.encode(self)
    }
}

extension Optional: BSATNDecodable where Wrapped: BSATNDecodable {
    public init(from decoder: inout BSATNDecoder) throws {
        self = try decoder.decode(Wrapped?.self)
    }
}

// MARK: - UUID
// Note: BSATN typically represents UUIDs as 16 raw bytes (big-endian per RFC 4122)

extension UUID: BSATNCodable {
    public func encode(to encoder: inout BSATNEncoder) throws {
        // UUID bytes are already in network byte order (big-endian)
        let bytes = withUnsafePointer(to: uuid) { ptr in
            Data(bytes: ptr, count: 16)
        }
        encoder.appendRaw(bytes)
    }
    
    public init(from decoder: inout BSATNDecoder) throws {
        let bytes = try decoder.readBytes(16)
        guard bytes.count == 16 else {
            throw BSATNDecodingError.invalidData("UUID requires exactly 16 bytes")
        }
        
        let uuid = bytes.withUnsafeBytes { ptr -> uuid_t in
            ptr.load(as: uuid_t.self)
        }
        self.init(uuid: uuid)
    }
}
