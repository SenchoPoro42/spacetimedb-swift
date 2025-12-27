//
//  PrimaryKeyExtractor.swift
//  SpacetimeDB
//
//  Primary key extraction for indexing rows in the client cache.
//

import Foundation

// MARK: - PrimaryKeyExtractor

/// Extracts primary key bytes from raw BSATN-encoded row data.
///
/// At the base cache level, we work with raw bytes and don't know the schema.
/// Generated code registers extractors that know how to read the PK fields
/// from the row's binary representation.
///
/// Without an extractor, the entire row data is used as the key, which works
/// for initial subscriptions but prevents efficient update detection.
public struct PrimaryKeyExtractor: Sendable {
    
    /// Function that extracts primary key bytes from row data.
    private let extractor: @Sendable (Data) -> Data
    
    /// Create a primary key extractor.
    ///
    /// - Parameter extractor: Function that takes raw row data and returns the PK bytes.
    public init(_ extractor: @escaping @Sendable (Data) -> Data) {
        self.extractor = extractor
    }
    
    /// Extract the primary key bytes from row data.
    ///
    /// - Parameter rowData: The BSATN-encoded row data.
    /// - Returns: The primary key bytes.
    public func extractKey(from rowData: Data) -> Data {
        extractor(rowData)
    }
}

// MARK: - Common Extractors

extension PrimaryKeyExtractor {
    
    /// An extractor that uses the entire row as the key.
    ///
    /// This is the default fallback when no schema-aware extractor is registered.
    public static let identity = PrimaryKeyExtractor { $0 }
    
    /// Create an extractor for a fixed-size prefix primary key.
    ///
    /// Use this when the primary key is a fixed-size type (e.g., u64, u128)
    /// at the start of the row.
    ///
    /// - Parameter byteCount: The number of bytes in the primary key.
    /// - Returns: An extractor that reads the first N bytes.
    public static func fixedPrefix(byteCount: Int) -> PrimaryKeyExtractor {
        PrimaryKeyExtractor { rowData in
            guard rowData.count >= byteCount else {
                return rowData
            }
            return rowData.prefix(byteCount)
        }
    }
    
    /// Create an extractor for a u32 primary key at offset 0.
    public static let u32AtStart = fixedPrefix(byteCount: 4)
    
    /// Create an extractor for a u64 primary key at offset 0.
    public static let u64AtStart = fixedPrefix(byteCount: 8)
    
    /// Create an extractor for a u128 primary key at offset 0.
    public static let u128AtStart = fixedPrefix(byteCount: 16)
    
    /// Create an extractor for a u256 primary key at offset 0 (Identity).
    public static let u256AtStart = fixedPrefix(byteCount: 32)
    
    /// Create an extractor for a fixed-size key at a specific offset.
    ///
    /// - Parameters:
    ///   - offset: The byte offset where the key starts.
    ///   - byteCount: The number of bytes in the key.
    /// - Returns: An extractor that reads bytes at the specified range.
    public static func fixedRange(offset: Int, byteCount: Int) -> PrimaryKeyExtractor {
        PrimaryKeyExtractor { rowData in
            let endOffset = offset + byteCount
            guard rowData.count >= endOffset else {
                return rowData
            }
            let startIndex = rowData.startIndex.advanced(by: offset)
            let endIndex = rowData.startIndex.advanced(by: endOffset)
            return rowData[startIndex..<endIndex]
        }
    }
}

// MARK: - PrimaryKeyExtractorRegistry

/// Registry for primary key extractors, keyed by table name.
///
/// Generated code registers extractors during module initialization.
/// The cache queries this registry when processing table updates.
public final class PrimaryKeyExtractorRegistry: @unchecked Sendable {
    
    /// Shared registry instance.
    public static let shared = PrimaryKeyExtractorRegistry()
    
    /// Registered extractors by table name.
    private var extractors: [String: PrimaryKeyExtractor] = [:]
    
    /// Lock for thread-safe access.
    private let lock = NSLock()
    
    private init() {}
    
    /// Register an extractor for a table.
    ///
    /// - Parameters:
    ///   - tableName: The table name.
    ///   - extractor: The primary key extractor.
    public func register(tableName: String, extractor: PrimaryKeyExtractor) {
        lock.lock()
        defer { lock.unlock() }
        extractors[tableName] = extractor
    }
    
    /// Get the extractor for a table.
    ///
    /// - Parameter tableName: The table name.
    /// - Returns: The registered extractor, or nil if none registered.
    public func extractor(for tableName: String) -> PrimaryKeyExtractor? {
        lock.lock()
        defer { lock.unlock() }
        return extractors[tableName]
    }
    
    /// Remove the extractor for a table.
    ///
    /// - Parameter tableName: The table name.
    public func unregister(tableName: String) {
        lock.lock()
        defer { lock.unlock() }
        extractors.removeValue(forKey: tableName)
    }
    
    /// Remove all registered extractors.
    public func clear() {
        lock.lock()
        defer { lock.unlock() }
        extractors.removeAll()
    }
}

// MARK: - PrimaryKeyExtractable Protocol

/// Protocol for types that can provide their primary key bytes.
///
/// Generated row types conform to this protocol to enable efficient
/// primary key extraction without re-decoding the entire row.
public protocol PrimaryKeyExtractable {
    /// Extract the primary key as raw bytes.
    ///
    /// - Returns: The BSATN-encoded primary key bytes.
    func primaryKeyBytes() -> Data
    
    /// The extractor for this row type.
    ///
    /// Generated code provides this to extract PK from raw row data
    /// without decoding to the Swift type.
    static var primaryKeyExtractor: PrimaryKeyExtractor { get }
}
