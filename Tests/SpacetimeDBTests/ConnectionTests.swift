//
//  ConnectionTests.swift
//  SpacetimeDB
//
//  Tests for the Connection layer.
//

import XCTest
@testable import SpacetimeDB

// MARK: - ConnectionStateTests

final class ConnectionStateTests: XCTestCase {
    
    func testDisconnectedState() {
        let state = ConnectionState.disconnected
        XCTAssertFalse(state.isConnected)
        XCTAssertFalse(state.isConnecting)
        XCTAssertEqual(state.description, "disconnected")
    }
    
    func testConnectingState() {
        let state = ConnectionState.connecting
        XCTAssertFalse(state.isConnected)
        XCTAssertTrue(state.isConnecting)
        XCTAssertEqual(state.description, "connecting")
    }
    
    func testConnectedState() {
        let state = ConnectionState.connected
        XCTAssertTrue(state.isConnected)
        XCTAssertFalse(state.isConnecting)
        XCTAssertEqual(state.description, "connected")
    }
    
    func testReconnectingState() {
        let state = ConnectionState.reconnecting(attempt: 2)
        XCTAssertFalse(state.isConnected)
        XCTAssertTrue(state.isConnecting)
        XCTAssertEqual(state.description, "reconnecting (attempt 2)")
    }
    
    func testStateEquality() {
        XCTAssertEqual(ConnectionState.disconnected, ConnectionState.disconnected)
        XCTAssertEqual(ConnectionState.connected, ConnectionState.connected)
        XCTAssertEqual(ConnectionState.reconnecting(attempt: 1), ConnectionState.reconnecting(attempt: 1))
        XCTAssertNotEqual(ConnectionState.reconnecting(attempt: 1), ConnectionState.reconnecting(attempt: 2))
        XCTAssertNotEqual(ConnectionState.connected, ConnectionState.connecting)
    }
}

// MARK: - RequestIdGeneratorTests

final class RequestIdGeneratorTests: XCTestCase {
    
    func testSequentialGeneration() {
        let generator = RequestIdGenerator(startingAt: 100)
        
        XCTAssertEqual(generator.next(), 100)
        XCTAssertEqual(generator.next(), 101)
        XCTAssertEqual(generator.next(), 102)
    }
    
    func testDefaultStartsAtOne() {
        let generator = RequestIdGenerator()
        
        XCTAssertEqual(generator.next(), 1)
        XCTAssertEqual(generator.next(), 2)
    }
    
    func testWrappingAddition() {
        let generator = RequestIdGenerator(startingAt: UInt32.max)
        
        XCTAssertEqual(generator.next(), UInt32.max)
        XCTAssertEqual(generator.next(), 0) // Wraps around
    }
    
    func testCurrent() {
        let generator = RequestIdGenerator(startingAt: 50)
        
        XCTAssertEqual(generator.current, 50)
        _ = generator.next()
        XCTAssertEqual(generator.current, 51)
    }
}

// MARK: - QueryIdGeneratorTests

final class QueryIdGeneratorTests: XCTestCase {
    
    func testSequentialGeneration() {
        let generator = QueryIdGenerator(startingAt: 1)
        
        XCTAssertEqual(generator.next().id, 1)
        XCTAssertEqual(generator.next().id, 2)
        XCTAssertEqual(generator.next().id, 3)
    }
    
    func testReturnsQueryId() {
        let generator = QueryIdGenerator()
        
        let queryId = generator.next()
        XCTAssertTrue(type(of: queryId) == QueryId.self)
    }
}

// MARK: - ConnectionErrorTests

final class ConnectionErrorTests: XCTestCase {
    
    func testNotConnectedDescription() {
        let error = ConnectionError.notConnected
        XCTAssertEqual(error.description, "Not connected to SpacetimeDB server")
    }
    
    func testReducerTimeoutDescription() {
        let error = ConnectionError.reducerTimeout(reducerName: "add_user", timeoutSeconds: 30.0)
        XCTAssertTrue(error.description.contains("add_user"))
        XCTAssertTrue(error.description.contains("30"))
    }
    
    func testReducerCallFailedDescription() {
        let error = ConnectionError.reducerCallFailed(reducerName: "delete_user", message: "User not found")
        XCTAssertTrue(error.description.contains("delete_user"))
        XCTAssertTrue(error.description.contains("User not found"))
    }
    
    func testBuilderMissingConfiguration() {
        let error = ConnectionError.builderMissingConfiguration(field: "uri")
        XCTAssertTrue(error.description.contains("uri"))
    }
    
    func testReconnectFailedDescription() {
        let error = ConnectionError.reconnectFailed(attempts: 5)
        XCTAssertTrue(error.description.contains("5"))
    }
}

// MARK: - ReducerResultTests

final class ReducerResultTests: XCTestCase {
    
    func testSuccessStatus() {
        let result = ReducerResult(
            reducerName: "test_reducer",
            requestId: 1,
            status: .success,
            timestamp: Timestamp(microseconds: 0),
            energyUsed: .zero,
            executionDuration: .zero
        )
        
        XCTAssertTrue(result.isSuccess)
        XCTAssertNil(result.errorMessage)
    }
    
    func testFailedStatus() {
        let result = ReducerResult(
            reducerName: "test_reducer",
            requestId: 1,
            status: .failed("Something went wrong"),
            timestamp: Timestamp(microseconds: 0),
            energyUsed: .zero,
            executionDuration: .zero
        )
        
        XCTAssertFalse(result.isSuccess)
        XCTAssertEqual(result.errorMessage, "Something went wrong")
    }
    
    func testOutOfEnergyStatus() {
        let result = ReducerResult(
            reducerName: "test_reducer",
            requestId: 1,
            status: .outOfEnergy,
            timestamp: Timestamp(microseconds: 0),
            energyUsed: .zero,
            executionDuration: .zero
        )
        
        XCTAssertFalse(result.isSuccess)
        XCTAssertNil(result.errorMessage)
    }
    
    func testDescription() {
        let successResult = ReducerResult(
            reducerName: "my_reducer",
            requestId: 1,
            status: .success,
            timestamp: Timestamp(microseconds: 0),
            energyUsed: .zero,
            executionDuration: .zero
        )
        XCTAssertTrue(successResult.description.contains("my_reducer"))
        XCTAssertTrue(successResult.description.contains("success"))
    }
}

// MARK: - SubscriptionHandleTests

final class SubscriptionHandleTests: XCTestCase {
    
    func testBatchSubscriptionHandle() {
        let handle = SubscriptionHandle(
            queryId: nil,
            queries: ["SELECT * FROM users", "SELECT * FROM messages"],
            requestId: 42,
            isBatchSubscription: true
        )
        
        XCTAssertNil(handle.queryId)
        XCTAssertEqual(handle.queries.count, 2)
        XCTAssertEqual(handle.requestId, 42)
        XCTAssertTrue(handle.isBatchSubscription)
        XCTAssertTrue(handle.description.contains("batch"))
    }
    
    func testSingleSubscriptionHandle() {
        let handle = SubscriptionHandle(
            queryId: QueryId(123),
            queries: ["SELECT * FROM users"],
            requestId: 99,
            isBatchSubscription: false
        )
        
        XCTAssertEqual(handle.queryId, QueryId(123))
        XCTAssertEqual(handle.queries.count, 1)
        XCTAssertFalse(handle.isBatchSubscription)
        XCTAssertTrue(handle.description.contains("queryId"))
    }
    
    func testHashable() {
        let handle1 = SubscriptionHandle(queryId: QueryId(1), queries: ["q1"], requestId: 1, isBatchSubscription: false)
        let handle2 = SubscriptionHandle(queryId: QueryId(1), queries: ["q1"], requestId: 1, isBatchSubscription: false)
        let handle3 = SubscriptionHandle(queryId: QueryId(2), queries: ["q2"], requestId: 2, isBatchSubscription: false)
        
        XCTAssertEqual(handle1, handle2)
        XCTAssertNotEqual(handle1, handle3)
        
        // Test use in Set
        var set: Set<SubscriptionHandle> = []
        set.insert(handle1)
        set.insert(handle2)
        XCTAssertEqual(set.count, 1)
    }
}

// MARK: - ConnectionBuilderTests

final class ConnectionBuilderTests: XCTestCase {
    
    func testMissingUriThrows() async {
        let builder = ConnectionBuilder()
            .withModuleName("test")
            .withoutAutoConnect()
        
        do {
            _ = try await builder.build()
            XCTFail("Expected error for missing URI")
        } catch let error as ConnectionError {
            if case .builderMissingConfiguration(let field) = error {
                XCTAssertEqual(field, "uri")
            } else {
                XCTFail("Wrong error type: \(error)")
            }
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }
    
    func testMissingModuleNameThrows() async {
        let builder = ConnectionBuilder()
            .withUri(URL(string: "ws://localhost:3000")!)
            .withoutAutoConnect()
        
        do {
            _ = try await builder.build()
            XCTFail("Expected error for missing module name")
        } catch let error as ConnectionError {
            if case .builderMissingConfiguration(let field) = error {
                XCTAssertEqual(field, "moduleName")
            } else {
                XCTFail("Wrong error type: \(error)")
            }
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }
    
    func testBuilderChaining() {
        let builder = ConnectionBuilder()
            .withUri(URL(string: "ws://localhost:3000")!)
            .withModuleName("test_module")
            .withToken("test_token")
            .withConfiguration(.noReconnect)
            .withReducerCallTimeout(60.0)
            .withoutAutoConnect()
        
        XCTAssertEqual(builder.uri?.absoluteString, "ws://localhost:3000")
        XCTAssertEqual(builder.moduleName, "test_module")
        XCTAssertEqual(builder.token, "test_token")
        XCTAssertEqual(builder.reducerCallTimeout, 60.0)
        XCTAssertFalse(builder.autoConnect)
    }
    
    func testStaticBuilderMethod() {
        // This tests that SpacetimeDBConnection.builder() is available
        let builder = SpacetimeDBConnection.builder()
        XCTAssertTrue(type(of: builder) == ConnectionBuilder.self)
    }
}

// MARK: - ActiveSubscriptionRegistryTests

final class ActiveSubscriptionRegistryTests: XCTestCase {
    
    func testRegisterAndGetQueries() {
        let registry = ActiveSubscriptionRegistry()
        
        let handle1 = SubscriptionHandle(
            queryId: QueryId(1),
            queries: ["SELECT * FROM users"],
            requestId: 1,
            isBatchSubscription: false
        )
        let handle2 = SubscriptionHandle(
            queryId: QueryId(2),
            queries: ["SELECT * FROM messages", "SELECT * FROM channels"],
            requestId: 2,
            isBatchSubscription: true
        )
        
        registry.register(handle1)
        registry.register(handle2)
        
        let queries = registry.getAllQueries()
        XCTAssertEqual(queries.count, 3)
        XCTAssertTrue(queries.contains("SELECT * FROM users"))
        XCTAssertTrue(queries.contains("SELECT * FROM messages"))
        XCTAssertTrue(queries.contains("SELECT * FROM channels"))
    }
    
    func testRemoveSubscription() {
        let registry = ActiveSubscriptionRegistry()
        
        let handle = SubscriptionHandle(
            queryId: QueryId(1),
            queries: ["SELECT * FROM users"],
            requestId: 1,
            isBatchSubscription: false
        )
        
        registry.register(handle)
        XCTAssertEqual(registry.count, 1)
        
        registry.remove(handle)
        XCTAssertEqual(registry.count, 0)
        XCTAssertTrue(registry.getAllQueries().isEmpty)
    }
    
    func testClear() {
        let registry = ActiveSubscriptionRegistry()
        
        let handle = SubscriptionHandle(queryId: nil, queries: ["q1", "q2"], requestId: 1, isBatchSubscription: true)
        registry.register(handle)
        
        registry.clear()
        XCTAssertEqual(registry.count, 0)
    }
}

// MARK: - Update Detection Tests

final class UpdateDetectionTests: XCTestCase {
    
    func testUpdateDetectionWithMatchingPKs() async throws {
        let cache = ClientCache()
        
        // Create test data with a primary key extractor
        // PK is first 4 bytes (u32)
        let pkExtractor = PrimaryKeyExtractor.u32AtStart
        PrimaryKeyExtractorRegistry.shared.register(tableName: "test_table", extractor: pkExtractor)
        
        // Setup: insert initial row with PK=1, value=10
        let pk: UInt32 = 1
        let initialValue: UInt32 = 10
        var initialRow = Data()
        withUnsafeBytes(of: pk.littleEndian) { initialRow.append(contentsOf: $0) }
        withUnsafeBytes(of: initialValue.littleEndian) { initialRow.append(contentsOf: $0) }
        
        let tableCache = await cache.table(named: "test_table")
        tableCache.insert(initialRow)
        
        XCTAssertEqual(tableCache.count, 1)
        
        // Prepare update: delete old row, insert new row with same PK but different value
        let newValue: UInt32 = 20
        var newRow = Data()
        withUnsafeBytes(of: pk.littleEndian) { newRow.append(contentsOf: $0) }
        withUnsafeBytes(of: newValue.littleEndian) { newRow.append(contentsOf: $0) }
        
        // Track callback invocations
        var updateCalled = false
        var insertCalled = false
        var deleteCalled = false
        
        await cache.onChange(tableName: "test_table") { _, operation in
            switch operation {
            case .update:
                updateCalled = true
            case .insert:
                insertCalled = true
            case .delete:
                deleteCalled = true
            }
        }
        
        // Create QueryUpdate with delete and insert for same PK
        let queryUpdate = QueryUpdate(
            deletes: BsatnRowList(sizeHint: .fixedSize(8), rowsData: initialRow),
            inserts: BsatnRowList(sizeHint: .fixedSize(8), rowsData: newRow)
        )
        
        let tableUpdate = TableUpdate(
            tableId: TableId(1),
            tableName: "test_table",
            numRows: 1,
            updates: [.uncompressed(queryUpdate)]
        )
        
        let dbUpdate = DatabaseUpdate(tables: [tableUpdate])
        try await cache.applyDatabaseUpdate(dbUpdate)
        
        // Should have called update callback, not delete + insert
        XCTAssertTrue(updateCalled, "Update callback should have been called")
        XCTAssertFalse(insertCalled, "Insert callback should NOT have been called")
        XCTAssertFalse(deleteCalled, "Delete callback should NOT have been called")
        
        // Row should still exist with new value
        XCTAssertEqual(tableCache.count, 1)
        
        // Cleanup
        PrimaryKeyExtractorRegistry.shared.unregister(tableName: "test_table")
    }
    
    func testPureDeleteAndInsert() async throws {
        let cache = ClientCache()
        
        // Create test data
        // Row 1: PK=1
        var row1 = Data()
        let pk1: UInt32 = 1
        withUnsafeBytes(of: pk1.littleEndian) { row1.append(contentsOf: $0) }
        
        // Row 2: PK=2 (different)
        var row2 = Data()
        let pk2: UInt32 = 2
        withUnsafeBytes(of: pk2.littleEndian) { row2.append(contentsOf: $0) }
        
        let pkExtractor = PrimaryKeyExtractor.u32AtStart
        PrimaryKeyExtractorRegistry.shared.register(tableName: "test_table2", extractor: pkExtractor)
        
        // Insert row1
        let tableCache = await cache.table(named: "test_table2")
        tableCache.insert(row1)
        
        var deleteCalled = false
        var insertCalled = false
        var updateCalled = false
        
        await cache.onChange(tableName: "test_table2") { _, operation in
            switch operation {
            case .update:
                updateCalled = true
            case .insert:
                insertCalled = true
            case .delete:
                deleteCalled = true
            }
        }
        
        // QueryUpdate: delete row1 (PK=1), insert row2 (PK=2) - different PKs
        let queryUpdate = QueryUpdate(
            deletes: BsatnRowList(sizeHint: .fixedSize(4), rowsData: row1),
            inserts: BsatnRowList(sizeHint: .fixedSize(4), rowsData: row2)
        )
        
        let tableUpdate = TableUpdate(
            tableId: TableId(2),
            tableName: "test_table2",
            numRows: 2,
            updates: [.uncompressed(queryUpdate)]
        )
        
        let dbUpdate = DatabaseUpdate(tables: [tableUpdate])
        try await cache.applyDatabaseUpdate(dbUpdate)
        
        // Should have called both delete and insert, but NOT update
        XCTAssertTrue(deleteCalled, "Delete callback should have been called")
        XCTAssertTrue(insertCalled, "Insert callback should have been called")
        XCTAssertFalse(updateCalled, "Update callback should NOT have been called")
        
        // Should have row2 now
        XCTAssertEqual(tableCache.count, 1)
        
        // Cleanup
        PrimaryKeyExtractorRegistry.shared.unregister(tableName: "test_table2")
    }
}
