//
//  TypeGenerator.swift
//  SpacetimeDBCodegen
//
//  Generates Swift structs and enums from SpacetimeDB AlgebraicTypes.
//

import Foundation

// MARK: - TypeGenerator

/// Generates Swift type definitions from SpacetimeDB schema types.
public struct TypeGenerator {
    
    private let typespace: Typespace
    private let typeMapper: TypeMapper
    
    public init(typespace: Typespace, typeMapper: TypeMapper) {
        self.typespace = typespace
        self.typeMapper = typeMapper
    }
    
    // MARK: - Struct Generation
    
    /// Generate a Swift struct from a ProductType.
    public func generateStruct(
        name: String,
        product: ProductType,
        isRowType: Bool = false
    ) -> GeneratedFile {
        let code = SwiftCodeBuilder()
        let swiftName = name.asSwiftTypeName()
        
        code.fileHeader(filename: "\(swiftName).swift")
        code.importModule("Foundation")
        code.importModule("SpacetimeDB")
        code.line()
        
        // Documentation
        code.doc("Row type for the \(name) table." )
        if isRowType {
            code.doc("")
            code.doc("Auto-generated from the SpacetimeDB module schema.")
        }
        
        // Struct declaration
        var protocols = ["BSATNCodable", "Sendable", "Equatable"]
        if isRowType {
            protocols.append("PrimaryKeyExtractable")
        }
        
        code.structDecl(swiftName, protocols: protocols) { builder in
            // Properties
            builder.mark("Properties")
            for element in product.elements {
                let propName = (element.name.value ?? "field\(product.elements.firstIndex { $0 == element } ?? 0)")
                    .asSwiftPropertyName()
                let propType = typeMapper.mapType(element.algebraicType)
                builder.property(propName, type: propType)
            }
            
            // Initializer
            builder.mark("Initialization")
            let initParams = product.elements.map { element in
                let propName = (element.name.value ?? "field\(product.elements.firstIndex { $0 == element } ?? 0)")
                    .asSwiftPropertyName()
                let propType = typeMapper.mapType(element.algebraicType)
                return "\(propName): \(propType)"
            }.joined(separator: ", ")
            
            builder.initDecl(initParams) { b in
                for element in product.elements {
                    let propName = (element.name.value ?? "field\(product.elements.firstIndex { $0 == element } ?? 0)")
                        .asSwiftPropertyName()
                    b.line("self.\(propName) = \(propName)")
                }
            }
            
            // BSATN Encoding
            builder.mark("BSATNCodable")
            builder.funcDecl("encode(to encoder: inout BSATNEncoder) throws") { b in
                for element in product.elements {
                    let propName = (element.name.value ?? "field\(product.elements.firstIndex { $0 == element } ?? 0)")
                        .asSwiftPropertyName()
                    b.line("try \(propName).encode(to: &encoder)")
                }
            }
            
            builder.line()
            builder.initDecl("from decoder: inout BSATNDecoder") { b in
                for element in product.elements {
                    let propName = (element.name.value ?? "field\(product.elements.firstIndex { $0 == element } ?? 0)")
                        .asSwiftPropertyName()
                    let propType = typeMapper.mapType(element.algebraicType)
                    b.line("self.\(propName) = try \(propType)(from: &decoder)")
                }
            }
        }
        
        return GeneratedFile(
            filename: "\(swiftName).swift",
            subdirectory: "Types",
            contents: code.build()
        )
    }
    
    // MARK: - Enum Generation
    
    /// Generate a Swift enum from a SumType.
    public func generateEnum(name: String, sum: SumType) -> GeneratedFile {
        let code = SwiftCodeBuilder()
        let swiftName = name.asSwiftTypeName()
        
        code.fileHeader(filename: "\(swiftName).swift")
        code.importModule("Foundation")
        code.importModule("SpacetimeDB")
        code.line()
        
        code.doc("Enum type \(name).")
        code.doc("")
        code.doc("Auto-generated from the SpacetimeDB module schema.")
        
        code.enumDecl(swiftName, protocols: ["BSATNCodable", "Sendable", "Equatable"]) { builder in
            // Cases
            for (index, variant) in sum.variants.enumerated() {
                let caseName = (variant.name.value ?? "case\(index)").asSwiftPropertyName()
                
                if variant.algebraicType.isUnit {
                    builder.line("case \(caseName)")
                } else {
                    let associatedType = typeMapper.mapType(variant.algebraicType)
                    builder.line("case \(caseName)(\(associatedType))")
                }
            }
            
            // BSATN Encoding
            builder.mark("BSATNCodable")
            builder.funcDecl("encode(to encoder: inout BSATNEncoder) throws") { b in
                b.block("switch self") { sw in
                    for (index, variant) in sum.variants.enumerated() {
                        let caseName = (variant.name.value ?? "case\(index)").asSwiftPropertyName()
                        
                        if variant.algebraicType.isUnit {
                            sw.line("case .\(caseName):")
                            sw.indent()
                            sw.line("encoder.encode(UInt8(\(index)))")
                            sw.outdent()
                        } else {
                            sw.line("case .\(caseName)(let value):")
                            sw.indent()
                            sw.line("encoder.encode(UInt8(\(index)))")
                            sw.line("try value.encode(to: &encoder)")
                            sw.outdent()
                        }
                    }
                }
            }
            
            builder.line()
            builder.initDecl("from decoder: inout BSATNDecoder") { b in
                b.line("let tag = try decoder.decode(UInt8.self)")
                b.line()
                b.block("switch tag") { sw in
                    for (index, variant) in sum.variants.enumerated() {
                        let caseName = (variant.name.value ?? "case\(index)").asSwiftPropertyName()
                        
                        sw.line("case \(index):")
                        sw.indent()
                        if variant.algebraicType.isUnit {
                            sw.line("self = .\(caseName)")
                        } else {
                            let associatedType = typeMapper.mapType(variant.algebraicType)
                            sw.line("self = .\(caseName)(try \(associatedType)(from: &decoder))")
                        }
                        sw.outdent()
                    }
                    
                    sw.line("default:")
                    sw.indent()
                    sw.line("throw BSATNDecodingError.invalidEnumTag(tag: tag, typeName: \"\(swiftName)\")")
                    sw.outdent()
                }
            }
        }
        
        return GeneratedFile(
            filename: "\(swiftName).swift",
            subdirectory: "Types",
            contents: code.build()
        )
    }
    
    // MARK: - Type Detection
    
    /// Determine if an algebraic type should generate a struct or enum.
    public func generateType(name: String, type: AlgebraicType, isRowType: Bool = false) -> GeneratedFile? {
        switch type {
        case .product(let product):
            return generateStruct(name: name, product: product, isRowType: isRowType)
        case .sum(let sum):
            // Don't generate for Option types - they map to Swift optionals
            if type.isOption {
                return nil
            }
            return generateEnum(name: name, sum: sum)
        case .builtin, .ref:
            // Builtins and refs don't generate types
            return nil
        }
    }
}

// MARK: - Type Collection

/// Collects all types that need to be generated from a module.
public struct TypeCollector {
    
    private let moduleDef: RawModuleDef
    
    public init(moduleDef: RawModuleDef) {
        self.moduleDef = moduleDef
    }
    
    /// Collect all named types that need code generation.
    ///
    /// Returns a map of type index to type name.
    public func collectNamedTypes() -> [Int: String] {
        var namedTypes: [Int: String] = [:]
        
        // Table row types
        for table in moduleDef.tables {
            namedTypes[table.productTypeRef] = table.name.asSwiftTypeName()
        }
        
        // TODO: Also collect types used in reducers and nested types
        
        return namedTypes
    }
    
    /// Get all table row type indices.
    public func tableTypeIndices() -> Set<Int> {
        Set(moduleDef.tables.map { $0.productTypeRef })
    }
}
