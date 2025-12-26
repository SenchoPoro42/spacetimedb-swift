//
//  TransactionTypes.swift
//  SpacetimeDB
//
//  Reducer call and transaction update types.
//

import Foundation

// MARK: - Client → Server Types

/// Request to call a reducer.
public struct CallReducer: Sendable {
    /// The name of the reducer to call.
    public let reducer: String
    
    /// The BSATN-encoded arguments to the reducer.
    public let args: Data
    
    /// Client-provided request identifier.
    /// The server will include this ID in the response `TransactionUpdate`.
    public let requestId: UInt32
    
    /// Flags controlling notification behavior.
    public let flags: CallReducerFlags
    
    public init(reducer: String, args: Data, requestId: UInt32, flags: CallReducerFlags = .fullUpdate) {
        self.reducer = reducer
        self.args = args
        self.requestId = requestId
        self.flags = flags
    }
}

extension CallReducer: BSATNCodable {
    public func encode(to encoder: inout BSATNEncoder) throws {
        try reducer.encode(to: &encoder)
        try args.encode(to: &encoder)
        encoder.encode(requestId)
        try flags.encode(to: &encoder)
    }
    
    public init(from decoder: inout BSATNDecoder) throws {
        self.reducer = try String(from: &decoder)
        self.args = try Data(from: &decoder)
        self.requestId = try decoder.decode(UInt32.self)
        self.flags = try CallReducerFlags(from: &decoder)
    }
}

/// Request to call a procedure.
public struct CallProcedure: Sendable {
    /// The name of the procedure to call.
    public let procedure: String
    
    /// The BSATN-encoded arguments to the procedure.
    public let args: Data
    
    /// Client-provided request identifier.
    public let requestId: UInt32
    
    /// Reserved flags.
    public let flags: CallProcedureFlags
    
    public init(procedure: String, args: Data, requestId: UInt32, flags: CallProcedureFlags = .default) {
        self.procedure = procedure
        self.args = args
        self.requestId = requestId
        self.flags = flags
    }
}

extension CallProcedure: BSATNCodable {
    public func encode(to encoder: inout BSATNEncoder) throws {
        try procedure.encode(to: &encoder)
        try args.encode(to: &encoder)
        encoder.encode(requestId)
        try flags.encode(to: &encoder)
    }
    
    public init(from decoder: inout BSATNDecoder) throws {
        self.procedure = try String(from: &decoder)
        self.args = try Data(from: &decoder)
        self.requestId = try decoder.decode(UInt32.self)
        self.flags = try CallProcedureFlags(from: &decoder)
    }
}

// MARK: - Server → Client Types

/// Sent after connecting to inform the client of its identity.
///
/// This is always the first message sent on a new WebSocket connection.
public struct IdentityToken: Sendable {
    /// The user's identity.
    public let identity: Identity
    
    /// Authentication token for reconnection.
    public let token: String
    
    /// The connection ID for this session.
    public let connectionId: ConnectionId
    
    public init(identity: Identity, token: String, connectionId: ConnectionId) {
        self.identity = identity
        self.token = token
        self.connectionId = connectionId
    }
}

extension IdentityToken: BSATNCodable {
    public func encode(to encoder: inout BSATNEncoder) throws {
        try identity.encode(to: &encoder)
        try token.encode(to: &encoder)
        try connectionId.encode(to: &encoder)
    }
    
    public init(from decoder: inout BSATNDecoder) throws {
        self.identity = try Identity(from: &decoder)
        self.token = try String(from: &decoder)
        self.connectionId = try ConnectionId(from: &decoder)
    }
}

// MARK: - UpdateStatus

/// The status of a reducer transaction.
public enum UpdateStatus: Sendable {
    /// The reducer ran successfully and its changes were committed.
    case committed(DatabaseUpdate)
    
    /// The reducer errored and changes were rolled back.
    case failed(String)
    
    /// The reducer was interrupted due to insufficient energy.
    case outOfEnergy
}

extension UpdateStatus: BSATNCodable {
    public func encode(to encoder: inout BSATNEncoder) throws {
        switch self {
        case .committed(let update):
            encoder.encode(UInt8(0))
            try update.encode(to: &encoder)
        case .failed(let message):
            encoder.encode(UInt8(1))
            try message.encode(to: &encoder)
        case .outOfEnergy:
            encoder.encode(UInt8(2))
        }
    }
    
    public init(from decoder: inout BSATNDecoder) throws {
        let tag = try decoder.decode(UInt8.self)
        switch tag {
        case 0:
            let update = try DatabaseUpdate(from: &decoder)
            self = .committed(update)
        case 1:
            let message = try String(from: &decoder)
            self = .failed(message)
        case 2:
            self = .outOfEnergy
        default:
            throw BSATNDecodingError.invalidEnumTag(tag: tag, typeName: "UpdateStatus")
        }
    }
}

// MARK: - ReducerCallInfo

/// Metadata about a reducer invocation.
public struct ReducerCallInfo: Sendable {
    /// The name of the reducer that was called.
    public let reducerName: String
    
    /// The numerical ID of the reducer.
    public let reducerId: UInt32
    
    /// The BSATN-encoded arguments.
    public let args: Data
    
    /// The client-provided request ID.
    public let requestId: UInt32
    
    public init(reducerName: String, reducerId: UInt32, args: Data, requestId: UInt32) {
        self.reducerName = reducerName
        self.reducerId = reducerId
        self.args = args
        self.requestId = requestId
    }
}

extension ReducerCallInfo: BSATNCodable {
    public func encode(to encoder: inout BSATNEncoder) throws {
        try reducerName.encode(to: &encoder)
        encoder.encode(reducerId)
        try args.encode(to: &encoder)
        encoder.encode(requestId)
    }
    
    public init(from decoder: inout BSATNDecoder) throws {
        self.reducerName = try String(from: &decoder)
        self.reducerId = try decoder.decode(UInt32.self)
        self.args = try Data(from: &decoder)
        self.requestId = try decoder.decode(UInt32.self)
    }
}

// MARK: - TransactionUpdate

/// Received upon a reducer run.
///
/// Clients receive these only for reducers which update subscribed rows,
/// or for their own `Failed` or `OutOfEnergy` reducer invocations.
public struct TransactionUpdate: Sendable {
    /// The status of the transaction (committed, failed, or out of energy).
    public let status: UpdateStatus
    
    /// The time when the reducer started.
    public let timestamp: Timestamp
    
    /// The identity of the user who requested the reducer run.
    public let callerIdentity: Identity
    
    /// The connection ID of the caller.
    /// All-zeros is a sentinel meaning no meaningful value (e.g., scheduled reducers).
    public let callerConnectionId: ConnectionId
    
    /// Information about the reducer call.
    public let reducerCall: ReducerCallInfo
    
    /// Energy credits consumed by the reducer.
    public let energyQuantaUsed: EnergyQuanta
    
    /// How long the reducer took to run.
    public let totalHostExecutionDuration: TimeDuration
    
    public init(
        status: UpdateStatus,
        timestamp: Timestamp,
        callerIdentity: Identity,
        callerConnectionId: ConnectionId,
        reducerCall: ReducerCallInfo,
        energyQuantaUsed: EnergyQuanta,
        totalHostExecutionDuration: TimeDuration
    ) {
        self.status = status
        self.timestamp = timestamp
        self.callerIdentity = callerIdentity
        self.callerConnectionId = callerConnectionId
        self.reducerCall = reducerCall
        self.energyQuantaUsed = energyQuantaUsed
        self.totalHostExecutionDuration = totalHostExecutionDuration
    }
}

extension TransactionUpdate: BSATNCodable {
    public func encode(to encoder: inout BSATNEncoder) throws {
        try status.encode(to: &encoder)
        try timestamp.encode(to: &encoder)
        try callerIdentity.encode(to: &encoder)
        try callerConnectionId.encode(to: &encoder)
        try reducerCall.encode(to: &encoder)
        try energyQuantaUsed.encode(to: &encoder)
        try totalHostExecutionDuration.encode(to: &encoder)
    }
    
    public init(from decoder: inout BSATNDecoder) throws {
        self.status = try UpdateStatus(from: &decoder)
        self.timestamp = try Timestamp(from: &decoder)
        self.callerIdentity = try Identity(from: &decoder)
        self.callerConnectionId = try ConnectionId(from: &decoder)
        self.reducerCall = try ReducerCallInfo(from: &decoder)
        self.energyQuantaUsed = try EnergyQuanta(from: &decoder)
        self.totalHostExecutionDuration = try TimeDuration(from: &decoder)
    }
}

// MARK: - TransactionUpdateLight

/// Lightweight transaction update with only the database changes.
///
/// Used when full transaction metadata is not needed.
public struct TransactionUpdateLight: Sendable {
    /// Client-provided request identifier.
    public let requestId: UInt32
    
    /// The database update containing row changes.
    public let update: DatabaseUpdate
    
    public init(requestId: UInt32, update: DatabaseUpdate) {
        self.requestId = requestId
        self.update = update
    }
}

extension TransactionUpdateLight: BSATNCodable {
    public func encode(to encoder: inout BSATNEncoder) throws {
        encoder.encode(requestId)
        try update.encode(to: &encoder)
    }
    
    public init(from decoder: inout BSATNDecoder) throws {
        self.requestId = try decoder.decode(UInt32.self)
        self.update = try DatabaseUpdate(from: &decoder)
    }
}

// MARK: - ProcedureStatus

/// The status of a procedure call.
public enum ProcedureStatus: Sendable {
    /// The procedure ran and returned the enclosed value.
    case returned(Data)
    
    /// The procedure was interrupted due to insufficient energy.
    case outOfEnergy
    
    /// The call failed in the host (e.g., type error or unknown procedure).
    case internalError(String)
}

extension ProcedureStatus: BSATNCodable {
    public func encode(to encoder: inout BSATNEncoder) throws {
        switch self {
        case .returned(let data):
            encoder.encode(UInt8(0))
            try data.encode(to: &encoder)
        case .outOfEnergy:
            encoder.encode(UInt8(1))
        case .internalError(let message):
            encoder.encode(UInt8(2))
            try message.encode(to: &encoder)
        }
    }
    
    public init(from decoder: inout BSATNDecoder) throws {
        let tag = try decoder.decode(UInt8.self)
        switch tag {
        case 0:
            let data = try Data(from: &decoder)
            self = .returned(data)
        case 1:
            self = .outOfEnergy
        case 2:
            let message = try String(from: &decoder)
            self = .internalError(message)
        default:
            throw BSATNDecodingError.invalidEnumTag(tag: tag, typeName: "ProcedureStatus")
        }
    }
}

// MARK: - ProcedureResult

/// Result of a procedure call.
public struct ProcedureResult: Sendable {
    /// The status including return value on success.
    public let status: ProcedureStatus
    
    /// The time when the procedure started.
    public let timestamp: Timestamp
    
    /// How long the procedure took to run.
    public let totalHostExecutionDuration: TimeDuration
    
    /// The client-provided request ID.
    public let requestId: UInt32
    
    public init(
        status: ProcedureStatus,
        timestamp: Timestamp,
        totalHostExecutionDuration: TimeDuration,
        requestId: UInt32
    ) {
        self.status = status
        self.timestamp = timestamp
        self.totalHostExecutionDuration = totalHostExecutionDuration
        self.requestId = requestId
    }
}

extension ProcedureResult: BSATNCodable {
    public func encode(to encoder: inout BSATNEncoder) throws {
        try status.encode(to: &encoder)
        try timestamp.encode(to: &encoder)
        try totalHostExecutionDuration.encode(to: &encoder)
        encoder.encode(requestId)
    }
    
    public init(from decoder: inout BSATNDecoder) throws {
        self.status = try ProcedureStatus(from: &decoder)
        self.timestamp = try Timestamp(from: &decoder)
        self.totalHostExecutionDuration = try TimeDuration(from: &decoder)
        self.requestId = try decoder.decode(UInt32.self)
    }
}
