//
//  TableGenerator.swift
//  SpacetimeDBCodegen
//
//  Generates typed table wrapper classes from SpacetimeDB table definitions.
//

import Foundation

// MARK: - TableGenerator

/// Generates Swift table wrapper types from SpacetimeDB table definitions.
public struct TableGenerator {
    
    private let typespace: Typespace
    private let typeMapper: TypeMapper
    
    public init(typespace: Typespace, typeMapper: TypeMapper) {
        self.typespace = typespace
        self.typeMapper = typeMapper
    }
    
    /// Generate a table wrapper for a table definition.
    public func generateTable(table: TableDef) -> GeneratedFile {
        let code = SwiftCodeBuilder()
        let rowTypeName = table.name.asSwiftTypeName()
        let tableClassName = "\(rowTypeName)Table"
        
        code.fileHeader(filename: "\(tableClassName).swift")
        code.importModule("Foundation")
        code.importModule("SpacetimeDB")
        code.line()
        
        code.doc("Type-safe accessor for the `\(table.name)` table.")
        code.doc("")
        code.doc("Provides typed iteration, lookup, and callback registration.")
        
        code.structDecl(tableClassName, protocols: ["Sendable"]) { builder in
            // Private cache reference
            builder.mark("Properties")
            builder.line("private let cache: TableCache")
            builder.line("private let callbacks: CallbackRegistry")
            builder.line()
            builder.doc("The underlying table name.")
            builder.line("public static let tableName = \"\(table.name)\"")
            
            // Initializer
            builder.mark("Initialization")
            builder.line("internal init(cache: TableCache, callbacks: CallbackRegistry) {")
            builder.indent()
            builder.line("self.cache = cache")
            builder.line("self.callbacks = callbacks")
            builder.outdent()
            builder.line("}")
            
            // Basic accessors
            builder.mark("Accessors")
            builder.doc("The number of rows in the table.")
            builder.computedProperty("count", type: "Int") { b in
                b.line("cache.count")
            }
            builder.line()
            
            builder.doc("Whether the table is empty.")
            builder.computedProperty("isEmpty", type: "Bool") { b in
                b.line("cache.isEmpty")
            }
            builder.line()
            
            // Iteration
            builder.doc("Iterate over all rows in the table.")
            builder.doc("")
            builder.doc("- Returns: An array of all rows, decoded from the cache.")
            builder.funcDecl("iter() -> [\(rowTypeName)]") { b in
                b.line("cache.allRows().compactMap { rowData in")
                b.indent()
                b.line("try? BSATNDecoder.decode(\(rowTypeName).self, from: rowData)")
                b.outdent()
                b.line("}")
            }
            builder.line()
            
            // Raw iteration
            builder.doc("Iterate over raw row data.")
            builder.doc("")
            builder.doc("Use this when you need access to the raw BSATN data.")
            builder.funcDecl("iterRaw() -> [Data]") { b in
                b.line("cache.allRows()")
            }
            
            // Primary key lookup (if table has PK)
            if table.hasPrimaryKey {
                builder.mark("Primary Key Lookup")
                generatePrimaryKeyLookup(table: table, rowTypeName: rowTypeName, builder: builder)
            }
            
            // Callbacks
            builder.mark("Callbacks")
            generateCallbacks(rowTypeName: rowTypeName, tableName: table.name, builder: builder)
        }
        
        return GeneratedFile(
            filename: "\(tableClassName).swift",
            subdirectory: "Tables",
            contents: code.build()
        )
    }
    
    /// Generate primary key lookup methods.
    private func generatePrimaryKeyLookup(
        table: TableDef,
        rowTypeName: String,
        builder: SwiftCodeBuilder
    ) {
        // Get the row type to determine PK field info
        guard let rowType = typespace.resolve(table.productTypeRef),
              case .product(let product) = rowType else {
            return
        }
        
        // Get PK column info
        guard let pkIndex = table.primaryKey.first,
              pkIndex < product.elements.count else {
            return
        }
        
        let pkElement = product.elements[pkIndex]
        let pkFieldName = (pkElement.name.value ?? "field\(pkIndex)").asSwiftPropertyName()
        let pkType = typeMapper.mapType(pkElement.algebraicType)
        let pkParamName = "by\(pkFieldName.prefix(1).uppercased() + pkFieldName.dropFirst())"
        
        builder.doc("Find a row by its primary key.")
        builder.doc("")
        builder.doc("- Parameter \(pkFieldName): The primary key value to search for.")
        builder.doc("- Returns: The matching row, or nil if not found.")
        builder.funcDecl("find(\(pkParamName) \(pkFieldName): \(pkType)) -> \(rowTypeName)?") { b in
            b.line("var encoder = BSATNEncoder()")
            b.line("try? \(pkFieldName).encode(to: &encoder)")
            b.line("guard let data = cache.find(byPrimaryKey: encoder.data) else { return nil }")
            b.line("return try? BSATNDecoder.decode(\(rowTypeName).self, from: data)")
        }
        builder.line()
        
        builder.doc("Check if a row with the given primary key exists.")
        builder.doc("")
        builder.doc("- Parameter \(pkFieldName): The primary key value to check.")
        builder.doc("- Returns: True if a matching row exists.")
        builder.funcDecl("contains(\(pkParamName) \(pkFieldName): \(pkType)) -> Bool") { b in
            b.line("var encoder = BSATNEncoder()")
            b.line("try? \(pkFieldName).encode(to: &encoder)")
            b.line("return cache.contains(primaryKey: encoder.data)")
        }
    }
    
    /// Generate callback registration methods.
    private func generateCallbacks(
        rowTypeName: String,
        tableName: String,
        builder: SwiftCodeBuilder
    ) {
        // onInsert
        builder.doc("Register a callback for row insertions.")
        builder.doc("")
        builder.doc("- Parameter callback: Called with the inserted row.")
        builder.doc("- Returns: A handle to unregister the callback.")
        builder.line("@discardableResult")
        builder.funcDecl("onInsert(_ callback: @escaping @Sendable (\(rowTypeName)) -> Void) -> CallbackHandle") { b in
            b.line("callbacks.onInsert(tableName: \"\(tableName)\") { _, rowData in")
            b.indent()
            b.line("if let row = try? BSATNDecoder.decode(\(rowTypeName).self, from: rowData) {")
            b.indent()
            b.line("callback(row)")
            b.outdent()
            b.line("}")
            b.outdent()
            b.line("}")
        }
        builder.line()
        
        // onDelete
        builder.doc("Register a callback for row deletions.")
        builder.doc("")
        builder.doc("- Parameter callback: Called with the deleted row.")
        builder.doc("- Returns: A handle to unregister the callback.")
        builder.line("@discardableResult")
        builder.funcDecl("onDelete(_ callback: @escaping @Sendable (\(rowTypeName)) -> Void) -> CallbackHandle") { b in
            b.line("callbacks.onDelete(tableName: \"\(tableName)\") { _, rowData in")
            b.indent()
            b.line("if let row = try? BSATNDecoder.decode(\(rowTypeName).self, from: rowData) {")
            b.indent()
            b.line("callback(row)")
            b.outdent()
            b.line("}")
            b.outdent()
            b.line("}")
        }
        builder.line()
        
        // onChange (all operations)
        builder.doc("Register a callback for any row change (insert, update, or delete).")
        builder.doc("")
        builder.doc("- Parameter callback: Called with the table name and operation.")
        builder.doc("- Returns: A handle to unregister the callback.")
        builder.line("@discardableResult")
        builder.funcDecl("onChange(_ callback: @escaping @Sendable (RowOperation, \(rowTypeName)?) -> Void) -> CallbackHandle") { b in
            b.line("callbacks.onChange(tableName: \"\(tableName)\") { _, operation in")
            b.indent()
            b.line("let row = try? BSATNDecoder.decode(\(rowTypeName).self, from: operation.rowData)")
            b.line("callback(operation, row)")
            b.outdent()
            b.line("}")
        }
        builder.line()
        
        // Remove callback
        builder.doc("Remove a registered callback.")
        builder.doc("")
        builder.doc("- Parameter handle: The handle returned from a registration method.")
        builder.funcDecl("removeCallback(_ handle: CallbackHandle)") { b in
            b.line("callbacks.remove(handle)")
        }
    }
}
