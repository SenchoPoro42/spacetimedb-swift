//
//  SwiftCodeBuilder.swift
//  SpacetimeDBCodegen
//
//  A builder for generating well-formatted Swift source code.
//

import Foundation

// MARK: - SwiftCodeBuilder

/// A builder for generating Swift source code with proper formatting.
public final class SwiftCodeBuilder {
    
    private var lines: [String] = []
    private var currentIndent: Int = 0
    private let indentString: String
    
    /// Create a new code builder.
    ///
    /// - Parameter indentSize: Number of spaces per indent level (default: 4).
    public init(indentSize: Int = 4) {
        self.indentString = String(repeating: " ", count: indentSize)
    }
    
    // MARK: - Basic Operations
    
    /// Add a line of code at the current indent level.
    @discardableResult
    public func line(_ text: String = "") -> SwiftCodeBuilder {
        if text.isEmpty {
            lines.append("")
        } else {
            lines.append(indent() + text)
        }
        return self
    }
    
    /// Add multiple lines of code.
    @discardableResult
    public func lines(_ texts: [String]) -> SwiftCodeBuilder {
        for text in texts {
            line(text)
        }
        return self
    }
    
    /// Add a comment line.
    @discardableResult
    public func comment(_ text: String) -> SwiftCodeBuilder {
        line("// \(text)")
    }
    
    /// Add a documentation comment.
    @discardableResult
    public func doc(_ text: String) -> SwiftCodeBuilder {
        line("/// \(text)")
    }
    
    /// Add multiple documentation comment lines.
    @discardableResult
    public func docs(_ texts: [String]) -> SwiftCodeBuilder {
        for text in texts {
            doc(text)
        }
        return self
    }
    
    // MARK: - Indentation
    
    /// Increase indent level.
    @discardableResult
    public func indent() -> SwiftCodeBuilder {
        currentIndent += 1
        return self
    }
    
    /// Decrease indent level.
    @discardableResult
    public func outdent() -> SwiftCodeBuilder {
        currentIndent = max(0, currentIndent - 1)
        return self
    }
    
    /// Get the current indent string.
    private func indent() -> String {
        String(repeating: indentString, count: currentIndent)
    }
    
    // MARK: - Blocks
    
    /// Add a block with braces.
    ///
    /// Example: `block("struct Foo") { ... }` produces:
    /// ```
    /// struct Foo {
    ///     ...
    /// }
    /// ```
    @discardableResult
    public func block(_ header: String, _ builder: (SwiftCodeBuilder) -> Void) -> SwiftCodeBuilder {
        line("\(header) {")
        currentIndent += 1
        builder(self)
        currentIndent -= 1
        line("}")
        return self
    }
    
    /// Add a closure block.
    @discardableResult
    public func closure(_ header: String, _ builder: (SwiftCodeBuilder) -> Void) -> SwiftCodeBuilder {
        block(header, builder)
    }
    
    // MARK: - Common Patterns
    
    /// Add an import statement.
    @discardableResult
    public func importModule(_ module: String) -> SwiftCodeBuilder {
        line("import \(module)")
    }
    
    /// Add a struct declaration.
    @discardableResult
    public func structDecl(
        _ name: String,
        access: String = "public",
        protocols: [String] = [],
        _ builder: (SwiftCodeBuilder) -> Void
    ) -> SwiftCodeBuilder {
        var header = "\(access) struct \(name)"
        if !protocols.isEmpty {
            header += ": \(protocols.joined(separator: ", "))"
        }
        return block(header, builder)
    }
    
    /// Add an enum declaration.
    @discardableResult
    public func enumDecl(
        _ name: String,
        access: String = "public",
        protocols: [String] = [],
        _ builder: (SwiftCodeBuilder) -> Void
    ) -> SwiftCodeBuilder {
        var header = "\(access) enum \(name)"
        if !protocols.isEmpty {
            header += ": \(protocols.joined(separator: ", "))"
        }
        return block(header, builder)
    }
    
    /// Add an extension declaration.
    @discardableResult
    public func extensionDecl(
        _ type: String,
        protocols: [String] = [],
        _ builder: (SwiftCodeBuilder) -> Void
    ) -> SwiftCodeBuilder {
        var header = "extension \(type)"
        if !protocols.isEmpty {
            header += ": \(protocols.joined(separator: ", "))"
        }
        return block(header, builder)
    }
    
    /// Add a function declaration.
    @discardableResult
    public func funcDecl(
        _ signature: String,
        access: String = "public",
        _ builder: (SwiftCodeBuilder) -> Void
    ) -> SwiftCodeBuilder {
        block("\(access) func \(signature)", builder)
    }
    
    /// Add an initializer declaration.
    @discardableResult
    public func initDecl(
        _ params: String,
        access: String = "public",
        _ builder: (SwiftCodeBuilder) -> Void
    ) -> SwiftCodeBuilder {
        block("\(access) init(\(params))", builder)
    }
    
    /// Add a property declaration.
    @discardableResult
    public func property(
        _ name: String,
        type: String,
        access: String = "public",
        isLet: Bool = true,
        defaultValue: String? = nil
    ) -> SwiftCodeBuilder {
        let keyword = isLet ? "let" : "var"
        var decl = "\(access) \(keyword) \(name): \(type)"
        if let value = defaultValue {
            decl += " = \(value)"
        }
        return line(decl)
    }
    
    /// Add a computed property.
    @discardableResult
    public func computedProperty(
        _ name: String,
        type: String,
        access: String = "public",
        _ builder: (SwiftCodeBuilder) -> Void
    ) -> SwiftCodeBuilder {
        block("\(access) var \(name): \(type)", builder)
    }
    
    // MARK: - MARK Comments
    
    /// Add a MARK comment.
    @discardableResult
    public func mark(_ text: String) -> SwiftCodeBuilder {
        line()
        line("// MARK: - \(text)")
        line()
        return self
    }
    
    // MARK: - File Header
    
    /// Add a standard file header.
    @discardableResult
    public func fileHeader(filename: String, module: String = "ModuleBindings") -> SwiftCodeBuilder {
        line("//")
        line("//  \(filename)")
        line("//  \(module)")
        line("//")
        line("//  Auto-generated by spacetimedb-codegen. DO NOT EDIT.")
        line("//")
        line()
        return self
    }
    
    // MARK: - Output
    
    /// Build the final source code string.
    public func build() -> String {
        lines.joined(separator: "\n")
    }
    
    /// Clear all content.
    public func clear() {
        lines.removeAll()
        currentIndent = 0
    }
}

// MARK: - GeneratedFile

/// Represents a generated source file.
public struct GeneratedFile {
    /// The filename (including extension).
    public let filename: String
    
    /// The subdirectory within the output directory.
    public let subdirectory: String?
    
    /// The file contents.
    public let contents: String
    
    public init(filename: String, subdirectory: String? = nil, contents: String) {
        self.filename = filename
        self.subdirectory = subdirectory
        self.contents = contents
    }
    
    /// The relative path from the output directory.
    public var relativePath: String {
        if let dir = subdirectory {
            return "\(dir)/\(filename)"
        }
        return filename
    }
}

// MARK: - FileWriter

/// Writes generated files to disk.
public struct FileWriter {
    
    private let outputDirectory: URL
    private let fileManager = FileManager.default
    
    public init(outputDirectory: URL) {
        self.outputDirectory = outputDirectory
    }
    
    /// Write a generated file to disk.
    public func write(_ file: GeneratedFile) throws {
        var targetDir = outputDirectory
        
        if let subdir = file.subdirectory {
            targetDir = outputDirectory.appendingPathComponent(subdir)
        }
        
        // Create directory if needed
        try fileManager.createDirectory(at: targetDir, withIntermediateDirectories: true)
        
        // Write file
        let filePath = targetDir.appendingPathComponent(file.filename)
        try file.contents.write(to: filePath, atomically: true, encoding: .utf8)
    }
    
    /// Write multiple generated files.
    public func writeAll(_ files: [GeneratedFile]) throws {
        for file in files {
            try write(file)
        }
    }
}
