//
//  main.swift
//  SpacetimeDBCodegen
//
//  CLI entry point for the SpacetimeDB Swift code generator.
//

import ArgumentParser
import Foundation
import SpacetimeDBCodegenLib

@main
struct SpacetimeDBCodegen: AsyncParsableCommand {
    static var configuration = CommandConfiguration(
        commandName: "spacetimedb-codegen",
        abstract: "Generate type-safe Swift bindings from a SpacetimeDB module schema.",
        discussion: """
            This tool generates Swift code from a SpacetimeDB module schema, providing:
            - Type-safe row structs with BSATNCodable conformance
            - Typed table wrappers with iteration, lookup, and callbacks
            - Typed reducer call methods
            
            The schema can be loaded from:
            - A local JSON file (--schema-file)
            - A running SpacetimeDB server (--server + --module-name)
            
            Example usage:
                spacetimedb-codegen --schema-file schema.json --out-dir ./ModuleBindings
                spacetimedb-codegen --server ws://localhost:3000 --module-name my_module --out-dir ./ModuleBindings
            """,
        version: "0.1.0"
    )
    
    // MARK: - Input Options
    
    @Option(
        name: [.long, .customShort("f")],
        help: "Path to a JSON schema file (from `spacetime describe --json`)."
    )
    var schemaFile: String?
    
    @Option(
        name: [.long, .customShort("s")],
        help: "SpacetimeDB server URL (e.g., ws://localhost:3000)."
    )
    var server: String?
    
    @Option(
        name: [.long, .customShort("m")],
        help: "Module name or database identity on the server."
    )
    var moduleName: String?
    
    // MARK: - Output Options
    
    @Option(
        name: [.long, .customShort("o")],
        help: "Output directory for generated files."
    )
    var outDir: String
    
    @Flag(
        name: .long,
        help: "Overwrite existing files without prompting."
    )
    var force: Bool = false
    
    @Flag(
        name: .long,
        help: "Print verbose output during generation."
    )
    var verbose: Bool = false
    
    // MARK: - Validation
    
    func validate() throws {
        // Must have either schema-file OR (server + module-name)
        let hasFile = schemaFile != nil
        let hasServer = server != nil && moduleName != nil
        
        if !hasFile && !hasServer {
            throw ValidationError(
                "Must provide either --schema-file OR both --server and --module-name"
            )
        }
        
        if hasFile && hasServer {
            throw ValidationError(
                "Cannot specify both --schema-file and --server/--module-name"
            )
        }
        
        if server != nil && moduleName == nil {
            throw ValidationError("--module-name is required when using --server")
        }
        
        if moduleName != nil && server == nil {
            throw ValidationError("--server is required when using --module-name")
        }
    }
    
    // MARK: - Execution
    
    func run() async throws {
        log("SpacetimeDB Swift Code Generator v0.1.0")
        
        // Load schema
        let schema: RawModuleDef
        if let schemaPath = schemaFile {
            log("Loading schema from file: \(schemaPath)")
            let fileURL = URL(fileURLWithPath: schemaPath)
            schema = try SchemaLoader.loadFromFile(at: fileURL)
        } else if let serverURL = server, let module = moduleName {
            log("Fetching schema from server: \(serverURL)")
            guard let url = URL(string: serverURL) else {
                throw CodegenError.invalidInput("Invalid server URL: \(serverURL)")
            }
            schema = try await SchemaLoader.loadFromServer(uri: url, moduleName: module)
        } else {
            throw CodegenError.invalidInput("No schema source specified")
        }
        
        log("Schema loaded: \(schema.tables.count) tables, \(schema.reducers.count) reducers")
        
        // Generate code
        log("Generating code...")
        let generator = ModuleGenerator(moduleDef: schema)
        let files = generator.generateAll()
        
        log("Generated \(files.count) files")
        
        // Write files
        let outputURL = URL(fileURLWithPath: outDir)
        let writer = FileWriter(outputDirectory: outputURL)
        
        // Check if output directory exists
        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: outDir) && !force {
            log("Warning: Output directory exists. Use --force to overwrite.")
        }
        
        // Create output directory
        try fileManager.createDirectory(at: outputURL, withIntermediateDirectories: true)
        
        // Write all files
        for file in files {
            log("  Writing: \(file.relativePath)")
            try writer.write(file)
        }
        
        print("✓ Generated \(files.count) files in \(outDir)")
        
        // Print summary
        let typeCount = files.filter { $0.subdirectory == "Types" }.count
        let tableCount = files.filter { $0.subdirectory == "Tables" }.count
        let reducerCount = files.filter { $0.subdirectory == "Reducers" }.count
        
        print("  - \(typeCount) type definitions")
        print("  - \(tableCount) table wrappers")
        print("  - \(reducerCount) reducer methods")
    }
    
    // MARK: - Helpers
    
    private func log(_ message: String) {
        if verbose {
            print(message)
        }
    }
}
