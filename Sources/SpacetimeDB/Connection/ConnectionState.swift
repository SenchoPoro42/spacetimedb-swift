//
//  ConnectionState.swift
//  SpacetimeDB
//
//  Connection state machine and result types.
//

import Foundation

// MARK: - ConnectionState

/// The current state of a SpacetimeDB connection.
public enum ConnectionState: Sendable, Equatable {
    /// Not connected to the server.
    case disconnected
    
    /// Attempting to establish a connection.
    case connecting
    
    /// Connected and ready for operations.
    case connected
    
    /// Connection lost, attempting to reconnect.
    case reconnecting(attempt: Int)
    
    /// Whether the connection is usable for operations.
    public var isConnected: Bool {
        if case .connected = self {
            return true
        }
        return false
    }
    
    /// Whether a connection attempt is in progress.
    public var isConnecting: Bool {
        switch self {
        case .connecting, .reconnecting:
            return true
        default:
            return false
        }
    }
}

// MARK: - CustomStringConvertible

extension ConnectionState: CustomStringConvertible {
    public var description: String {
        switch self {
        case .disconnected:
            return "disconnected"
        case .connecting:
            return "connecting"
        case .connected:
            return "connected"
        case .reconnecting(let attempt):
            return "reconnecting (attempt \(attempt))"
        }
    }
}

// MARK: - ReducerResult

/// The result of a reducer call.
public struct ReducerResult: Sendable {
    /// The name of the reducer that was called.
    public let reducerName: String
    
    /// The request ID used for this call.
    public let requestId: UInt32
    
    /// The status of the reducer execution.
    public let status: Status
    
    /// The timestamp when the reducer started.
    public let timestamp: Timestamp
    
    /// Energy consumed by the reducer.
    public let energyUsed: EnergyQuanta
    
    /// How long the reducer took to execute.
    public let executionDuration: TimeDuration
    
    /// The status of a reducer execution.
    public enum Status: Sendable {
        /// The reducer completed successfully.
        case success
        
        /// The reducer failed with an error message.
        case failed(String)
        
        /// The reducer ran out of energy.
        case outOfEnergy
    }
    
    /// Whether the reducer completed successfully.
    public var isSuccess: Bool {
        if case .success = status {
            return true
        }
        return false
    }
    
    /// The error message if the reducer failed.
    public var errorMessage: String? {
        if case .failed(let message) = status {
            return message
        }
        return nil
    }
}

// MARK: - ReducerResult CustomStringConvertible

extension ReducerResult: CustomStringConvertible {
    public var description: String {
        switch status {
        case .success:
            return "ReducerResult(\(reducerName): success)"
        case .failed(let message):
            return "ReducerResult(\(reducerName): failed - \(message))"
        case .outOfEnergy:
            return "ReducerResult(\(reducerName): out of energy)"
        }
    }
}

// MARK: - SubscriptionResult

/// The result of a subscription request.
public struct SubscriptionResult: Sendable {
    /// The request ID used for this subscription.
    public let requestId: UInt32
    
    /// The query ID assigned to this subscription (for later unsubscribe).
    public let queryId: QueryId?
    
    /// The number of initial rows received.
    public let initialRowCount: Int
    
    /// How long the server took to process the subscription.
    public let executionDurationMicros: UInt64
}

// MARK: - SubscriptionResult CustomStringConvertible

extension SubscriptionResult: CustomStringConvertible {
    public var description: String {
        "SubscriptionResult(requestId: \(requestId), rows: \(initialRowCount))"
    }
}
