//
//  ServerMessage.swift
//  SpacetimeDB
//
//  Top-level server → client message type.
//

import Foundation

/// Messages sent from the server to the client.
///
/// BSATN encoding: u8 tag (0-10) + variant data
///
/// Note: Compression is handled at the transport layer, not in message encoding.
/// The transport layer may prefix messages with a compression tag (0=none, 1=brotli, 2=gzip).
public enum ServerMessage: Sendable {
    /// Initial subscription data (response to `Subscribe`).
    /// This will be removed when switching to `SubscribeSingle`.
    case initialSubscription(InitialSubscription)
    
    /// Transaction update upon reducer run.
    case transactionUpdate(TransactionUpdate)
    
    /// Lightweight transaction update (only database changes).
    case transactionUpdateLight(TransactionUpdateLight)
    
    /// Identity token sent after connecting.
    case identityToken(IdentityToken)
    
    /// Response to a one-off query.
    case oneOffQueryResponse(OneOffQueryResponse)
    
    /// Response to `SubscribeSingle` with initial matching rows.
    case subscribeApplied(SubscribeApplied)
    
    /// Response to `Unsubscribe` with final matching rows.
    case unsubscribeApplied(UnsubscribeApplied)
    
    /// Error in the subscription lifecycle.
    case subscriptionError(SubscriptionError)
    
    /// Response to `SubscribeMulti` with initial matching rows.
    case subscribeMultiApplied(SubscribeMultiApplied)
    
    /// Response to `UnsubscribeMulti` with final matching rows.
    case unsubscribeMultiApplied(UnsubscribeMultiApplied)
    
    /// Result of a procedure call.
    case procedureResult(ProcedureResult)
}

extension ServerMessage: BSATNCodable {
    public func encode(to encoder: inout BSATNEncoder) throws {
        switch self {
        case .initialSubscription(let value):
            encoder.encode(UInt8(0))
            try value.encode(to: &encoder)
            
        case .transactionUpdate(let value):
            encoder.encode(UInt8(1))
            try value.encode(to: &encoder)
            
        case .transactionUpdateLight(let value):
            encoder.encode(UInt8(2))
            try value.encode(to: &encoder)
            
        case .identityToken(let value):
            encoder.encode(UInt8(3))
            try value.encode(to: &encoder)
            
        case .oneOffQueryResponse(let value):
            encoder.encode(UInt8(4))
            try value.encode(to: &encoder)
            
        case .subscribeApplied(let value):
            encoder.encode(UInt8(5))
            try value.encode(to: &encoder)
            
        case .unsubscribeApplied(let value):
            encoder.encode(UInt8(6))
            try value.encode(to: &encoder)
            
        case .subscriptionError(let value):
            encoder.encode(UInt8(7))
            try value.encode(to: &encoder)
            
        case .subscribeMultiApplied(let value):
            encoder.encode(UInt8(8))
            try value.encode(to: &encoder)
            
        case .unsubscribeMultiApplied(let value):
            encoder.encode(UInt8(9))
            try value.encode(to: &encoder)
            
        case .procedureResult(let value):
            encoder.encode(UInt8(10))
            try value.encode(to: &encoder)
        }
    }
    
    public init(from decoder: inout BSATNDecoder) throws {
        let tag = try decoder.decode(UInt8.self)
        
        switch tag {
        case 0:
            self = .initialSubscription(try InitialSubscription(from: &decoder))
        case 1:
            self = .transactionUpdate(try TransactionUpdate(from: &decoder))
        case 2:
            self = .transactionUpdateLight(try TransactionUpdateLight(from: &decoder))
        case 3:
            self = .identityToken(try IdentityToken(from: &decoder))
        case 4:
            self = .oneOffQueryResponse(try OneOffQueryResponse(from: &decoder))
        case 5:
            self = .subscribeApplied(try SubscribeApplied(from: &decoder))
        case 6:
            self = .unsubscribeApplied(try UnsubscribeApplied(from: &decoder))
        case 7:
            self = .subscriptionError(try SubscriptionError(from: &decoder))
        case 8:
            self = .subscribeMultiApplied(try SubscribeMultiApplied(from: &decoder))
        case 9:
            self = .unsubscribeMultiApplied(try UnsubscribeMultiApplied(from: &decoder))
        case 10:
            self = .procedureResult(try ProcedureResult(from: &decoder))
        default:
            throw BSATNDecodingError.invalidEnumTag(tag: tag, typeName: "ServerMessage")
        }
    }
}

// MARK: - Convenience Accessors

extension ServerMessage {
    /// Returns true if this message indicates an error.
    public var isError: Bool {
        switch self {
        case .subscriptionError:
            return true
        case .transactionUpdate(let update):
            if case .failed = update.status { return true }
            if case .outOfEnergy = update.status { return true }
            return false
        case .procedureResult(let result):
            if case .outOfEnergy = result.status { return true }
            if case .internalError = result.status { return true }
            return false
        default:
            return false
        }
    }
    
    /// Returns true if this message contains database updates.
    public var hasDatabaseUpdate: Bool {
        switch self {
        case .initialSubscription, .transactionUpdate, .transactionUpdateLight,
             .subscribeApplied, .unsubscribeApplied, .subscribeMultiApplied, .unsubscribeMultiApplied:
            return true
        default:
            return false
        }
    }
    
    /// Returns the request ID if this message is a response to a client request.
    public var requestId: UInt32? {
        switch self {
        case .initialSubscription(let v):
            return v.requestId
        case .transactionUpdate(let v):
            return v.reducerCall.requestId
        case .transactionUpdateLight(let v):
            return v.requestId
        case .subscribeApplied(let v):
            return v.requestId
        case .unsubscribeApplied(let v):
            return v.requestId
        case .subscribeMultiApplied(let v):
            return v.requestId
        case .unsubscribeMultiApplied(let v):
            return v.requestId
        case .procedureResult(let v):
            return v.requestId
        case .subscriptionError(let v):
            return v.requestId
        case .identityToken, .oneOffQueryResponse:
            return nil
        }
    }
}

// MARK: - CustomStringConvertible

extension ServerMessage: CustomStringConvertible {
    public var description: String {
        switch self {
        case .initialSubscription(let v):
            return "ServerMessage.initialSubscription(\(v.databaseUpdate.totalRowCount) rows)"
        case .transactionUpdate(let v):
            return "ServerMessage.transactionUpdate(\(v.reducerCall.reducerName))"
        case .transactionUpdateLight(let v):
            return "ServerMessage.transactionUpdateLight(requestId: \(v.requestId))"
        case .identityToken(let v):
            return "ServerMessage.identityToken(\(v.identity.shortHexString)...)"
        case .oneOffQueryResponse(let v):
            if let error = v.error {
                return "ServerMessage.oneOffQueryResponse(error: \(error.prefix(30)))"
            }
            return "ServerMessage.oneOffQueryResponse(\(v.tables.count) tables)"
        case .subscribeApplied(let v):
            return "ServerMessage.subscribeApplied(queryId: \(v.queryId))"
        case .unsubscribeApplied(let v):
            return "ServerMessage.unsubscribeApplied(queryId: \(v.queryId))"
        case .subscriptionError(let v):
            return "ServerMessage.subscriptionError(\(v.error.prefix(30))...)"
        case .subscribeMultiApplied(let v):
            return "ServerMessage.subscribeMultiApplied(queryId: \(v.queryId))"
        case .unsubscribeMultiApplied(let v):
            return "ServerMessage.unsubscribeMultiApplied(queryId: \(v.queryId))"
        case .procedureResult(let v):
            return "ServerMessage.procedureResult(requestId: \(v.requestId))"
        }
    }
}
