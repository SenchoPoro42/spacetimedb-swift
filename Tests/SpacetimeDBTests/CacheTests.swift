//
//  CacheTests.swift
//  SpacetimeDBTests
//
//  Unit tests for the client cache system.
//

import XCTest
@testable import SpacetimeDB

// MARK: - TableCache Tests

final class TableCacheTests: XCTestCase {
    
    func testEmptyCache() {
        let cache = TableCache(tableName: "test")
        
        XCTAssertEqual(cache.tableName, "test")
        XCTAssertEqual(cache.count, 0)
        XCTAssertTrue(cache.isEmpty)
        XCTAssertEqual(cache.allRows().count, 0)
    }
    
    func testInsertAndCount() {
        let cache = TableCache(tableName: "test")
        
        let row1 = Data([0x01, 0x02, 0x03])
        let row2 = Data([0x04, 0x05, 0x06])
        
        cache.insert(row1)
        XCTAssertEqual(cache.count, 1)
        
        cache.insert(row2)
        XCTAssertEqual(cache.count, 2)
        XCTAssertFalse(cache.isEmpty)
    }
    
    func testInsertReplacesSameKey() {
        let cache = TableCache(tableName: "test")
        
        let row1 = Data([0x01, 0x02, 0x03])
        let row2 = Data([0x01, 0x02, 0x03])  // Same data = same key (identity extractor)
        
        let replaced1 = cache.insert(row1)
        XCTAssertNil(replaced1)
        XCTAssertEqual(cache.count, 1)
        
        let replaced2 = cache.insert(row2)
        XCTAssertNotNil(replaced2)
        XCTAssertEqual(cache.count, 1)
    }
    
    func testDelete() {
        let cache = TableCache(tableName: "test")
        
        let row1 = Data([0x01, 0x02, 0x03])
        let row2 = Data([0x04, 0x05, 0x06])
        
        cache.insert(row1)
        cache.insert(row2)
        XCTAssertEqual(cache.count, 2)
        
        let deleted = cache.delete(row1)
        XCTAssertTrue(deleted)
        XCTAssertEqual(cache.count, 1)
        
        // Deleting non-existent row returns false
        let deleted2 = cache.delete(row1)
        XCTAssertFalse(deleted2)
    }
    
    func testClear() {
        let cache = TableCache(tableName: "test")
        
        cache.insert(Data([0x01]))
        cache.insert(Data([0x02]))
        cache.insert(Data([0x03]))
        XCTAssertEqual(cache.count, 3)
        
        cache.clear()
        XCTAssertEqual(cache.count, 0)
        XCTAssertTrue(cache.isEmpty)
    }
    
    func testIteration() {
        let cache = TableCache(tableName: "test")
        
        let rows = [
            Data([0x01]),
            Data([0x02]),
            Data([0x03])
        ]
        
        for row in rows {
            cache.insert(row)
        }
        
        let iteratedRows = Array(cache)
        XCTAssertEqual(iteratedRows.count, 3)
        
        // Verify all rows are present (order not guaranteed)
        for row in rows {
            XCTAssertTrue(iteratedRows.contains(row))
        }
    }
    
    func testFindByPrimaryKey() {
        let cache = TableCache(tableName: "test")
        
        let row1 = Data([0x01, 0x02, 0x03])
        cache.insert(row1)
        
        // With identity extractor, PK = entire row
        let found = cache.find(byPrimaryKey: row1)
        XCTAssertEqual(found, row1)
        
        let notFound = cache.find(byPrimaryKey: Data([0xFF]))
        XCTAssertNil(notFound)
    }
    
    func testBatchInsert() {
        let cache = TableCache(tableName: "test")
        
        let rows = [
            Data([0x01]),
            Data([0x02]),
            Data([0x03])
        ]
        
        let results = cache.insertBatch(rows)
        XCTAssertEqual(results.count, 3)
        XCTAssertEqual(cache.count, 3)
        
        // All should be new inserts
        for result in results {
            XCTAssertNil(result.replaced)
        }
    }
    
    func testBatchDelete() {
        let cache = TableCache(tableName: "test")
        
        let rows = [
            Data([0x01]),
            Data([0x02]),
            Data([0x03])
        ]
        
        for row in rows {
            cache.insert(row)
        }
        
        let deleted = cache.deleteBatch([Data([0x01]), Data([0x02]), Data([0xFF])])
        XCTAssertEqual(deleted.count, 2)  // Only 2 existed
        XCTAssertEqual(cache.count, 1)    // Only [0x03] remains
    }
}

// MARK: - PrimaryKeyExtractor Tests

final class PrimaryKeyExtractorTests: XCTestCase {
    
    func testIdentityExtractor() {
        let extractor = PrimaryKeyExtractor.identity
        let data = Data([0x01, 0x02, 0x03, 0x04])
        
        let key = extractor.extractKey(from: data)
        XCTAssertEqual(key, data)
    }
    
    func testFixedPrefixExtractor() {
        let extractor = PrimaryKeyExtractor.fixedPrefix(byteCount: 4)
        let data = Data([0x01, 0x02, 0x03, 0x04, 0x05, 0x06])
        
        let key = extractor.extractKey(from: data)
        XCTAssertEqual(key, Data([0x01, 0x02, 0x03, 0x04]))
    }
    
    func testFixedPrefixWithShortData() {
        let extractor = PrimaryKeyExtractor.fixedPrefix(byteCount: 8)
        let data = Data([0x01, 0x02, 0x03])  // Shorter than 8 bytes
        
        // Should return entire data as fallback
        let key = extractor.extractKey(from: data)
        XCTAssertEqual(key, data)
    }
    
    func testFixedRangeExtractor() {
        let extractor = PrimaryKeyExtractor.fixedRange(offset: 2, byteCount: 3)
        let data = Data([0x00, 0x01, 0xAA, 0xBB, 0xCC, 0xFF])
        
        let key = extractor.extractKey(from: data)
        XCTAssertEqual(key, Data([0xAA, 0xBB, 0xCC]))
    }
    
    func testU64AtStartExtractor() {
        let extractor = PrimaryKeyExtractor.u64AtStart
        let data = Data([0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08, 0xFF, 0xFF])
        
        let key = extractor.extractKey(from: data)
        XCTAssertEqual(key.count, 8)
        XCTAssertEqual(key, Data([0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08]))
    }
    
    func testTableCacheWithCustomExtractor() {
        let cache = TableCache(tableName: "test")
        cache.setPrimaryKeyExtractor(.u32AtStart)
        
        // Row with same first 4 bytes (PK) but different suffix
        let row1 = Data([0x01, 0x02, 0x03, 0x04, 0xAA, 0xBB])
        let row2 = Data([0x01, 0x02, 0x03, 0x04, 0xCC, 0xDD])
        
        cache.insert(row1)
        let replaced = cache.insert(row2)
        
        // row2 should replace row1 since they have the same PK
        XCTAssertNotNil(replaced)
        XCTAssertEqual(replaced, row1)
        XCTAssertEqual(cache.count, 1)
        
        // Different PK should create new entry
        let row3 = Data([0xFF, 0xFF, 0xFF, 0xFF, 0x00, 0x00])
        let replaced2 = cache.insert(row3)
        XCTAssertNil(replaced2)
        XCTAssertEqual(cache.count, 2)
    }
}

// MARK: - CallbackRegistry Tests

final class CallbackRegistryTests: XCTestCase {
    
    func testInsertCallback() {
        let registry = CallbackRegistry()
        var receivedTable: String?
        var receivedData: Data?
        
        registry.onInsert(tableName: "users") { table, data in
            receivedTable = table
            receivedData = data
        }
        
        let rowData = Data([0x01, 0x02, 0x03])
        registry.notifyInsert(tableName: "users", rowData: rowData)
        
        XCTAssertEqual(receivedTable, "users")
        XCTAssertEqual(receivedData, rowData)
    }
    
    func testDeleteCallback() {
        let registry = CallbackRegistry()
        var callCount = 0
        
        registry.onDelete(tableName: "users") { _, _ in
            callCount += 1
        }
        
        registry.notifyDelete(tableName: "users", rowData: Data([0x01]))
        registry.notifyDelete(tableName: "users", rowData: Data([0x02]))
        
        XCTAssertEqual(callCount, 2)
    }
    
    func testGlobalCallback() {
        let registry = CallbackRegistry()
        var operations: [RowOperation] = []
        
        registry.onAnyChange { _, operation in
            operations.append(operation)
        }
        
        registry.notifyInsert(tableName: "users", rowData: Data([0x01]))
        registry.notifyDelete(tableName: "messages", rowData: Data([0x02]))
        
        XCTAssertEqual(operations.count, 2)
        XCTAssertTrue(operations[0].isInsert)
        XCTAssertTrue(operations[1].isDelete)
    }
    
    func testTableSpecificCallback() {
        let registry = CallbackRegistry()
        var userCallCount = 0
        var messageCallCount = 0
        
        registry.onInsert(tableName: "users") { _, _ in
            userCallCount += 1
        }
        
        registry.onInsert(tableName: "messages") { _, _ in
            messageCallCount += 1
        }
        
        registry.notifyInsert(tableName: "users", rowData: Data([0x01]))
        registry.notifyInsert(tableName: "users", rowData: Data([0x02]))
        registry.notifyInsert(tableName: "messages", rowData: Data([0x03]))
        
        XCTAssertEqual(userCallCount, 2)
        XCTAssertEqual(messageCallCount, 1)
    }
    
    func testRemoveCallback() {
        let registry = CallbackRegistry()
        var callCount = 0
        
        let handle = registry.onInsert(tableName: "users") { _, _ in
            callCount += 1
        }
        
        registry.notifyInsert(tableName: "users", rowData: Data([0x01]))
        XCTAssertEqual(callCount, 1)
        
        let removed = registry.remove(handle)
        XCTAssertTrue(removed)
        
        registry.notifyInsert(tableName: "users", rowData: Data([0x02]))
        XCTAssertEqual(callCount, 1)  // Still 1, callback was removed
    }
    
    func testUpdateCallback() {
        let registry = CallbackRegistry()
        var receivedOperation: RowOperation?
        
        registry.onChange(tableName: "users") { _, operation in
            receivedOperation = operation
        }
        
        let oldData = Data([0x01, 0x02])
        let newData = Data([0x01, 0x03])
        registry.notifyUpdate(tableName: "users", oldData: oldData, newData: newData)
        
        XCTAssertNotNil(receivedOperation)
        XCTAssertTrue(receivedOperation!.isUpdate)
        
        if case .update(let old, let new) = receivedOperation! {
            XCTAssertEqual(old, oldData)
            XCTAssertEqual(new, newData)
        }
    }
}

// MARK: - ClientCache Tests

final class ClientCacheTests: XCTestCase {
    
    func testEmptyCache() async {
        let cache = ClientCache()
        
        let names = await cache.tableNames
        XCTAssertTrue(names.isEmpty)
        
        let count = await cache.totalRowCount
        XCTAssertEqual(count, 0)
    }
    
    func testTableAccess() async {
        let cache = ClientCache()
        
        let users = await cache.table(named: "users")
        XCTAssertEqual(users.tableName, "users")
        
        // Accessing same table returns same instance
        let users2 = await cache.table(named: "users")
        XCTAssertTrue(users === users2)
    }
    
    func testApplyQueryUpdate() async throws {
        let cache = ClientCache()
        
        // Create a simple QueryUpdate with inserts
        let inserts = BsatnRowList(
            sizeHint: .fixedSize(4),
            rowsData: Data([
                0x01, 0x00, 0x00, 0x00,  // Row 1
                0x02, 0x00, 0x00, 0x00   // Row 2
            ])
        )
        let queryUpdate = QueryUpdate(deletes: .empty, inserts: inserts)
        
        // Create a TableUpdate
        let tableUpdate = TableUpdate(
            tableId: TableId(1),
            tableName: "users",
            numRows: 2,
            updates: [.uncompressed(queryUpdate)]
        )
        
        // Create DatabaseUpdate
        let dbUpdate = DatabaseUpdate(tables: [tableUpdate])
        
        // Apply it
        try await cache.applyDatabaseUpdate(dbUpdate)
        
        let usersTable = await cache.table(named: "users")
        XCTAssertEqual(usersTable.count, 2)
        
        let stats = await cache.stats
        XCTAssertEqual(stats.totalInserts, 2)
    }
    
    func testCallbacksOnUpdate() async throws {
        let cache = ClientCache()
        var insertedRows: [Data] = []
        
        await cache.onInsert(tableName: "users") { _, data in
            insertedRows.append(data)
        }
        
        // Create and apply update
        let inserts = BsatnRowList(
            sizeHint: .fixedSize(2),
            rowsData: Data([0x01, 0x02, 0x03, 0x04])
        )
        let queryUpdate = QueryUpdate(deletes: .empty, inserts: inserts)
        let tableUpdate = TableUpdate(
            tableId: TableId(1),
            tableName: "users",
            numRows: 2,
            updates: [.uncompressed(queryUpdate)]
        )
        
        try await cache.applyDatabaseUpdate(DatabaseUpdate(tables: [tableUpdate]))
        
        XCTAssertEqual(insertedRows.count, 2)
    }
    
    func testDeleteCallbacks() async throws {
        let cache = ClientCache()
        var deletedRows: [Data] = []
        
        await cache.onDelete(tableName: "users") { _, data in
            deletedRows.append(data)
        }
        
        // First insert some rows
        let row1 = Data([0x01, 0x02])
        let row2 = Data([0x03, 0x04])
        
        let inserts = BsatnRowList(
            sizeHint: .fixedSize(2),
            rowsData: row1 + row2
        )
        let insertUpdate = QueryUpdate(deletes: .empty, inserts: inserts)
        let insertTableUpdate = TableUpdate(
            tableId: TableId(1),
            tableName: "users",
            numRows: 2,
            updates: [.uncompressed(insertUpdate)]
        )
        
        try await cache.applyDatabaseUpdate(DatabaseUpdate(tables: [insertTableUpdate]))
        
        // Now delete one row
        let deletes = BsatnRowList(
            sizeHint: .fixedSize(2),
            rowsData: row1
        )
        let deleteUpdate = QueryUpdate(deletes: deletes, inserts: .empty)
        let deleteTableUpdate = TableUpdate(
            tableId: TableId(1),
            tableName: "users",
            numRows: 1,
            updates: [.uncompressed(deleteUpdate)]
        )
        
        try await cache.applyDatabaseUpdate(DatabaseUpdate(tables: [deleteTableUpdate]))
        
        XCTAssertEqual(deletedRows.count, 1)
        XCTAssertEqual(deletedRows[0], row1)
        
        let usersTable = await cache.table(named: "users")
        XCTAssertEqual(usersTable.count, 1)
    }
    
    func testClear() async throws {
        let cache = ClientCache()
        
        // Add some data
        let inserts = BsatnRowList(
            sizeHint: .fixedSize(2),
            rowsData: Data([0x01, 0x02, 0x03, 0x04])
        )
        let queryUpdate = QueryUpdate(deletes: .empty, inserts: inserts)
        let tableUpdate = TableUpdate(
            tableId: TableId(1),
            tableName: "users",
            numRows: 2,
            updates: [.uncompressed(queryUpdate)]
        )
        
        try await cache.applyDatabaseUpdate(DatabaseUpdate(tables: [tableUpdate]))
        
        var count = await cache.totalRowCount
        XCTAssertEqual(count, 2)
        
        await cache.clear()
        
        count = await cache.totalRowCount
        XCTAssertEqual(count, 0)
        
        // Table structure still exists
        let hasTable = await cache.hasTable(named: "users")
        XCTAssertTrue(hasTable)
    }
    
    func testReset() async throws {
        let cache = ClientCache()
        
        // Add some data
        let inserts = BsatnRowList(
            sizeHint: .fixedSize(2),
            rowsData: Data([0x01, 0x02])
        )
        let queryUpdate = QueryUpdate(deletes: .empty, inserts: inserts)
        let tableUpdate = TableUpdate(
            tableId: TableId(1),
            tableName: "users",
            numRows: 1,
            updates: [.uncompressed(queryUpdate)]
        )
        
        try await cache.applyDatabaseUpdate(DatabaseUpdate(tables: [tableUpdate]))
        
        await cache.reset()
        
        // Everything is gone, including table structure
        let hasTable = await cache.hasTable(named: "users")
        XCTAssertFalse(hasTable)
        
        let names = await cache.tableNames
        XCTAssertTrue(names.isEmpty)
    }
    
    func testRemoveCallback() async {
        let cache = ClientCache()
        var callCount = 0
        
        let handle = await cache.onInsert(tableName: "users") { _, _ in
            callCount += 1
        }
        
        // Trigger once
        let inserts = BsatnRowList(sizeHint: .fixedSize(1), rowsData: Data([0x01]))
        let queryUpdate = QueryUpdate(deletes: .empty, inserts: inserts)
        let tableUpdate = TableUpdate(
            tableId: TableId(1),
            tableName: "users",
            numRows: 1,
            updates: [.uncompressed(queryUpdate)]
        )
        
        try? await cache.applyDatabaseUpdate(DatabaseUpdate(tables: [tableUpdate]))
        XCTAssertEqual(callCount, 1)
        
        // Remove callback
        let removed = await cache.removeCallback(handle)
        XCTAssertTrue(removed)
        
        // Trigger again - should not increment
        try? await cache.applyDatabaseUpdate(DatabaseUpdate(tables: [tableUpdate]))
        XCTAssertEqual(callCount, 1)
    }
}

// MARK: - RowOperation Tests

final class RowOperationTests: XCTestCase {
    
    func testInsertOperation() {
        let data = Data([0x01, 0x02, 0x03])
        let operation = RowOperation.insert(data)
        
        XCTAssertTrue(operation.isInsert)
        XCTAssertFalse(operation.isDelete)
        XCTAssertFalse(operation.isUpdate)
        XCTAssertEqual(operation.rowData, data)
    }
    
    func testDeleteOperation() {
        let data = Data([0x01, 0x02, 0x03])
        let operation = RowOperation.delete(data)
        
        XCTAssertFalse(operation.isInsert)
        XCTAssertTrue(operation.isDelete)
        XCTAssertFalse(operation.isUpdate)
        XCTAssertEqual(operation.rowData, data)
    }
    
    func testUpdateOperation() {
        let oldData = Data([0x01, 0x02])
        let newData = Data([0x03, 0x04])
        let operation = RowOperation.update(old: oldData, new: newData)
        
        XCTAssertFalse(operation.isInsert)
        XCTAssertFalse(operation.isDelete)
        XCTAssertTrue(operation.isUpdate)
        XCTAssertEqual(operation.rowData, newData)  // Returns new data for updates
    }
}
