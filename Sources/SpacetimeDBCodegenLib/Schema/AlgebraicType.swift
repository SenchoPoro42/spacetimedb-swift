//
//  AlgebraicType.swift
//  SpacetimeDBCodegen
//
//  Models for SpacetimeDB's Algebraic Type System (SATS).
//  These types represent the schema information from RawModuleDef JSON.
//

import Foundation

// MARK: - AlgebraicType

/// The root type for SpacetimeDB's type system.
///
/// Every type in a SpacetimeDB schema is represented as an AlgebraicType,
/// which can be a product (struct), sum (enum), builtin primitive, or
/// a reference to another type in the typespace.
public indirect enum AlgebraicType: Codable, Sendable, Equatable {
    /// A product type (struct/tuple with named or positional fields).
    case product(ProductType)
    
    /// A sum type (tagged union/enum with variants).
    case sum(SumType)
    
    /// A builtin primitive type.
    case builtin(BuiltinType)
    
    /// A reference to another type in the typespace by index.
    case ref(Int)
    
    // MARK: - Codable
    
    private enum CodingKeys: String, CodingKey {
        case Product, Sum, Builtin, Ref
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        if let product = try container.decodeIfPresent(ProductType.self, forKey: .Product) {
            self = .product(product)
        } else if let sum = try container.decodeIfPresent(SumType.self, forKey: .Sum) {
            self = .sum(sum)
        } else if let builtin = try container.decodeIfPresent(BuiltinType.self, forKey: .Builtin) {
            self = .builtin(builtin)
        } else if let ref = try container.decodeIfPresent(Int.self, forKey: .Ref) {
            self = .ref(ref)
        } else {
            throw DecodingError.dataCorrupted(
                DecodingError.Context(
                    codingPath: decoder.codingPath,
                    debugDescription: "Unknown AlgebraicType variant"
                )
            )
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .product(let value):
            try container.encode(value, forKey: .Product)
        case .sum(let value):
            try container.encode(value, forKey: .Sum)
        case .builtin(let value):
            try container.encode(value, forKey: .Builtin)
        case .ref(let value):
            try container.encode(value, forKey: .Ref)
        }
    }
}

// MARK: - ProductType

/// A product type represents a struct or tuple.
///
/// Product types have zero or more elements (fields), each with an
/// optional name and an algebraic type.
public struct ProductType: Codable, Sendable, Equatable {
    /// The fields of this product type.
    public let elements: [ProductTypeElement]
    
    public init(elements: [ProductTypeElement]) {
        self.elements = elements
    }
}

/// An element (field) of a product type.
public struct ProductTypeElement: Codable, Sendable, Equatable {
    /// The optional name of this field.
    public let name: OptionalString
    
    /// The type of this field.
    public let algebraicType: AlgebraicType
    
    private enum CodingKeys: String, CodingKey {
        case name
        case algebraicType = "algebraic_type"
    }
    
    public init(name: String?, algebraicType: AlgebraicType) {
        self.name = OptionalString(name)
        self.algebraicType = algebraicType
    }
}

// MARK: - SumType

/// A sum type represents a tagged union or enum.
///
/// Sum types have zero or more variants, each with an optional name
/// (discriminant) and an algebraic type for the variant's data.
public struct SumType: Codable, Sendable, Equatable {
    /// The variants of this sum type.
    public let variants: [SumTypeVariant]
    
    public init(variants: [SumTypeVariant]) {
        self.variants = variants
    }
}

/// A variant of a sum type.
public struct SumTypeVariant: Codable, Sendable, Equatable {
    /// The optional name (discriminant) of this variant.
    public let name: OptionalString
    
    /// The type of data this variant carries.
    public let algebraicType: AlgebraicType
    
    private enum CodingKeys: String, CodingKey {
        case name
        case algebraicType = "algebraic_type"
    }
    
    public init(name: String?, algebraicType: AlgebraicType) {
        self.name = OptionalString(name)
        self.algebraicType = algebraicType
    }
}

// MARK: - BuiltinType

/// Builtin primitive types in SpacetimeDB.
public enum BuiltinType: Codable, Sendable, Equatable {
    // Primitive types
    case bool
    case i8, i16, i32, i64, i128, i256
    case u8, u16, u32, u64, u128, u256
    case f32, f64
    case string
    
    // Container types
    case array(AlgebraicType)
    case map(key: AlgebraicType, value: AlgebraicType)
    
    // MARK: - Codable
    
    private enum CodingKeys: String, CodingKey {
        case Bool, I8, I16, I32, I64, I128, I256
        case U8, U16, U32, U64, U128, U256
        case F32, F64, String
        case Array, Map
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // Check for simple types (encoded as empty arrays)
        if container.contains(.Bool) { self = .bool; return }
        if container.contains(.I8) { self = .i8; return }
        if container.contains(.I16) { self = .i16; return }
        if container.contains(.I32) { self = .i32; return }
        if container.contains(.I64) { self = .i64; return }
        if container.contains(.I128) { self = .i128; return }
        if container.contains(.I256) { self = .i256; return }
        if container.contains(.U8) { self = .u8; return }
        if container.contains(.U16) { self = .u16; return }
        if container.contains(.U32) { self = .u32; return }
        if container.contains(.U64) { self = .u64; return }
        if container.contains(.U128) { self = .u128; return }
        if container.contains(.U256) { self = .u256; return }
        if container.contains(.F32) { self = .f32; return }
        if container.contains(.F64) { self = .f64; return }
        if container.contains(.String) { self = .string; return }
        
        // Check for container types
        if let elementType = try container.decodeIfPresent(AlgebraicType.self, forKey: .Array) {
            self = .array(elementType)
            return
        }
        
        if let mapTypes = try container.decodeIfPresent(MapTypeEncoding.self, forKey: .Map) {
            self = .map(key: mapTypes.key, value: mapTypes.value)
            return
        }
        
        throw DecodingError.dataCorrupted(
            DecodingError.Context(
                codingPath: decoder.codingPath,
                debugDescription: "Unknown BuiltinType variant"
            )
        )
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        switch self {
        case .bool: try container.encode([String](), forKey: .Bool)
        case .i8: try container.encode([String](), forKey: .I8)
        case .i16: try container.encode([String](), forKey: .I16)
        case .i32: try container.encode([String](), forKey: .I32)
        case .i64: try container.encode([String](), forKey: .I64)
        case .i128: try container.encode([String](), forKey: .I128)
        case .i256: try container.encode([String](), forKey: .I256)
        case .u8: try container.encode([String](), forKey: .U8)
        case .u16: try container.encode([String](), forKey: .U16)
        case .u32: try container.encode([String](), forKey: .U32)
        case .u64: try container.encode([String](), forKey: .U64)
        case .u128: try container.encode([String](), forKey: .U128)
        case .u256: try container.encode([String](), forKey: .U256)
        case .f32: try container.encode([String](), forKey: .F32)
        case .f64: try container.encode([String](), forKey: .F64)
        case .string: try container.encode([String](), forKey: .String)
        case .array(let element):
            try container.encode(element, forKey: .Array)
        case .map(let key, let value):
            try container.encode(MapTypeEncoding(key: key, value: value), forKey: .Map)
        }
    }
}

/// Helper for encoding/decoding Map types.
private struct MapTypeEncoding: Codable {
    let key: AlgebraicType
    let value: AlgebraicType
}

// MARK: - OptionalString

/// Represents SpacetimeDB's optional string encoding: `{"some": "value"}` or `{"none": []}`.
public struct OptionalString: Codable, Sendable, Equatable {
    public let value: String?
    
    public init(_ value: String?) {
        self.value = value
    }
    
    private enum CodingKeys: String, CodingKey {
        case some, none
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        if let value = try container.decodeIfPresent(String.self, forKey: .some) {
            self.value = value
        } else if container.contains(.none) {
            self.value = nil
        } else {
            throw DecodingError.dataCorrupted(
                DecodingError.Context(
                    codingPath: decoder.codingPath,
                    debugDescription: "Expected 'some' or 'none' for optional string"
                )
            )
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        if let value = value {
            try container.encode(value, forKey: .some)
        } else {
            try container.encode([String](), forKey: .none)
        }
    }
}

// MARK: - Convenience Extensions

extension AlgebraicType {
    /// Returns true if this is the unit type (empty product).
    public var isUnit: Bool {
        if case .product(let p) = self, p.elements.isEmpty {
            return true
        }
        return false
    }
    
    /// Returns true if this is an Option type (sum with none/some variants).
    public var isOption: Bool {
        guard case .sum(let sum) = self, sum.variants.count == 2 else {
            return false
        }
        let names = sum.variants.compactMap { $0.name.value }
        return names.contains("none") && names.contains("some")
    }
    
    /// If this is an Option type, returns the inner type.
    public var optionInnerType: AlgebraicType? {
        guard isOption, case .sum(let sum) = self else { return nil }
        return sum.variants.first { $0.name.value == "some" }?.algebraicType
    }
}
