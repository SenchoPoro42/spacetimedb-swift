//
//  ClientMessage.swift
//  SpacetimeDB
//
//  Top-level client → server message type.
//

import Foundation

/// Messages sent from the client to the server.
///
/// BSATN encoding: u8 tag (0-7) + variant data
public enum ClientMessage: Sendable {
    /// Request a reducer run.
    case callReducer(CallReducer)
    
    /// Register SQL queries on which to receive updates.
    /// Replaces all existing subscriptions.
    case subscribe(Subscribe)
    
    /// Send a one-off SQL query without establishing a subscription.
    case oneOffQuery(OneOffQuery)
    
    /// Subscribe to a single query (adds to existing subscriptions).
    case subscribeSingle(SubscribeSingle)
    
    /// Subscribe to multiple queries as a group.
    case subscribeMulti(SubscribeMulti)
    
    /// Remove a subscription added with `subscribeSingle`.
    case unsubscribe(Unsubscribe)
    
    /// Remove a subscription added with `subscribeMulti`.
    case unsubscribeMulti(UnsubscribeMulti)
    
    /// Request a procedure run.
    case callProcedure(CallProcedure)
}

extension ClientMessage: BSATNCodable {
    public func encode(to encoder: inout BSATNEncoder) throws {
        switch self {
        case .callReducer(let value):
            encoder.encode(UInt8(0))
            try value.encode(to: &encoder)
            
        case .subscribe(let value):
            encoder.encode(UInt8(1))
            try value.encode(to: &encoder)
            
        case .oneOffQuery(let value):
            encoder.encode(UInt8(2))
            try value.encode(to: &encoder)
            
        case .subscribeSingle(let value):
            encoder.encode(UInt8(3))
            try value.encode(to: &encoder)
            
        case .subscribeMulti(let value):
            encoder.encode(UInt8(4))
            try value.encode(to: &encoder)
            
        case .unsubscribe(let value):
            encoder.encode(UInt8(5))
            try value.encode(to: &encoder)
            
        case .unsubscribeMulti(let value):
            encoder.encode(UInt8(6))
            try value.encode(to: &encoder)
            
        case .callProcedure(let value):
            encoder.encode(UInt8(7))
            try value.encode(to: &encoder)
        }
    }
    
    public init(from decoder: inout BSATNDecoder) throws {
        let tag = try decoder.decode(UInt8.self)
        
        switch tag {
        case 0:
            self = .callReducer(try CallReducer(from: &decoder))
        case 1:
            self = .subscribe(try Subscribe(from: &decoder))
        case 2:
            self = .oneOffQuery(try OneOffQuery(from: &decoder))
        case 3:
            self = .subscribeSingle(try SubscribeSingle(from: &decoder))
        case 4:
            self = .subscribeMulti(try SubscribeMulti(from: &decoder))
        case 5:
            self = .unsubscribe(try Unsubscribe(from: &decoder))
        case 6:
            self = .unsubscribeMulti(try UnsubscribeMulti(from: &decoder))
        case 7:
            self = .callProcedure(try CallProcedure(from: &decoder))
        default:
            throw BSATNDecodingError.invalidEnumTag(tag: tag, typeName: "ClientMessage")
        }
    }
}

// MARK: - Convenience Accessors

extension ClientMessage {
    /// Returns true if this is a subscription-related message.
    public var isSubscriptionMessage: Bool {
        switch self {
        case .subscribe, .subscribeSingle, .subscribeMulti, .unsubscribe, .unsubscribeMulti:
            return true
        case .callReducer, .oneOffQuery, .callProcedure:
            return false
        }
    }
    
    /// Returns the request ID if this message has one.
    public var requestId: UInt32? {
        switch self {
        case .callReducer(let v):
            return v.requestId
        case .subscribe(let v):
            return v.requestId
        case .subscribeSingle(let v):
            return v.requestId
        case .subscribeMulti(let v):
            return v.requestId
        case .unsubscribe(let v):
            return v.requestId
        case .unsubscribeMulti(let v):
            return v.requestId
        case .callProcedure(let v):
            return v.requestId
        case .oneOffQuery:
            return nil
        }
    }
}

// MARK: - CustomStringConvertible

extension ClientMessage: CustomStringConvertible {
    public var description: String {
        switch self {
        case .callReducer(let v):
            return "ClientMessage.callReducer(\(v.reducer))"
        case .subscribe(let v):
            return "ClientMessage.subscribe(\(v.queryStrings.count) queries)"
        case .oneOffQuery(let v):
            return "ClientMessage.oneOffQuery(\(v.queryString.prefix(30))...)"
        case .subscribeSingle(let v):
            return "ClientMessage.subscribeSingle(queryId: \(v.queryId))"
        case .subscribeMulti(let v):
            return "ClientMessage.subscribeMulti(queryId: \(v.queryId))"
        case .unsubscribe(let v):
            return "ClientMessage.unsubscribe(queryId: \(v.queryId))"
        case .unsubscribeMulti(let v):
            return "ClientMessage.unsubscribeMulti(queryId: \(v.queryId))"
        case .callProcedure(let v):
            return "ClientMessage.callProcedure(\(v.procedure))"
        }
    }
}
