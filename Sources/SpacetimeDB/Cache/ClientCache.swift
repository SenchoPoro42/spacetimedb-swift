//
//  ClientCache.swift
//  SpacetimeDB
//
//  Main client-side cache for subscribed database rows.
//

import Foundation

// MARK: - ClientCache

/// The client-side cache for subscribed database rows.
///
/// `ClientCache` maintains an in-memory representation of the subscribed
/// portion of the SpacetimeDB database. It processes `DatabaseUpdate` messages
/// from the server to keep the local cache synchronized.
///
/// ## Usage
///
/// ```swift
/// let cache = ClientCache()
///
/// // Register callbacks
/// let handle = await cache.onInsert(tableName: "User") { tableName, rowData in
///     print("New user inserted")
/// }
///
/// // Process server updates
/// await cache.applyDatabaseUpdate(update)
///
/// // Access cached data
/// for rowData in await cache.table(named: "User").iter() {
///     let user = try BSATNDecoder.decode(User.self, from: rowData)
/// }
/// ```
///
/// ## Thread Safety
///
/// `ClientCache` is implemented as an actor, ensuring all access is thread-safe.
/// Access table data and register callbacks from any async context.
public actor ClientCache {
    
    // MARK: - Properties
    
    /// Per-table caches.
    private var tables: [String: TableCache] = [:]
    
    /// Callback registry for row changes.
    private let callbacks = CallbackRegistry()
    
    /// Statistics about cache operations.
    public private(set) var stats = CacheStats()
    
    // MARK: - Initialization
    
    /// Create a new empty client cache.
    public init() {}
    
    // MARK: - Table Access
    
    /// Get the cache for a table, creating it if necessary.
    ///
    /// - Parameter name: The table name.
    /// - Returns: The table cache.
    public func table(named name: String) -> TableCache {
        if let existing = tables[name] {
            return existing
        }
        let cache = TableCache(tableName: name)
        
        // Register primary key extractor if available
        if let extractor = PrimaryKeyExtractorRegistry.shared.extractor(for: name) {
            cache.setPrimaryKeyExtractor(extractor)
        }
        
        tables[name] = cache
        return cache
    }
    
    /// Get all table names in the cache.
    public var tableNames: [String] {
        Array(tables.keys)
    }
    
    /// Get all tables in the cache.
    public var allTables: [TableCache] {
        Array(tables.values)
    }
    
    /// Check if a table exists in the cache.
    ///
    /// - Parameter name: The table name.
    /// - Returns: True if the table has been created.
    public func hasTable(named name: String) -> Bool {
        tables[name] != nil
    }
    
    /// Get the total number of rows across all tables.
    public var totalRowCount: Int {
        tables.values.reduce(0) { $0 + $1.count }
    }
    
    // MARK: - Applying Updates
    
    /// Apply a database update from the server.
    ///
    /// This processes all table updates, applying inserts and deletes
    /// to the local cache and firing appropriate callbacks.
    ///
    /// - Parameter update: The database update to apply.
    /// - Throws: `QueryUpdateDecompressionError` if decompression fails.
    public func applyDatabaseUpdate(_ update: DatabaseUpdate) throws {
        for tableUpdate in update.tables {
            try applyTableUpdate(tableUpdate)
        }
    }
    
    /// Apply a single table update.
    ///
    /// - Parameter update: The table update to apply.
    /// - Throws: `QueryUpdateDecompressionError` if decompression fails.
    public func applyTableUpdate(_ update: TableUpdate) throws {
        let tableCache = table(named: update.tableName)
        tableCache.setTableId(update.tableId)
        
        for compressableUpdate in update.updates {
            let queryUpdate = try compressableUpdate.decompress()
            applyQueryUpdate(queryUpdate, tableName: update.tableName, tableCache: tableCache)
        }
    }
    
    /// Apply a query update to a specific table.
    ///
    /// - Parameters:
    ///   - update: The query update containing deletes and inserts.
    ///   - tableName: The name of the table.
    ///   - tableCache: The table cache to update.
    private func applyQueryUpdate(_ update: QueryUpdate, tableName: String, tableCache: TableCache) {
        // Process deletes first
        for rowData in update.deletes {
            let deleted = tableCache.delete(rowData)
            if deleted {
                stats.totalDeletes += 1
                callbacks.notifyDelete(tableName: tableName, rowData: rowData)
            }
        }
        
        // Process inserts
        for rowData in update.inserts {
            let replaced = tableCache.insert(rowData)
            stats.totalInserts += 1
            
            if let oldData = replaced {
                // This was an update (same PK, different data)
                stats.totalUpdates += 1
                callbacks.notifyUpdate(tableName: tableName, oldData: oldData, newData: rowData)
            } else {
                callbacks.notifyInsert(tableName: tableName, rowData: rowData)
            }
        }
    }
    
    /// Clear all cached data.
    ///
    /// This removes all rows from all tables but keeps the table structures.
    /// Callbacks are NOT fired for cleared rows.
    public func clear() {
        for cache in tables.values {
            cache.clear()
        }
        stats = CacheStats()
    }
    
    /// Clear all cached data and remove all tables.
    public func reset() {
        tables.removeAll()
        stats = CacheStats()
    }
    
    // MARK: - Callbacks
    
    /// Register a callback for any row change in any table.
    ///
    /// - Parameter callback: The callback to invoke on any change.
    /// - Returns: A handle to unregister the callback.
    @discardableResult
    public func onAnyChange(_ callback: @escaping RowChangeCallback) -> CallbackHandle {
        callbacks.onAnyChange(callback)
    }
    
    /// Register a callback for row inserts in a specific table.
    ///
    /// - Parameters:
    ///   - tableName: The table to observe.
    ///   - callback: The callback to invoke on insert.
    /// - Returns: A handle to unregister the callback.
    @discardableResult
    public func onInsert(tableName: String, _ callback: @escaping RowInsertCallback) -> CallbackHandle {
        callbacks.onInsert(tableName: tableName, callback)
    }
    
    /// Register a callback for row deletes in a specific table.
    ///
    /// - Parameters:
    ///   - tableName: The table to observe.
    ///   - callback: The callback to invoke on delete.
    /// - Returns: A handle to unregister the callback.
    @discardableResult
    public func onDelete(tableName: String, _ callback: @escaping RowDeleteCallback) -> CallbackHandle {
        callbacks.onDelete(tableName: tableName, callback)
    }
    
    /// Register a callback for any change in a specific table.
    ///
    /// - Parameters:
    ///   - tableName: The table to observe.
    ///   - callback: The callback to invoke on any change.
    /// - Returns: A handle to unregister the callback.
    @discardableResult
    public func onChange(tableName: String, _ callback: @escaping RowChangeCallback) -> CallbackHandle {
        callbacks.onChange(tableName: tableName, callback)
    }
    
    /// Remove a callback registration.
    ///
    /// - Parameter handle: The handle returned when registering.
    /// - Returns: True if the callback was found and removed.
    @discardableResult
    public func removeCallback(_ handle: CallbackHandle) -> Bool {
        callbacks.remove(handle)
    }
    
    /// Remove all registered callbacks.
    public func removeAllCallbacks() {
        callbacks.removeAll()
    }
}

// MARK: - CacheStats

/// Statistics about cache operations.
public struct CacheStats: Sendable {
    /// Total number of insert operations processed.
    public var totalInserts: Int = 0
    
    /// Total number of delete operations processed.
    public var totalDeletes: Int = 0
    
    /// Total number of update operations detected (delete + insert with same PK).
    public var totalUpdates: Int = 0
    
    /// Total operations processed.
    public var totalOperations: Int {
        totalInserts + totalDeletes
    }
}

// MARK: - Convenience Extensions

extension ClientCache {
    
    /// Apply an initial subscription response.
    ///
    /// - Parameter subscription: The initial subscription data.
    /// - Throws: `QueryUpdateDecompressionError` if decompression fails.
    public func applyInitialSubscription(_ subscription: InitialSubscription) throws {
        try applyDatabaseUpdate(subscription.databaseUpdate)
    }
    
    /// Apply a transaction update if committed.
    ///
    /// - Parameter transaction: The transaction update.
    /// - Throws: `QueryUpdateDecompressionError` if decompression fails.
    /// - Returns: True if the update was applied (committed), false if failed/out of energy.
    @discardableResult
    public func applyTransactionUpdate(_ transaction: TransactionUpdate) throws -> Bool {
        switch transaction.status {
        case .committed(let update):
            try applyDatabaseUpdate(update)
            return true
        case .failed, .outOfEnergy:
            return false
        }
    }
    
    /// Apply a subscribe applied response.
    ///
    /// - Parameter response: The subscribe applied response.
    /// - Throws: `QueryUpdateDecompressionError` if decompression fails.
    public func applySubscribeApplied(_ response: SubscribeApplied) throws {
        let tableUpdate = response.rows.tableRows
        try applyTableUpdate(tableUpdate)
    }
    
    /// Apply a subscribe multi applied response.
    ///
    /// - Parameter response: The subscribe multi applied response.
    /// - Throws: `QueryUpdateDecompressionError` if decompression fails.
    public func applySubscribeMultiApplied(_ response: SubscribeMultiApplied) throws {
        try applyDatabaseUpdate(response.update)
    }
}

// MARK: - CustomStringConvertible

extension ClientCache: CustomStringConvertible {
    nonisolated public var description: String {
        "ClientCache"
    }
}

extension CacheStats: CustomStringConvertible {
    public var description: String {
        "CacheStats(inserts: \(totalInserts), deletes: \(totalDeletes), updates: \(totalUpdates))"
    }
}
