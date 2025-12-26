//
//  TransportConfiguration.swift
//  SpacetimeDB
//
//  Configuration options for WebSocket transport.
//

import Foundation

/// Configuration for WebSocket transport behavior.
public struct TransportConfiguration: Sendable {
    /// Interval between ping messages to keep the connection alive.
    /// Set to `nil` to disable automatic ping.
    public var pingInterval: TimeInterval?
    
    /// Timeout for establishing a connection.
    public var connectionTimeout: TimeInterval
    
    /// Maximum number of automatic reconnection attempts.
    /// Set to 0 to disable automatic reconnection.
    public var maxReconnectAttempts: Int
    
    /// Base delay between reconnection attempts.
    /// The actual delay uses exponential backoff: `reconnectDelay * 2^attempt`.
    public var reconnectDelay: TimeInterval
    
    /// Maximum delay between reconnection attempts when using exponential backoff.
    public var maxReconnectDelay: TimeInterval
    
    /// Creates a new transport configuration with the specified options.
    ///
    /// - Parameters:
    ///   - pingInterval: Interval between ping messages (default: 30 seconds).
    ///   - connectionTimeout: Timeout for establishing a connection (default: 10 seconds).
    ///   - maxReconnectAttempts: Maximum reconnection attempts (default: 3).
    ///   - reconnectDelay: Base delay between reconnection attempts (default: 1 second).
    ///   - maxReconnectDelay: Maximum reconnection delay (default: 30 seconds).
    public init(
        pingInterval: TimeInterval? = 30.0,
        connectionTimeout: TimeInterval = 10.0,
        maxReconnectAttempts: Int = 3,
        reconnectDelay: TimeInterval = 1.0,
        maxReconnectDelay: TimeInterval = 30.0
    ) {
        self.pingInterval = pingInterval
        self.connectionTimeout = connectionTimeout
        self.maxReconnectAttempts = maxReconnectAttempts
        self.reconnectDelay = reconnectDelay
        self.maxReconnectDelay = maxReconnectDelay
    }
    
    /// Default configuration suitable for most use cases.
    public static let `default` = TransportConfiguration()
    
    /// Configuration with no automatic reconnection.
    public static let noReconnect = TransportConfiguration(
        maxReconnectAttempts: 0
    )
    
    /// Calculate the delay for a reconnection attempt using exponential backoff.
    ///
    /// - Parameter attempt: The attempt number (0-indexed).
    /// - Returns: The delay in seconds before the next attempt.
    public func delayForAttempt(_ attempt: Int) -> TimeInterval {
        let delay = reconnectDelay * pow(2.0, Double(attempt))
        return min(delay, maxReconnectDelay)
    }
}

// MARK: - CustomStringConvertible

extension TransportConfiguration: CustomStringConvertible {
    public var description: String {
        var parts: [String] = []
        
        if let ping = pingInterval {
            parts.append("ping: \(ping)s")
        } else {
            parts.append("ping: disabled")
        }
        
        parts.append("timeout: \(connectionTimeout)s")
        
        if maxReconnectAttempts > 0 {
            parts.append("reconnect: \(maxReconnectAttempts) attempts")
        } else {
            parts.append("reconnect: disabled")
        }
        
        return "TransportConfiguration(\(parts.joined(separator: ", ")))"
    }
}
