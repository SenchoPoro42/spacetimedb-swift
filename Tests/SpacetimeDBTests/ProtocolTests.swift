//
//  ProtocolTests.swift
//  SpacetimeDB
//
//  Unit tests for protocol message BSATN encoding/decoding.
//

import XCTest
@testable import SpacetimeDB

final class ProtocolTests: XCTestCase {
    
    // MARK: - Common Types Tests
    
    func testQueryIdRoundtrip() throws {
        let queryId = QueryId(12345)
        let data = try BSATNEncoder.encode(queryId)
        let decoded = try BSATNDecoder.decode(QueryId.self, from: data)
        XCTAssertEqual(queryId.id, decoded.id)
    }
    
    func testCallReducerFlagsEncoding() throws {
        // FullUpdate = 0
        let fullUpdate = CallReducerFlags.fullUpdate
        let fullUpdateData = try BSATNEncoder.encode(fullUpdate)
        XCTAssertEqual(fullUpdateData, Data([0x00]))
        
        // NoSuccessNotify = 1
        let noNotify = CallReducerFlags.noSuccessNotify
        let noNotifyData = try BSATNEncoder.encode(noNotify)
        XCTAssertEqual(noNotifyData, Data([0x01]))
        
        // Roundtrip
        let decoded = try BSATNDecoder.decode(CallReducerFlags.self, from: fullUpdateData)
        XCTAssertEqual(decoded, .fullUpdate)
    }
    
    func testCallReducerFlagsInvalidTag() throws {
        let invalidData = Data([0x05])  // Invalid tag
        XCTAssertThrowsError(try BSATNDecoder.decode(CallReducerFlags.self, from: invalidData)) { error in
            guard case BSATNDecodingError.invalidEnumTag(let tag, let typeName) = error else {
                XCTFail("Expected invalidEnumTag error")
                return
            }
            XCTAssertEqual(tag, 5)
            XCTAssertEqual(typeName, "CallReducerFlags")
        }
    }
    
    func testTableIdRoundtrip() throws {
        let tableId = TableId(42)
        let data = try BSATNEncoder.encode(tableId)
        let decoded = try BSATNDecoder.decode(TableId.self, from: data)
        XCTAssertEqual(tableId.id, decoded.id)
    }
    
    func testEnergyQuantaRoundtrip() throws {
        // Test positive value
        let energy = EnergyQuanta(1000)
        let data = try BSATNEncoder.encode(energy)
        let decoded = try BSATNDecoder.decode(EnergyQuanta.self, from: data)
        XCTAssertEqual(decoded.asInt64, 1000)
        
        // Test zero
        let zeroEnergy = EnergyQuanta.zero
        let zeroData = try BSATNEncoder.encode(zeroEnergy)
        let zeroDecoded = try BSATNDecoder.decode(EnergyQuanta.self, from: zeroData)
        XCTAssertEqual(zeroDecoded.asInt64, 0)
        
        // Test negative value
        let negEnergy = EnergyQuanta(-500)
        let negData = try BSATNEncoder.encode(negEnergy)
        let negDecoded = try BSATNDecoder.decode(EnergyQuanta.self, from: negData)
        XCTAssertEqual(negDecoded.asInt64, -500)
    }
    
    // MARK: - TimeDuration Tests
    
    func testTimeDurationRoundtrip() throws {
        let duration = TimeDuration(nanoseconds: 123_456_789)
        let data = try BSATNEncoder.encode(duration)
        let decoded = try BSATNDecoder.decode(TimeDuration.self, from: data)
        XCTAssertEqual(duration.nanoseconds, decoded.nanoseconds)
    }
    
    func testTimeDurationConversions() {
        let duration = TimeDuration(milliseconds: 1500)
        XCTAssertEqual(duration.nanoseconds, 1_500_000_000)
        XCTAssertEqual(duration.microseconds, 1_500_000)
        XCTAssertEqual(duration.milliseconds, 1500)
        XCTAssertEqual(duration.seconds, 1.5, accuracy: 0.001)
    }
    
    // MARK: - Database Update Types Tests
    
    func testRowSizeHintFixedSize() throws {
        let hint = RowSizeHint.fixedSize(32)
        let data = try BSATNEncoder.encode(hint)
        let decoded = try BSATNDecoder.decode(RowSizeHint.self, from: data)
        
        if case .fixedSize(let size) = decoded {
            XCTAssertEqual(size, 32)
        } else {
            XCTFail("Expected fixedSize")
        }
    }
    
    func testRowSizeHintRowOffsets() throws {
        let offsets: [UInt64] = [0, 10, 25, 50]
        let hint = RowSizeHint.rowOffsets(offsets)
        let data = try BSATNEncoder.encode(hint)
        let decoded = try BSATNDecoder.decode(RowSizeHint.self, from: data)
        
        if case .rowOffsets(let decodedOffsets) = decoded {
            XCTAssertEqual(decodedOffsets, offsets)
        } else {
            XCTFail("Expected rowOffsets")
        }
    }
    
    func testBsatnRowListFixedSize() throws {
        // Create a row list with 3 rows of 4 bytes each
        let rowsData = Data([
            0x01, 0x00, 0x00, 0x00,  // row 0
            0x02, 0x00, 0x00, 0x00,  // row 1
            0x03, 0x00, 0x00, 0x00,  // row 2
        ])
        let list = BsatnRowList(sizeHint: .fixedSize(4), rowsData: rowsData)
        
        XCTAssertEqual(list.count, 3)
        XCTAssertFalse(list.isEmpty)
        XCTAssertEqual(list.byteCount, 12)
        
        // Test row access
        XCTAssertEqual(list.rowData(at: 0), Data([0x01, 0x00, 0x00, 0x00]))
        XCTAssertEqual(list.rowData(at: 1), Data([0x02, 0x00, 0x00, 0x00]))
        XCTAssertEqual(list.rowData(at: 2), Data([0x03, 0x00, 0x00, 0x00]))
        XCTAssertNil(list.rowData(at: 3))
        
        // Test roundtrip
        let data = try BSATNEncoder.encode(list)
        let decoded = try BSATNDecoder.decode(BsatnRowList.self, from: data)
        XCTAssertEqual(decoded.count, 3)
    }
    
    func testBsatnRowListRowOffsets() throws {
        // Variable-size rows: "hello" (5), "hi" (2), "world!" (6)
        let rowsData = Data("hellohi world!".utf8)
        let offsets: [UInt64] = [0, 5, 7]  // Start positions
        let list = BsatnRowList(sizeHint: .rowOffsets(offsets), rowsData: rowsData)
        
        XCTAssertEqual(list.count, 3)
        XCTAssertEqual(list.rowData(at: 0), Data("hello".utf8))
        XCTAssertEqual(list.rowData(at: 1), Data("hi".utf8))
        XCTAssertEqual(list.rowData(at: 2), Data(" world!".utf8))
    }
    
    func testBsatnRowListIteration() {
        let rowsData = Data([0x01, 0x02, 0x03, 0x04])
        let list = BsatnRowList(sizeHint: .fixedSize(1), rowsData: rowsData)
        
        var values: [UInt8] = []
        for row in list {
            values.append(row[0])
        }
        XCTAssertEqual(values, [0x01, 0x02, 0x03, 0x04])
    }
    
    func testEmptyDatabaseUpdate() throws {
        let update = DatabaseUpdate.empty
        XCTAssertTrue(update.isEmpty)
        XCTAssertEqual(update.totalRowCount, 0)
        
        let data = try BSATNEncoder.encode(update)
        let decoded = try BSATNDecoder.decode(DatabaseUpdate.self, from: data)
        XCTAssertTrue(decoded.isEmpty)
    }
    
    func testCompressableQueryUpdate() throws {
        let queryUpdate = QueryUpdate(deletes: .empty, inserts: .empty)
        let compressable = CompressableQueryUpdate.uncompressed(queryUpdate)
        
        let data = try BSATNEncoder.encode(compressable)
        let decoded = try BSATNDecoder.decode(CompressableQueryUpdate.self, from: data)
        
        if case .uncompressed(let decodedUpdate) = decoded {
            XCTAssertEqual(decodedUpdate.deletes.count, 0)
            XCTAssertEqual(decodedUpdate.inserts.count, 0)
        } else {
            XCTFail("Expected uncompressed")
        }
    }
    
    // MARK: - Subscription Types Tests
    
    func testSubscribeRoundtrip() throws {
        let subscribe = Subscribe(
            queryStrings: ["SELECT * FROM users", "SELECT * FROM messages"],
            requestId: 42
        )
        
        let data = try BSATNEncoder.encode(subscribe)
        let decoded = try BSATNDecoder.decode(Subscribe.self, from: data)
        
        XCTAssertEqual(decoded.queryStrings, subscribe.queryStrings)
        XCTAssertEqual(decoded.requestId, subscribe.requestId)
    }
    
    func testSubscribeSingleRoundtrip() throws {
        let subscribe = SubscribeSingle(
            query: "SELECT * FROM users WHERE online = true",
            requestId: 1,
            queryId: QueryId(100)
        )
        
        let data = try BSATNEncoder.encode(subscribe)
        let decoded = try BSATNDecoder.decode(SubscribeSingle.self, from: data)
        
        XCTAssertEqual(decoded.query, subscribe.query)
        XCTAssertEqual(decoded.requestId, subscribe.requestId)
        XCTAssertEqual(decoded.queryId.id, subscribe.queryId.id)
    }
    
    func testUnsubscribeRoundtrip() throws {
        let unsubscribe = Unsubscribe(requestId: 5, queryId: QueryId(100))
        
        let data = try BSATNEncoder.encode(unsubscribe)
        let decoded = try BSATNDecoder.decode(Unsubscribe.self, from: data)
        
        XCTAssertEqual(decoded.requestId, unsubscribe.requestId)
        XCTAssertEqual(decoded.queryId.id, unsubscribe.queryId.id)
    }
    
    func testSubscriptionErrorWithOptionalFields() throws {
        // All optional fields present
        let error1 = SubscriptionError(
            totalHostExecutionDurationMicros: 1000,
            requestId: 42,
            queryId: 100,
            tableId: TableId(5),
            error: "Query failed: syntax error"
        )
        
        let data1 = try BSATNEncoder.encode(error1)
        let decoded1 = try BSATNDecoder.decode(SubscriptionError.self, from: data1)
        
        XCTAssertEqual(decoded1.requestId, 42)
        XCTAssertEqual(decoded1.queryId, 100)
        XCTAssertEqual(decoded1.tableId?.id, 5)
        XCTAssertEqual(decoded1.error, "Query failed: syntax error")
        
        // All optional fields nil
        let error2 = SubscriptionError(
            totalHostExecutionDurationMicros: 500,
            requestId: nil,
            queryId: nil,
            tableId: nil,
            error: "Connection lost"
        )
        
        let data2 = try BSATNEncoder.encode(error2)
        let decoded2 = try BSATNDecoder.decode(SubscriptionError.self, from: data2)
        
        XCTAssertNil(decoded2.requestId)
        XCTAssertNil(decoded2.queryId)
        XCTAssertNil(decoded2.tableId)
        XCTAssertEqual(decoded2.error, "Connection lost")
    }
    
    // MARK: - Transaction Types Tests
    
    func testCallReducerRoundtrip() throws {
        let args = Data([0x01, 0x02, 0x03, 0x04])
        let call = CallReducer(
            reducer: "create_user",
            args: args,
            requestId: 123,
            flags: .fullUpdate
        )
        
        let data = try BSATNEncoder.encode(call)
        let decoded = try BSATNDecoder.decode(CallReducer.self, from: data)
        
        XCTAssertEqual(decoded.reducer, call.reducer)
        XCTAssertEqual(decoded.args, call.args)
        XCTAssertEqual(decoded.requestId, call.requestId)
        XCTAssertEqual(decoded.flags, .fullUpdate)
    }
    
    func testIdentityTokenRoundtrip() throws {
        let identity = Identity(UInt256(b0: 1, b1: 2, b2: 3, b3: 4))
        let connectionId = ConnectionId(100)
        
        let token = IdentityToken(
            identity: identity,
            token: "auth_token_12345",
            connectionId: connectionId
        )
        
        let data = try BSATNEncoder.encode(token)
        let decoded = try BSATNDecoder.decode(IdentityToken.self, from: data)
        
        XCTAssertEqual(decoded.identity, identity)
        XCTAssertEqual(decoded.token, token.token)
        XCTAssertEqual(decoded.connectionId, connectionId)
    }
    
    func testUpdateStatusCommitted() throws {
        let status = UpdateStatus.committed(.empty)
        let data = try BSATNEncoder.encode(status)
        let decoded = try BSATNDecoder.decode(UpdateStatus.self, from: data)
        
        if case .committed(let update) = decoded {
            XCTAssertTrue(update.isEmpty)
        } else {
            XCTFail("Expected committed status")
        }
    }
    
    func testUpdateStatusFailed() throws {
        let status = UpdateStatus.failed("Reducer panicked: division by zero")
        let data = try BSATNEncoder.encode(status)
        let decoded = try BSATNDecoder.decode(UpdateStatus.self, from: data)
        
        if case .failed(let message) = decoded {
            XCTAssertEqual(message, "Reducer panicked: division by zero")
        } else {
            XCTFail("Expected failed status")
        }
    }
    
    func testUpdateStatusOutOfEnergy() throws {
        let status = UpdateStatus.outOfEnergy
        let data = try BSATNEncoder.encode(status)
        let decoded = try BSATNDecoder.decode(UpdateStatus.self, from: data)
        
        if case .outOfEnergy = decoded {
            // Success
        } else {
            XCTFail("Expected outOfEnergy status")
        }
    }
    
    // MARK: - ClientMessage Tests
    
    func testClientMessageCallReducer() throws {
        let call = CallReducer(reducer: "test_reducer", args: Data(), requestId: 1, flags: .fullUpdate)
        let message = ClientMessage.callReducer(call)
        
        let data = try BSATNEncoder.encode(message)
        
        // First byte should be tag 0
        XCTAssertEqual(data[0], 0x00)
        
        let decoded = try BSATNDecoder.decode(ClientMessage.self, from: data)
        if case .callReducer(let decodedCall) = decoded {
            XCTAssertEqual(decodedCall.reducer, "test_reducer")
        } else {
            XCTFail("Expected callReducer")
        }
    }
    
    func testClientMessageSubscribe() throws {
        let subscribe = Subscribe(queryStrings: ["SELECT * FROM users"], requestId: 2)
        let message = ClientMessage.subscribe(subscribe)
        
        let data = try BSATNEncoder.encode(message)
        
        // First byte should be tag 1
        XCTAssertEqual(data[0], 0x01)
        
        let decoded = try BSATNDecoder.decode(ClientMessage.self, from: data)
        if case .subscribe(let decodedSubscribe) = decoded {
            XCTAssertEqual(decodedSubscribe.queryStrings, ["SELECT * FROM users"])
        } else {
            XCTFail("Expected subscribe")
        }
    }
    
    func testClientMessageRequestId() {
        let call = CallReducer(reducer: "test", args: Data(), requestId: 42, flags: .fullUpdate)
        let message = ClientMessage.callReducer(call)
        XCTAssertEqual(message.requestId, 42)
        
        let oneOff = OneOffQuery(messageId: Data([0x01]), queryString: "SELECT 1")
        let oneOffMessage = ClientMessage.oneOffQuery(oneOff)
        XCTAssertNil(oneOffMessage.requestId)
    }
    
    // MARK: - ServerMessage Tests
    
    func testServerMessageIdentityToken() throws {
        let identity = Identity.zero
        let connectionId = ConnectionId.zero
        let token = IdentityToken(identity: identity, token: "test_token", connectionId: connectionId)
        let message = ServerMessage.identityToken(token)
        
        let data = try BSATNEncoder.encode(message)
        
        // First byte should be tag 3
        XCTAssertEqual(data[0], 0x03)
        
        let decoded = try BSATNDecoder.decode(ServerMessage.self, from: data)
        if case .identityToken(let decodedToken) = decoded {
            XCTAssertEqual(decodedToken.token, "test_token")
        } else {
            XCTFail("Expected identityToken")
        }
    }
    
    func testServerMessageSubscriptionError() throws {
        let error = SubscriptionError(
            totalHostExecutionDurationMicros: 100,
            requestId: 1,
            queryId: 2,
            tableId: nil,
            error: "Test error"
        )
        let message = ServerMessage.subscriptionError(error)
        
        XCTAssertTrue(message.isError)
        
        let data = try BSATNEncoder.encode(message)
        let decoded = try BSATNDecoder.decode(ServerMessage.self, from: data)
        
        if case .subscriptionError(let decodedError) = decoded {
            XCTAssertEqual(decodedError.error, "Test error")
        } else {
            XCTFail("Expected subscriptionError")
        }
    }
    
    func testServerMessageHasDatabaseUpdate() {
        let subscription = InitialSubscription(
            databaseUpdate: .empty,
            requestId: 1,
            totalHostExecutionDuration: .zero
        )
        let message = ServerMessage.initialSubscription(subscription)
        XCTAssertTrue(message.hasDatabaseUpdate)
        
        let identity = Identity.zero
        let connectionId = ConnectionId.zero
        let tokenMessage = ServerMessage.identityToken(
            IdentityToken(identity: identity, token: "", connectionId: connectionId)
        )
        XCTAssertFalse(tokenMessage.hasDatabaseUpdate)
    }
    
    func testServerMessageInvalidTag() throws {
        let invalidData = Data([0xFF])  // Invalid tag
        XCTAssertThrowsError(try BSATNDecoder.decode(ServerMessage.self, from: invalidData))
    }
    
    // MARK: - Complex Roundtrip Tests
    
    func testTransactionUpdateRoundtrip() throws {
        let identity = Identity(UInt256(b0: 1, b1: 0, b2: 0, b3: 0))
        let connectionId = ConnectionId(42)
        
        let reducerCall = ReducerCallInfo(
            reducerName: "create_entity",
            reducerId: 5,
            args: Data([0x01, 0x02]),
            requestId: 100
        )
        
        let txUpdate = TransactionUpdate(
            status: .committed(.empty),
            timestamp: Timestamp(microseconds: 1234567890),
            callerIdentity: identity,
            callerConnectionId: connectionId,
            reducerCall: reducerCall,
            energyQuantaUsed: EnergyQuanta(500),
            totalHostExecutionDuration: TimeDuration(microseconds: 150)
        )
        
        let message = ServerMessage.transactionUpdate(txUpdate)
        let data = try BSATNEncoder.encode(message)
        let decoded = try BSATNDecoder.decode(ServerMessage.self, from: data)
        
        if case .transactionUpdate(let decodedTx) = decoded {
            XCTAssertEqual(decodedTx.timestamp.microseconds, 1234567890)
            XCTAssertEqual(decodedTx.reducerCall.reducerName, "create_entity")
            XCTAssertEqual(decodedTx.reducerCall.reducerId, 5)
            XCTAssertEqual(decodedTx.energyQuantaUsed.asInt64, 500)
            
            if case .committed(let update) = decodedTx.status {
                XCTAssertTrue(update.isEmpty)
            } else {
                XCTFail("Expected committed status")
            }
        } else {
            XCTFail("Expected transactionUpdate")
        }
    }
    
    func testTableUpdateWithRows() throws {
        // Create some row data
        let rowsData = Data([0x01, 0x00, 0x00, 0x00, 0x02, 0x00, 0x00, 0x00])  // Two 4-byte rows
        let rowList = BsatnRowList(sizeHint: .fixedSize(4), rowsData: rowsData)
        let queryUpdate = QueryUpdate(deletes: .empty, inserts: rowList)
        let compressable = CompressableQueryUpdate.uncompressed(queryUpdate)
        
        let tableUpdate = TableUpdate(
            tableId: TableId(1),
            tableName: "users",
            numRows: 2,
            updates: [compressable]
        )
        
        let data = try BSATNEncoder.encode(tableUpdate)
        let decoded = try BSATNDecoder.decode(TableUpdate.self, from: data)
        
        XCTAssertEqual(decoded.tableId.id, 1)
        XCTAssertEqual(decoded.tableName, "users")
        XCTAssertEqual(decoded.numRows, 2)
        XCTAssertEqual(decoded.updates.count, 1)
    }
}
