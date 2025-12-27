//
//  ConnectionError.swift
//  SpacetimeDB
//
//  Error types for the connection layer.
//

import Foundation

/// Errors that can occur in the SpacetimeDB connection layer.
public enum ConnectionError: Error, Sendable {
    /// The connection is not established.
    case notConnected
    
    /// Failed to establish the initial connection.
    case connectionFailed(underlying: Error)
    
    /// All reconnection attempts were exhausted.
    case reconnectFailed(attempts: Int)
    
    /// A reducer call failed with an error message.
    case reducerCallFailed(reducerName: String, message: String)
    
    /// A reducer call timed out waiting for a response.
    case reducerTimeout(reducerName: String, timeoutSeconds: TimeInterval)
    
    /// The reducer ran out of energy.
    case reducerOutOfEnergy(reducerName: String)
    
    /// A subscription request failed.
    case subscriptionFailed(message: String)
    
    /// The connection builder is missing required configuration.
    case builderMissingConfiguration(field: String)
    
    /// The connection was closed unexpectedly.
    case connectionClosed(reason: String?)
    
    /// An operation was cancelled.
    case cancelled
}

// MARK: - LocalizedError

extension ConnectionError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .notConnected:
            return "Not connected to SpacetimeDB server"
        case .connectionFailed(let error):
            return "Connection failed: \(error.localizedDescription)"
        case .reconnectFailed(let attempts):
            return "Reconnection failed after \(attempts) attempts"
        case .reducerCallFailed(let name, let message):
            return "Reducer '\(name)' failed: \(message)"
        case .reducerTimeout(let name, let timeout):
            return "Reducer '\(name)' timed out after \(timeout) seconds"
        case .reducerOutOfEnergy(let name):
            return "Reducer '\(name)' ran out of energy"
        case .subscriptionFailed(let message):
            return "Subscription failed: \(message)"
        case .builderMissingConfiguration(let field):
            return "Connection builder missing required field: \(field)"
        case .connectionClosed(let reason):
            if let reason = reason {
                return "Connection closed: \(reason)"
            }
            return "Connection closed"
        case .cancelled:
            return "Operation cancelled"
        }
    }
}

// MARK: - CustomStringConvertible

extension ConnectionError: CustomStringConvertible {
    public var description: String {
        errorDescription ?? "Unknown connection error"
    }
}
