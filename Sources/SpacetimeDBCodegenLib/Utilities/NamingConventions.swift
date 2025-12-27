//
//  NamingConventions.swift
//  SpacetimeDBCodegen
//
//  Utilities for converting between naming conventions and mapping types.
//

import Foundation

// MARK: - String Extensions for Naming

public extension String {
    /// Convert snake_case to camelCase.
    ///
    /// Examples:
    /// - "send_message" → "sendMessage"
    /// - "user_id" → "userId"
    /// - "URL" → "url"
    func snakeToCamelCase() -> String {
        let parts = self.split(separator: "_")
        guard let first = parts.first else { return self }
        
        let rest = parts.dropFirst().map { $0.capitalized }
        return String(first).lowercased() + rest.joined()
    }
    
    /// Convert snake_case to PascalCase.
    ///
    /// Examples:
    /// - "send_message" → "SendMessage"
    /// - "user" → "User"
    func snakeToPascalCase() -> String {
        self.split(separator: "_")
            .map { $0.capitalized }
            .joined()
    }
    
    /// Convert to a valid Swift identifier.
    ///
    /// Escapes reserved keywords and ensures the name is valid.
    func asSwiftIdentifier() -> String {
        let reserved = SwiftKeywords.all
        if reserved.contains(self) {
            return "`\(self)`"
        }
        return self
    }
    
    /// Convert to a valid Swift type name (PascalCase).
    func asSwiftTypeName() -> String {
        snakeToPascalCase().asSwiftIdentifier()
    }
    
    /// Convert to a valid Swift property name (camelCase).
    func asSwiftPropertyName() -> String {
        snakeToCamelCase().asSwiftIdentifier()
    }
    
    /// Pluralize a name (simple English rules).
    func pluralized() -> String {
        if self.hasSuffix("s") || self.hasSuffix("x") || self.hasSuffix("ch") || self.hasSuffix("sh") {
            return self + "es"
        } else if self.hasSuffix("y") && !["a", "e", "i", "o", "u"].contains(String(self.dropLast().last ?? Character(""))) {
            return String(self.dropLast()) + "ies"
        } else {
            return self + "s"
        }
    }
}

// MARK: - Swift Keywords

/// Swift reserved keywords that need escaping.
public enum SwiftKeywords {
    public static let all: Set<String> = [
        // Declarations
        "associatedtype", "class", "deinit", "enum", "extension", "fileprivate",
        "func", "import", "init", "inout", "internal", "let", "open", "operator",
        "private", "precedencegroup", "protocol", "public", "rethrows", "static",
        "struct", "subscript", "typealias", "var",
        
        // Statements
        "break", "case", "catch", "continue", "default", "defer", "do", "else",
        "fallthrough", "for", "guard", "if", "in", "repeat", "return", "throw",
        "switch", "where", "while",
        
        // Expressions and types
        "Any", "as", "await", "false", "is", "nil", "self", "Self", "super",
        "throws", "true", "try",
        
        // Patterns
        "_",
        
        // Context-sensitive (escaped when used as identifier)
        "Protocol", "Type"
    ]
}

// MARK: - Type Mapping

/// Maps SpacetimeDB types to Swift types.
public struct TypeMapper {
    
    private let typespace: Typespace
    private var namedTypes: [Int: String] = [:]
    
    public init(typespace: Typespace) {
        self.typespace = typespace
    }
    
    /// Register a named type at a given index.
    public mutating func registerNamedType(index: Int, name: String) {
        namedTypes[index] = name
    }
    
    /// Map a builtin type to its Swift equivalent.
    public func mapBuiltin(_ builtin: BuiltinType) -> String {
        switch builtin {
        case .bool: return "Bool"
        case .i8: return "Int8"
        case .i16: return "Int16"
        case .i32: return "Int32"
        case .i64: return "Int64"
        case .i128: return "Int128"
        case .i256: return "Int256"
        case .u8: return "UInt8"
        case .u16: return "UInt16"
        case .u32: return "UInt32"
        case .u64: return "UInt64"
        case .u128: return "UInt128"
        case .u256: return "UInt256"
        case .f32: return "Float"
        case .f64: return "Double"
        case .string: return "String"
        case .array(let element):
            return "[\(mapType(element))]"
        case .map(let key, let value):
            return "[\(mapType(key)): \(mapType(value))]"
        }
    }
    
    /// Map an algebraic type to its Swift equivalent.
    public func mapType(_ type: AlgebraicType) -> String {
        switch type {
        case .builtin(let builtin):
            return mapBuiltin(builtin)
            
        case .ref(let index):
            // Check if this is a named type
            if let name = namedTypes[index] {
                return name
            }
            // Check if it's a well-known type
            if let resolved = typespace.resolve(index) {
                return mapType(resolved)
            }
            return "UnknownType\(index)"
            
        case .product(let product):
            // Anonymous product - use tuple
            if product.elements.isEmpty {
                return "Void"
            }
            let elements = product.elements.map { elem in
                let typeName = mapType(elem.algebraicType)
                if let name = elem.name.value {
                    return "\(name.asSwiftPropertyName()): \(typeName)"
                }
                return typeName
            }
            return "(\(elements.joined(separator: ", ")))"
            
        case .sum(let sum):
            // Check if it's an Option type
            if type.isOption, let inner = type.optionInnerType {
                return "\(mapType(inner))?"
            }
            // Anonymous sum - would need to be named
            return "AnonymousEnum"
        }
    }
    
    /// Check if a type is the Identity type.
    public func isIdentityType(_ type: AlgebraicType) -> Bool {
        // Identity is typically U256 or a named type
        if case .builtin(.u256) = type {
            return true
        }
        if case .ref(let index) = type, namedTypes[index] == "Identity" {
            return true
        }
        return false
    }
    
    /// Check if a type is the ConnectionId type.
    public func isConnectionIdType(_ type: AlgebraicType) -> Bool {
        if case .ref(let index) = type, namedTypes[index] == "ConnectionId" {
            return true
        }
        return false
    }
    
    /// Check if a type is the Timestamp type.
    public func isTimestampType(_ type: AlgebraicType) -> Bool {
        if case .ref(let index) = type, namedTypes[index] == "Timestamp" {
            return true
        }
        return false
    }
}

// MARK: - Well-Known Types

/// Well-known SpacetimeDB types that map to SDK types.
public enum WellKnownTypes {
    /// SDK types that are provided by the core library.
    public static let sdkTypes: Set<String> = [
        "Identity",
        "ConnectionId",
        "Timestamp",
        "TimeDuration"
    ]
    
    /// Check if a type name is a well-known SDK type.
    public static func isSDKType(_ name: String) -> Bool {
        sdkTypes.contains(name)
    }
}
