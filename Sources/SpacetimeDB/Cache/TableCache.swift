//
//  TableCache.swift
//  SpacetimeDB
//
//  Per-table in-memory cache for storing subscribed rows.
//

import Foundation

// MARK: - TableCache

/// In-memory cache for a single table's rows.
///
/// Stores rows as raw BSATN data keyed by their primary key bytes.
/// This type-erased storage allows the cache to work without knowing
/// the row's schema; generated code provides type-safe wrappers.
///
/// Thread Safety: This class is not thread-safe on its own.
/// It should be accessed through the `ClientCache` actor.
public final class TableCache: @unchecked Sendable {
    
    // MARK: - Properties
    
    /// The name of this table.
    public let tableName: String
    
    /// The table ID (may change between server restarts).
    public private(set) var tableId: TableId?
    
    /// Row storage: primary key bytes → row bytes.
    private var rows: [Data: Data] = [:]
    
    /// Function to extract primary key bytes from a row.
    /// If nil, uses the entire row data as the key.
    private var primaryKeyExtractor: PrimaryKeyExtractor?
    
    // MARK: - Initialization
    
    /// Create a new table cache.
    ///
    /// - Parameters:
    ///   - tableName: The name of the table.
    ///   - tableId: Optional table ID from the server.
    public init(tableName: String, tableId: TableId? = nil) {
        self.tableName = tableName
        self.tableId = tableId
    }
    
    // MARK: - Configuration
    
    /// Register a primary key extractor for this table.
    ///
    /// The extractor is used to derive the key for indexing rows.
    /// Without an extractor, the entire row data is used as the key.
    ///
    /// - Parameter extractor: Function that extracts PK bytes from row data.
    public func setPrimaryKeyExtractor(_ extractor: PrimaryKeyExtractor) {
        self.primaryKeyExtractor = extractor
    }
    
    /// Update the table ID.
    ///
    /// Called when we receive table metadata from the server.
    public func setTableId(_ id: TableId) {
        self.tableId = id
    }
    
    // MARK: - Access
    
    /// The number of rows in the cache.
    public var count: Int {
        rows.count
    }
    
    /// Whether the cache is empty.
    public var isEmpty: Bool {
        rows.isEmpty
    }
    
    /// Iterate over all cached row data.
    ///
    /// - Returns: A sequence of raw BSATN row data.
    public func iter() -> AnySequence<Data> {
        AnySequence(rows.values)
    }
    
    /// Get all row data as an array.
    public func allRows() -> [Data] {
        Array(rows.values)
    }
    
    /// Find a row by its primary key bytes.
    ///
    /// - Parameter primaryKey: The primary key bytes.
    /// - Returns: The row data if found, nil otherwise.
    public func find(byPrimaryKey primaryKey: Data) -> Data? {
        rows[primaryKey]
    }
    
    /// Check if a row with the given primary key exists.
    ///
    /// - Parameter primaryKey: The primary key bytes.
    /// - Returns: True if the row exists.
    public func contains(primaryKey: Data) -> Bool {
        rows[primaryKey] != nil
    }
    
    // MARK: - Mutations
    
    /// Insert a row into the cache.
    ///
    /// If a row with the same primary key exists, it is replaced.
    ///
    /// - Parameter rowData: The BSATN-encoded row data.
    /// - Returns: The old row data if this was an update, nil if new insert.
    @discardableResult
    public func insert(_ rowData: Data) -> Data? {
        let key = extractKey(from: rowData)
        let oldValue = rows[key]
        rows[key] = rowData
        return oldValue
    }
    
    /// Delete a row from the cache.
    ///
    /// - Parameter rowData: The BSATN-encoded row data to delete.
    /// - Returns: True if the row was found and deleted.
    @discardableResult
    public func delete(_ rowData: Data) -> Bool {
        let key = extractKey(from: rowData)
        return rows.removeValue(forKey: key) != nil
    }
    
    /// Delete a row by its primary key.
    ///
    /// - Parameter primaryKey: The primary key bytes.
    /// - Returns: The deleted row data if found, nil otherwise.
    @discardableResult
    public func delete(byPrimaryKey primaryKey: Data) -> Data? {
        rows.removeValue(forKey: primaryKey)
    }
    
    /// Clear all rows from the cache.
    public func clear() {
        rows.removeAll()
    }
    
    // MARK: - Batch Operations
    
    /// Insert multiple rows.
    ///
    /// - Parameter rowsData: Array of BSATN-encoded row data.
    /// - Returns: Array of (inserted row, old row if replaced).
    @discardableResult
    public func insertBatch(_ rowsData: [Data]) -> [(inserted: Data, replaced: Data?)] {
        rowsData.map { rowData in
            let old = insert(rowData)
            return (inserted: rowData, replaced: old)
        }
    }
    
    /// Delete multiple rows.
    ///
    /// - Parameter rowsData: Array of BSATN-encoded row data to delete.
    /// - Returns: Array of deleted row data for rows that existed.
    @discardableResult
    public func deleteBatch(_ rowsData: [Data]) -> [Data] {
        rowsData.compactMap { rowData in
            let key = extractKey(from: rowData)
            return rows.removeValue(forKey: key)
        }
    }
    
    // MARK: - Private
    
    /// Extract the key for a row.
    private func extractKey(from rowData: Data) -> Data {
        if let extractor = primaryKeyExtractor {
            return extractor.extractKey(from: rowData)
        }
        // Fallback: use entire row as key
        return rowData
    }
}

// MARK: - CustomStringConvertible

extension TableCache: CustomStringConvertible {
    public var description: String {
        "TableCache(\(tableName), \(count) rows)"
    }
}

// MARK: - Sequence Conformance

extension TableCache: Sequence {
    public typealias Iterator = AnyIterator<Data>
    
    public func makeIterator() -> AnyIterator<Data> {
        var iterator = rows.values.makeIterator()
        return AnyIterator { iterator.next() }
    }
}
