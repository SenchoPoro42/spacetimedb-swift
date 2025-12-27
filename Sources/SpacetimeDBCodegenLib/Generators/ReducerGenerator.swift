//
//  ReducerGenerator.swift
//  SpacetimeDBCodegen
//
//  Generates typed reducer call methods from SpacetimeDB reducer definitions.
//

import Foundation

// MARK: - ReducerGenerator

/// Generates Swift reducer call methods from SpacetimeDB reducer definitions.
public struct ReducerGenerator {
    
    private let typespace: Typespace
    private let typeMapper: TypeMapper
    
    public init(typespace: Typespace, typeMapper: TypeMapper) {
        self.typespace = typespace
        self.typeMapper = typeMapper
    }
    
    /// Generate a reducer method for a reducer definition.
    ///
    /// Returns nil for lifecycle reducers (init, connect, disconnect).
    public func generateReducer(reducer: ReducerDef) -> GeneratedFile? {
        // Skip lifecycle reducers - they can't be called by clients
        guard reducer.isCallable else {
            return nil
        }
        
        let code = SwiftCodeBuilder()
        let methodName = reducer.name.asSwiftPropertyName()
        let className = reducer.name.asSwiftTypeName() + "Reducer"
        
        code.fileHeader(filename: "\(className).swift")
        code.importModule("Foundation")
        code.importModule("SpacetimeDB")
        code.line()
        
        code.doc("Reducer: `\(reducer.name)`")
        code.doc("")
        code.doc("Auto-generated typed wrapper for calling the reducer.")
        
        // Generate as an extension on RemoteReducers
        code.extensionDecl("RemoteReducers") { builder in
            generateReducerMethod(reducer: reducer, methodName: methodName, builder: builder)
        }
        
        return GeneratedFile(
            filename: "\(className).swift",
            subdirectory: "Reducers",
            contents: code.build()
        )
    }
    
    /// Generate the reducer call method.
    private func generateReducerMethod(
        reducer: ReducerDef,
        methodName: String,
        builder: SwiftCodeBuilder
    ) {
        let params = reducer.params.elements
        
        // Build parameter list
        let paramList = params.enumerated().map { index, element in
            let paramName = (element.name.value ?? "arg\(index)").asSwiftPropertyName()
            let paramType = typeMapper.mapType(element.algebraicType)
            return "\(paramName): \(paramType)"
        }.joined(separator: ", ")
        
        // Documentation
        builder.doc("Call the `\(reducer.name)` reducer.")
        builder.doc("")
        if !params.isEmpty {
            builder.doc("- Parameters:")
            for (index, element) in params.enumerated() {
                let paramName = (element.name.value ?? "arg\(index)").asSwiftPropertyName()
                builder.doc("  - \(paramName): Reducer argument.")
            }
        }
        builder.doc("- Returns: The result of the reducer call.")
        builder.doc("- Throws: `ConnectionError` on failure or timeout.")
        
        // Method signature
        let signature: String
        if params.isEmpty {
            signature = "\(methodName)() async throws -> ReducerResult"
        } else {
            signature = "\(methodName)(\(paramList)) async throws -> ReducerResult"
        }
        
        builder.funcDecl(signature) { b in
            if params.isEmpty {
                // No arguments - pass empty data
                b.line("try await connection.callReducer(\"\(reducer.name)\", args: Data())")
            } else {
                // Encode arguments
                b.line("var encoder = BSATNEncoder()")
                for (index, element) in params.enumerated() {
                    let paramName = (element.name.value ?? "arg\(index)").asSwiftPropertyName()
                    b.line("try \(paramName).encode(to: &encoder)")
                }
                b.line("return try await connection.callReducer(\"\(reducer.name)\", args: encoder.data)")
            }
        }
    }
    
    /// Generate all callable reducer methods.
    public func generateAllReducers(reducers: [ReducerDef]) -> [GeneratedFile] {
        reducers.compactMap { generateReducer(reducer: $0) }
    }
}

// MARK: - Reducer Enum Generator

/// Generates an enum representing all reducers in the module.
public struct ReducerEnumGenerator {
    
    private let reducers: [ReducerDef]
    private let typeMapper: TypeMapper
    
    public init(reducers: [ReducerDef], typeMapper: TypeMapper) {
        self.reducers = reducers
        self.typeMapper = typeMapper
    }
    
    /// Generate the Reducer enum for pattern matching on reducer events.
    public func generateReducerEnum() -> GeneratedFile {
        let code = SwiftCodeBuilder()
        
        code.fileHeader(filename: "Reducer.swift")
        code.importModule("Foundation")
        code.importModule("SpacetimeDB")
        code.line()
        
        code.doc("Enum representing all reducers in the module.")
        code.doc("")
        code.doc("Use this for pattern matching on reducer events.")
        
        let callableReducers = reducers.filter { $0.isCallable }
        
        code.enumDecl("Reducer", protocols: ["Sendable", "Equatable"]) { builder in
            // Cases for each reducer
            for reducer in callableReducers {
                let caseName = reducer.name.asSwiftPropertyName()
                let params = reducer.params.elements
                
                if params.isEmpty {
                    builder.line("case \(caseName)")
                } else {
                    let paramTypes = params.enumerated().map { index, element in
                        let paramName = (element.name.value ?? "arg\(index)").asSwiftPropertyName()
                        let paramType = typeMapper.mapType(element.algebraicType)
                        return "\(paramName): \(paramType)"
                    }.joined(separator: ", ")
                    builder.line("case \(caseName)(\(paramTypes))")
                }
            }
            
            // Unknown case for forward compatibility
            builder.line("case unknown(name: String, args: Data)")
            
            // Reducer name property
            builder.mark("Properties")
            builder.doc("The name of this reducer.")
            builder.computedProperty("name", type: "String") { b in
                b.block("switch self") { sw in
                    for reducer in callableReducers {
                        let caseName = reducer.name.asSwiftPropertyName()
                        if reducer.params.elements.isEmpty {
                            sw.line("case .\(caseName): return \"\(reducer.name)\"")
                        } else {
                            sw.line("case .\(caseName): return \"\(reducer.name)\"")
                        }
                    }
                    sw.line("case .unknown(let name, _): return name")
                }
            }
        }
        
        return GeneratedFile(
            filename: "Reducer.swift",
            subdirectory: nil,
            contents: code.build()
        )
    }
}
