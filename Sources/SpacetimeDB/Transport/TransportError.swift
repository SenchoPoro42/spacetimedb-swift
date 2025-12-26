//
//  TransportError.swift
//  SpacetimeDB
//
//  Error types for the WebSocket transport layer.
//

import Foundation

/// Errors that can occur in the WebSocket transport layer.
public enum TransportError: Error, Sendable {
    /// Connection to the server failed.
    case connectionFailed(underlying: Error)
    
    /// The connection was closed by the server or network.
    case connectionClosed(closeCode: Int, reason: String?)
    
    /// Sending a message failed.
    case sendFailed(underlying: Error)
    
    /// Failed to encode a client message.
    case encodingFailed(underlying: Error)
    
    /// Failed to decode a server message.
    case decodingFailed(underlying: Error)
    
    /// Failed to decompress a server message.
    case decompressionFailed(compressionType: CompressionType)
    
    /// Received an invalid or unexpected message.
    case invalidMessage(description: String)
    
    /// The operation timed out.
    case timeout
    
    /// The transport is not connected.
    case notConnected
    
    /// The transport is already connected.
    case alreadyConnected
    
    /// An unknown compression tag was received.
    case unknownCompressionTag(UInt8)
}

extension TransportError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .connectionFailed(let error):
            return "Connection failed: \(error.localizedDescription)"
        case .connectionClosed(let code, let reason):
            if let reason = reason {
                return "Connection closed (code \(code)): \(reason)"
            }
            return "Connection closed with code \(code)"
        case .sendFailed(let error):
            return "Failed to send message: \(error.localizedDescription)"
        case .encodingFailed(let error):
            return "Failed to encode message: \(error.localizedDescription)"
        case .decodingFailed(let error):
            return "Failed to decode message: \(error.localizedDescription)"
        case .decompressionFailed(let type):
            return "Decompression failed for \(type)"
        case .invalidMessage(let description):
            return "Invalid message: \(description)"
        case .timeout:
            return "Operation timed out"
        case .notConnected:
            return "Transport is not connected"
        case .alreadyConnected:
            return "Transport is already connected"
        case .unknownCompressionTag(let tag):
            return "Unknown compression tag: \(tag)"
        }
    }
}

// MARK: - WebSocket Close Code Extension

extension URLSessionWebSocketTask.CloseCode {
    /// Human-readable description of the close code.
    public var description: String {
        switch self {
        case .normalClosure:
            return "Normal closure"
        case .goingAway:
            return "Going away"
        case .protocolError:
            return "Protocol error"
        case .unsupportedData:
            return "Unsupported data"
        case .noStatusReceived:
            return "No status received"
        case .abnormalClosure:
            return "Abnormal closure"
        case .invalidFramePayloadData:
            return "Invalid frame payload data"
        case .policyViolation:
            return "Policy violation"
        case .messageTooBig:
            return "Message too big"
        case .mandatoryExtensionMissing:
            return "Mandatory extension missing"
        case .internalServerError:
            return "Internal server error"
        case .tlsHandshakeFailure:
            return "TLS handshake failure"
        case .invalid:
            return "Invalid close code"
        @unknown default:
            return "Unknown close code (\(rawValue))"
        }
    }
}
