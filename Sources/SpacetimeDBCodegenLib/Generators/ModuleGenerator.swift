//
//  ModuleGenerator.swift
//  SpacetimeDBCodegen
//
//  Main orchestrator for generating all module bindings.
//

import Foundation

// MARK: - ModuleGenerator

/// Orchestrates code generation for an entire SpacetimeDB module.
public struct ModuleGenerator {
    
    private let moduleDef: RawModuleDef
    private let typeMapper: TypeMapper
    private let typeGenerator: TypeGenerator
    private let tableGenerator: TableGenerator
    private let reducerGenerator: ReducerGenerator
    
    public init(moduleDef: RawModuleDef) {
        self.moduleDef = moduleDef
        
        // Build type mapper with named types
        var mapper = TypeMapper(typespace: moduleDef.typespace)
        let collector = TypeCollector(moduleDef: moduleDef)
        for (index, name) in collector.collectNamedTypes() {
            mapper.registerNamedType(index: index, name: name)
        }
        self.typeMapper = mapper
        
        self.typeGenerator = TypeGenerator(typespace: moduleDef.typespace, typeMapper: mapper)
        self.tableGenerator = TableGenerator(typespace: moduleDef.typespace, typeMapper: mapper)
        self.reducerGenerator = ReducerGenerator(typespace: moduleDef.typespace, typeMapper: mapper)
    }
    
    /// Generate all bindings for the module.
    public func generateAll() -> [GeneratedFile] {
        var files: [GeneratedFile] = []
        
        // Generate types for each table's row type
        let tableTypeIndices = Set(moduleDef.tables.map { $0.productTypeRef })
        for table in moduleDef.tables {
            if let rowType = moduleDef.typespace.resolve(table.productTypeRef) {
                if let typeFile = typeGenerator.generateType(
                    name: table.name,
                    type: rowType,
                    isRowType: true
                ) {
                    files.append(typeFile)
                }
            }
        }
        
        // Generate table wrappers
        for table in moduleDef.tables where table.isPublic {
            files.append(tableGenerator.generateTable(table: table))
        }
        
        // Generate reducer methods
        for reducer in moduleDef.reducers where reducer.isCallable {
            if let reducerFile = reducerGenerator.generateReducer(reducer: reducer) {
                files.append(reducerFile)
            }
        }
        
        // Generate RemoteTables
        files.append(generateRemoteTables())
        
        // Generate RemoteReducers
        files.append(generateRemoteReducers())
        
        // Generate DbConnection extension
        files.append(generateDbConnectionExtension())
        
        // Generate Reducer enum
        let enumGen = ReducerEnumGenerator(reducers: moduleDef.reducers, typeMapper: typeMapper)
        files.append(enumGen.generateReducerEnum())
        
        return files
    }
    
    /// Generate the RemoteTables struct.
    private func generateRemoteTables() -> GeneratedFile {
        let code = SwiftCodeBuilder()
        
        code.fileHeader(filename: "RemoteTables.swift")
        code.importModule("Foundation")
        code.importModule("SpacetimeDB")
        code.line()
        
        code.doc("Provides typed access to all tables in the module.")
        code.doc("")
        code.doc("Access tables through `connection.db.tableName`.")
        
        let publicTables = moduleDef.tables.filter { $0.isPublic }
        
        code.structDecl("RemoteTables", protocols: ["Sendable"]) { builder in
            builder.mark("Properties")
            builder.line("private let cache: ClientCache")
            builder.line("private let callbacks: CallbackRegistry")
            
            // Table properties
            builder.mark("Tables")
            for table in publicTables {
                let propName = table.name.asSwiftPropertyName()
                let typeName = table.name.asSwiftTypeName()
                let tableType = "\(typeName)Table"
                
                builder.doc("Access the `\(table.name)` table.")
                builder.computedProperty(propName, type: tableType) { b in
                    b.line("\(tableType)(cache: cache.table(named: \"\(table.name)\"), callbacks: callbacks)")
                }
                builder.line()
            }
            
            // Initializer
            builder.mark("Initialization")
            builder.line("internal init(cache: ClientCache, callbacks: CallbackRegistry) {")
            builder.indent()
            builder.line("self.cache = cache")
            builder.line("self.callbacks = callbacks")
            builder.outdent()
            builder.line("}")
        }
        
        return GeneratedFile(
            filename: "RemoteTables.swift",
            subdirectory: nil,
            contents: code.build()
        )
    }
    
    /// Generate the RemoteReducers struct.
    private func generateRemoteReducers() -> GeneratedFile {
        let code = SwiftCodeBuilder()
        
        code.fileHeader(filename: "RemoteReducers.swift")
        code.importModule("Foundation")
        code.importModule("SpacetimeDB")
        code.line()
        
        code.doc("Provides typed access to all reducers in the module.")
        code.doc("")
        code.doc("Call reducers through `connection.reducers.reducerName(...)`.")
        code.doc("")
        code.doc("Individual reducer methods are defined in extensions in the Reducers/ directory.")
        
        code.structDecl("RemoteReducers", protocols: ["Sendable"]) { builder in
            builder.mark("Properties")
            builder.doc("The connection used to call reducers.")
            builder.line("internal let connection: SpacetimeDBConnection")
            
            builder.mark("Initialization")
            builder.line("internal init(connection: SpacetimeDBConnection) {")
            builder.indent()
            builder.line("self.connection = connection")
            builder.outdent()
            builder.line("}")
        }
        
        return GeneratedFile(
            filename: "RemoteReducers.swift",
            subdirectory: nil,
            contents: code.build()
        )
    }
    
    /// Generate the DbConnection extension.
    private func generateDbConnectionExtension() -> GeneratedFile {
        let code = SwiftCodeBuilder()
        
        code.fileHeader(filename: "DbConnection+Module.swift")
        code.importModule("Foundation")
        code.importModule("SpacetimeDB")
        code.line()
        
        code.doc("Extension providing typed access to module tables and reducers.")
        
        code.extensionDecl("SpacetimeDBConnection") { builder in
            builder.doc("Typed access to the module's tables.")
            builder.doc("")
            builder.doc("Example:")
            builder.doc("```swift")
            builder.doc("let users = connection.tables.users.iter()")
            builder.doc("```")
            builder.computedProperty("tables", type: "RemoteTables") { b in
                b.line("RemoteTables(cache: db, callbacks: db.callbacks)")
            }
            builder.line()
            
            builder.doc("Typed access to the module's reducers.")
            builder.doc("")
            builder.doc("Example:")
            builder.doc("```swift")
            builder.doc("try await connection.reducers.sendMessage(text: \"Hello!\")")
            builder.doc("```")
            builder.computedProperty("reducers", type: "RemoteReducers") { b in
                b.line("RemoteReducers(connection: self)")
            }
        }
        
        return GeneratedFile(
            filename: "DbConnection+Module.swift",
            subdirectory: nil,
            contents: code.build()
        )
    }
}

// MARK: - Schema Loading

/// Loads schema from various sources.
public struct SchemaLoader {
    
    /// Load schema from a JSON file.
    public static func loadFromFile(at path: URL) throws -> RawModuleDef {
        let data = try Data(contentsOf: path)
        return try JSONDecoder().decode(RawModuleDef.self, from: data)
    }
    
    /// Load schema from JSON string.
    public static func loadFromString(_ json: String) throws -> RawModuleDef {
        guard let data = json.data(using: .utf8) else {
            throw CodegenError.invalidInput("Invalid JSON string encoding")
        }
        return try JSONDecoder().decode(RawModuleDef.self, from: data)
    }
    
    /// Load schema from a SpacetimeDB server.
    public static func loadFromServer(
        uri: URL,
        moduleName: String
    ) async throws -> RawModuleDef {
        // Build the schema URL
        var components = URLComponents(url: uri, resolvingAgainstBaseURL: false)!
        components.scheme = components.scheme == "ws" ? "http" : "https"
        components.path = "/v1/database/\(moduleName)/schema"
        components.queryItems = [URLQueryItem(name: "version", value: "9")]
        
        guard let schemaURL = components.url else {
            throw CodegenError.invalidInput("Invalid server URL")
        }
        
        let (data, response) = try await URLSession.shared.data(from: schemaURL)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw CodegenError.networkError("Failed to fetch schema from server")
        }
        
        return try JSONDecoder().decode(RawModuleDef.self, from: data)
    }
}

// MARK: - Errors

/// Errors during code generation.
public enum CodegenError: Error, LocalizedError {
    case invalidInput(String)
    case networkError(String)
    case fileWriteError(String)
    case schemaError(String)
    
    public var errorDescription: String? {
        switch self {
        case .invalidInput(let msg): return "Invalid input: \(msg)"
        case .networkError(let msg): return "Network error: \(msg)"
        case .fileWriteError(let msg): return "File write error: \(msg)"
        case .schemaError(let msg): return "Schema error: \(msg)"
        }
    }
}
