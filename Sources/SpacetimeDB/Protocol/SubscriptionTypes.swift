//
//  SubscriptionTypes.swift
//  SpacetimeDB
//
//  Subscription request and response types.
//

import Foundation

// MARK: - Client → Server Types

/// Request to subscribe to a set of SQL queries.
///
/// After sending this message, the client will receive a single `InitialSubscription`
/// containing all matching rows, then `TransactionUpdate`s for changes.
///
/// A `Subscribe` message sets or replaces the entire set of queries the client
/// is subscribed to.
public struct Subscribe: Sendable {
    /// SQL SELECT queries to subscribe to.
    public let queryStrings: [String]
    
    /// Client-provided request identifier.
    public let requestId: UInt32
    
    public init(queryStrings: [String], requestId: UInt32) {
        self.queryStrings = queryStrings
        self.requestId = requestId
    }
}

extension Subscribe: BSATNCodable {
    public func encode(to encoder: inout BSATNEncoder) throws {
        try queryStrings.encode(to: &encoder)
        encoder.encode(requestId)
    }
    
    public init(from decoder: inout BSATNDecoder) throws {
        self.queryStrings = try [String](from: &decoder)
        self.requestId = try decoder.decode(UInt32.self)
    }
}

/// Request to subscribe to a single SQL query.
///
/// Unlike `Subscribe`, this adds to existing subscriptions rather than replacing them.
public struct SubscribeSingle: Sendable {
    /// A single SQL SELECT query to subscribe to.
    public let query: String
    
    /// Client-provided request identifier.
    public let requestId: UInt32
    
    /// Client-provided query identifier for later unsubscription.
    public let queryId: QueryId
    
    public init(query: String, requestId: UInt32, queryId: QueryId) {
        self.query = query
        self.requestId = requestId
        self.queryId = queryId
    }
}

extension SubscribeSingle: BSATNCodable {
    public func encode(to encoder: inout BSATNEncoder) throws {
        try query.encode(to: &encoder)
        encoder.encode(requestId)
        try queryId.encode(to: &encoder)
    }
    
    public init(from decoder: inout BSATNDecoder) throws {
        self.query = try String(from: &decoder)
        self.requestId = try decoder.decode(UInt32.self)
        self.queryId = try QueryId(from: &decoder)
    }
}

/// Request to subscribe to multiple SQL queries as a group.
public struct SubscribeMulti: Sendable {
    /// SQL SELECT queries to subscribe to.
    public let queryStrings: [String]
    
    /// Client-provided request identifier.
    public let requestId: UInt32
    
    /// Client-provided query identifier for later unsubscription.
    public let queryId: QueryId
    
    public init(queryStrings: [String], requestId: UInt32, queryId: QueryId) {
        self.queryStrings = queryStrings
        self.requestId = requestId
        self.queryId = queryId
    }
}

extension SubscribeMulti: BSATNCodable {
    public func encode(to encoder: inout BSATNEncoder) throws {
        try queryStrings.encode(to: &encoder)
        encoder.encode(requestId)
        try queryId.encode(to: &encoder)
    }
    
    public init(from decoder: inout BSATNDecoder) throws {
        self.queryStrings = try [String](from: &decoder)
        self.requestId = try decoder.decode(UInt32.self)
        self.queryId = try QueryId(from: &decoder)
    }
}

/// Request to unsubscribe from a single query.
public struct Unsubscribe: Sendable {
    /// Client-provided request identifier.
    public let requestId: UInt32
    
    /// The query ID from the original `SubscribeSingle` message.
    public let queryId: QueryId
    
    public init(requestId: UInt32, queryId: QueryId) {
        self.requestId = requestId
        self.queryId = queryId
    }
}

extension Unsubscribe: BSATNCodable {
    public func encode(to encoder: inout BSATNEncoder) throws {
        encoder.encode(requestId)
        try queryId.encode(to: &encoder)
    }
    
    public init(from decoder: inout BSATNDecoder) throws {
        self.requestId = try decoder.decode(UInt32.self)
        self.queryId = try QueryId(from: &decoder)
    }
}

/// Request to unsubscribe from a multi-query subscription.
public struct UnsubscribeMulti: Sendable {
    /// Client-provided request identifier.
    public let requestId: UInt32
    
    /// The query ID from the original `SubscribeMulti` message.
    public let queryId: QueryId
    
    public init(requestId: UInt32, queryId: QueryId) {
        self.requestId = requestId
        self.queryId = queryId
    }
}

extension UnsubscribeMulti: BSATNCodable {
    public func encode(to encoder: inout BSATNEncoder) throws {
        encoder.encode(requestId)
        try queryId.encode(to: &encoder)
    }
    
    public init(from decoder: inout BSATNDecoder) throws {
        self.requestId = try decoder.decode(UInt32.self)
        self.queryId = try QueryId(from: &decoder)
    }
}

/// A one-off query submission (not a subscription).
///
/// Results are returned once without establishing a subscription.
public struct OneOffQuery: Sendable {
    /// Client-generated message ID for matching responses.
    public let messageId: Data
    
    /// SQL query string (SELECT * FROM ... WHERE ...).
    public let queryString: String
    
    public init(messageId: Data, queryString: String) {
        self.messageId = messageId
        self.queryString = queryString
    }
}

extension OneOffQuery: BSATNCodable {
    public func encode(to encoder: inout BSATNEncoder) throws {
        try messageId.encode(to: &encoder)
        try queryString.encode(to: &encoder)
    }
    
    public init(from decoder: inout BSATNDecoder) throws {
        self.messageId = try Data(from: &decoder)
        self.queryString = try String(from: &decoder)
    }
}

// MARK: - Server → Client Types

/// Response to `Subscribe` containing the initial matching rows.
public struct InitialSubscription: Sendable {
    /// All rows matching the subscription queries.
    public let databaseUpdate: DatabaseUpdate
    
    /// The request ID from the original `Subscribe` message.
    public let requestId: UInt32
    
    /// Time to process the subscription.
    public let totalHostExecutionDuration: TimeDuration
    
    public init(databaseUpdate: DatabaseUpdate, requestId: UInt32, totalHostExecutionDuration: TimeDuration) {
        self.databaseUpdate = databaseUpdate
        self.requestId = requestId
        self.totalHostExecutionDuration = totalHostExecutionDuration
    }
}

extension InitialSubscription: BSATNCodable {
    public func encode(to encoder: inout BSATNEncoder) throws {
        try databaseUpdate.encode(to: &encoder)
        encoder.encode(requestId)
        try totalHostExecutionDuration.encode(to: &encoder)
    }
    
    public init(from decoder: inout BSATNDecoder) throws {
        self.databaseUpdate = try DatabaseUpdate(from: &decoder)
        self.requestId = try decoder.decode(UInt32.self)
        self.totalHostExecutionDuration = try TimeDuration(from: &decoder)
    }
}

/// Response to `SubscribeSingle` containing the initial matching rows.
public struct SubscribeApplied: Sendable {
    /// The request ID from the original message.
    public let requestId: UInt32
    
    /// Time to process the subscription in microseconds.
    public let totalHostExecutionDurationMicros: UInt64
    
    /// The query ID from the original message.
    public let queryId: QueryId
    
    /// The matching rows for this query.
    public let rows: SubscribeRows
    
    public init(requestId: UInt32, totalHostExecutionDurationMicros: UInt64, queryId: QueryId, rows: SubscribeRows) {
        self.requestId = requestId
        self.totalHostExecutionDurationMicros = totalHostExecutionDurationMicros
        self.queryId = queryId
        self.rows = rows
    }
}

extension SubscribeApplied: BSATNCodable {
    public func encode(to encoder: inout BSATNEncoder) throws {
        encoder.encode(requestId)
        encoder.encode(totalHostExecutionDurationMicros)
        try queryId.encode(to: &encoder)
        try rows.encode(to: &encoder)
    }
    
    public init(from decoder: inout BSATNDecoder) throws {
        self.requestId = try decoder.decode(UInt32.self)
        self.totalHostExecutionDurationMicros = try decoder.decode(UInt64.self)
        self.queryId = try QueryId(from: &decoder)
        self.rows = try SubscribeRows(from: &decoder)
    }
}

/// Response to `Unsubscribe` containing the final matching rows.
public struct UnsubscribeApplied: Sendable {
    /// The request ID from the original message.
    public let requestId: UInt32
    
    /// Time to process the unsubscription in microseconds.
    public let totalHostExecutionDurationMicros: UInt64
    
    /// The query ID from the original message.
    public let queryId: QueryId
    
    /// The matching rows at the time of unsubscription.
    public let rows: SubscribeRows
    
    public init(requestId: UInt32, totalHostExecutionDurationMicros: UInt64, queryId: QueryId, rows: SubscribeRows) {
        self.requestId = requestId
        self.totalHostExecutionDurationMicros = totalHostExecutionDurationMicros
        self.queryId = queryId
        self.rows = rows
    }
}

extension UnsubscribeApplied: BSATNCodable {
    public func encode(to encoder: inout BSATNEncoder) throws {
        encoder.encode(requestId)
        encoder.encode(totalHostExecutionDurationMicros)
        try queryId.encode(to: &encoder)
        try rows.encode(to: &encoder)
    }
    
    public init(from decoder: inout BSATNDecoder) throws {
        self.requestId = try decoder.decode(UInt32.self)
        self.totalHostExecutionDurationMicros = try decoder.decode(UInt64.self)
        self.queryId = try QueryId(from: &decoder)
        self.rows = try SubscribeRows(from: &decoder)
    }
}

/// Response to `SubscribeMulti` containing the initial matching rows.
public struct SubscribeMultiApplied: Sendable {
    /// The request ID from the original message.
    public let requestId: UInt32
    
    /// Time to process the subscription in microseconds.
    public let totalHostExecutionDurationMicros: UInt64
    
    /// The query ID from the original message.
    public let queryId: QueryId
    
    /// The matching rows for all queries.
    public let update: DatabaseUpdate
    
    public init(requestId: UInt32, totalHostExecutionDurationMicros: UInt64, queryId: QueryId, update: DatabaseUpdate) {
        self.requestId = requestId
        self.totalHostExecutionDurationMicros = totalHostExecutionDurationMicros
        self.queryId = queryId
        self.update = update
    }
}

extension SubscribeMultiApplied: BSATNCodable {
    public func encode(to encoder: inout BSATNEncoder) throws {
        encoder.encode(requestId)
        encoder.encode(totalHostExecutionDurationMicros)
        try queryId.encode(to: &encoder)
        try update.encode(to: &encoder)
    }
    
    public init(from decoder: inout BSATNDecoder) throws {
        self.requestId = try decoder.decode(UInt32.self)
        self.totalHostExecutionDurationMicros = try decoder.decode(UInt64.self)
        self.queryId = try QueryId(from: &decoder)
        self.update = try DatabaseUpdate(from: &decoder)
    }
}

/// Response to `UnsubscribeMulti` containing the final matching rows.
public struct UnsubscribeMultiApplied: Sendable {
    /// The request ID from the original message.
    public let requestId: UInt32
    
    /// Time to process the unsubscription in microseconds.
    public let totalHostExecutionDurationMicros: UInt64
    
    /// The query ID from the original message.
    public let queryId: QueryId
    
    /// The matching rows at the time of unsubscription.
    public let update: DatabaseUpdate
    
    public init(requestId: UInt32, totalHostExecutionDurationMicros: UInt64, queryId: QueryId, update: DatabaseUpdate) {
        self.requestId = requestId
        self.totalHostExecutionDurationMicros = totalHostExecutionDurationMicros
        self.queryId = queryId
        self.update = update
    }
}

extension UnsubscribeMultiApplied: BSATNCodable {
    public func encode(to encoder: inout BSATNEncoder) throws {
        encoder.encode(requestId)
        encoder.encode(totalHostExecutionDurationMicros)
        try queryId.encode(to: &encoder)
        try update.encode(to: &encoder)
    }
    
    public init(from decoder: inout BSATNDecoder) throws {
        self.requestId = try decoder.decode(UInt32.self)
        self.totalHostExecutionDurationMicros = try decoder.decode(UInt64.self)
        self.queryId = try QueryId(from: &decoder)
        self.update = try DatabaseUpdate(from: &decoder)
    }
}

/// Error in the subscription lifecycle.
///
/// If `requestId` is nil, the client should drop all subscriptions.
public struct SubscriptionError: Sendable {
    /// Time to process the request in microseconds.
    public let totalHostExecutionDurationMicros: UInt64
    
    /// The request ID, if applicable.
    public let requestId: UInt32?
    
    /// The query ID, if applicable.
    public let queryId: UInt32?
    
    /// The table ID if only queries of this table type should be dropped.
    public let tableId: TableId?
    
    /// Error message describing the failure.
    public let error: String
    
    public init(
        totalHostExecutionDurationMicros: UInt64,
        requestId: UInt32?,
        queryId: UInt32?,
        tableId: TableId?,
        error: String
    ) {
        self.totalHostExecutionDurationMicros = totalHostExecutionDurationMicros
        self.requestId = requestId
        self.queryId = queryId
        self.tableId = tableId
        self.error = error
    }
}

extension SubscriptionError: BSATNCodable {
    public func encode(to encoder: inout BSATNEncoder) throws {
        encoder.encode(totalHostExecutionDurationMicros)
        try requestId.encode(to: &encoder)
        try queryId.encode(to: &encoder)
        try tableId.encode(to: &encoder)
        try error.encode(to: &encoder)
    }
    
    public init(from decoder: inout BSATNDecoder) throws {
        self.totalHostExecutionDurationMicros = try decoder.decode(UInt64.self)
        self.requestId = try UInt32?(from: &decoder)
        self.queryId = try UInt32?(from: &decoder)
        self.tableId = try TableId?(from: &decoder)
        self.error = try String(from: &decoder)
    }
}

/// Response to `OneOffQuery`.
public struct OneOffQueryResponse: Sendable {
    /// The message ID from the original query.
    public let messageId: Data
    
    /// Error message if query failed, nil on success.
    public let error: String?
    
    /// Result tables if query succeeded.
    public let tables: [OneOffTable]
    
    /// Time to process the query.
    public let totalHostExecutionDuration: TimeDuration
    
    public init(messageId: Data, error: String?, tables: [OneOffTable], totalHostExecutionDuration: TimeDuration) {
        self.messageId = messageId
        self.error = error
        self.tables = tables
        self.totalHostExecutionDuration = totalHostExecutionDuration
    }
}

extension OneOffQueryResponse: BSATNCodable {
    public func encode(to encoder: inout BSATNEncoder) throws {
        try messageId.encode(to: &encoder)
        try error.encode(to: &encoder)
        try tables.encode(to: &encoder)
        try totalHostExecutionDuration.encode(to: &encoder)
    }
    
    public init(from decoder: inout BSATNDecoder) throws {
        self.messageId = try Data(from: &decoder)
        self.error = try String?(from: &decoder)
        self.tables = try [OneOffTable](from: &decoder)
        self.totalHostExecutionDuration = try TimeDuration(from: &decoder)
    }
}

/// A table included in a OneOffQueryResponse.
public struct OneOffTable: Sendable {
    /// The name of the table.
    public let tableName: String
    
    /// The matching rows.
    public let rows: BsatnRowList
    
    public init(tableName: String, rows: BsatnRowList) {
        self.tableName = tableName
        self.rows = rows
    }
}

extension OneOffTable: BSATNCodable {
    public func encode(to encoder: inout BSATNEncoder) throws {
        try tableName.encode(to: &encoder)
        try rows.encode(to: &encoder)
    }
    
    public init(from decoder: inout BSATNDecoder) throws {
        self.tableName = try String(from: &decoder)
        self.rows = try BsatnRowList(from: &decoder)
    }
}
