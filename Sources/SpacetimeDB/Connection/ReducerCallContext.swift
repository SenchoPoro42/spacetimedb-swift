//
//  ReducerCallContext.swift
//  SpacetimeDB
//
//  Tracks pending reducer calls and subscription requests.
//

import Foundation

// MARK: - PendingCall

/// A pending call awaiting a response from the server.
internal struct PendingCall<T: Sendable>: Sendable {
    /// The request ID for this call.
    let requestId: UInt32
    
    /// The name of the reducer or subscription.
    let name: String
    
    /// When the call was initiated.
    let startTime: Date
    
    /// The continuation to resume when a response arrives.
    let continuation: CheckedContinuation<T, Error>
    
    /// Optional timeout task to cancel if response arrives.
    let timeoutTask: Task<Void, Never>?
}

// MARK: - PendingCallRegistry

/// Registry for tracking pending calls awaiting responses.
///
/// This is used internally by `SpacetimeDBConnection` to track
/// reducer calls and subscription requests that are awaiting
/// a response from the server.
internal final class PendingCallRegistry<T: Sendable>: @unchecked Sendable {
    
    /// Pending calls keyed by request ID.
    private var pendingCalls: [UInt32: PendingCall<T>] = [:]
    
    /// Lock for thread-safe access.
    private let lock = NSLock()
    
    init() {}
    
    /// Register a pending call.
    ///
    /// - Parameters:
    ///   - requestId: The request ID.
    ///   - name: The name of the reducer or query.
    ///   - continuation: The continuation to resume.
    ///   - timeoutTask: Optional timeout task.
    func register(
        requestId: UInt32,
        name: String,
        continuation: CheckedContinuation<T, Error>,
        timeoutTask: Task<Void, Never>? = nil
    ) {
        lock.lock()
        defer { lock.unlock() }
        
        pendingCalls[requestId] = PendingCall(
            requestId: requestId,
            name: name,
            startTime: Date(),
            continuation: continuation,
            timeoutTask: timeoutTask
        )
    }
    
    /// Remove and return a pending call.
    ///
    /// - Parameter requestId: The request ID.
    /// - Returns: The pending call if found.
    func remove(requestId: UInt32) -> PendingCall<T>? {
        lock.lock()
        defer { lock.unlock() }
        
        guard let call = pendingCalls.removeValue(forKey: requestId) else {
            return nil
        }
        
        // Cancel timeout if response arrived
        call.timeoutTask?.cancel()
        return call
    }
    
    /// Get a pending call without removing it.
    ///
    /// - Parameter requestId: The request ID.
    /// - Returns: The pending call if found.
    func get(requestId: UInt32) -> PendingCall<T>? {
        lock.lock()
        defer { lock.unlock() }
        return pendingCalls[requestId]
    }
    
    /// Cancel all pending calls with an error.
    ///
    /// - Parameter error: The error to resume with.
    func cancelAll(with error: Error) {
        lock.lock()
        let calls = pendingCalls
        pendingCalls.removeAll()
        lock.unlock()
        
        for call in calls.values {
            call.timeoutTask?.cancel()
            call.continuation.resume(throwing: error)
        }
    }
    
    /// The number of pending calls.
    var count: Int {
        lock.lock()
        defer { lock.unlock() }
        return pendingCalls.count
    }
    
    /// Whether there are any pending calls.
    var isEmpty: Bool {
        lock.lock()
        defer { lock.unlock() }
        return pendingCalls.isEmpty
    }
}

// MARK: - RequestIdGenerator

/// Generates unique request IDs for client messages.
internal final class RequestIdGenerator: @unchecked Sendable {
    private var counter: UInt32 = 0
    private let lock = NSLock()
    
    init(startingAt: UInt32 = 1) {
        self.counter = startingAt
    }
    
    /// Generate the next request ID.
    func next() -> UInt32 {
        lock.lock()
        defer { lock.unlock() }
        
        let id = counter
        counter &+= 1  // Wrapping addition
        return id
    }
    
    /// Get the current counter value (for testing).
    var current: UInt32 {
        lock.lock()
        defer { lock.unlock() }
        return counter
    }
}

// MARK: - QueryIdGenerator

/// Generates unique query IDs for subscriptions.
internal final class QueryIdGenerator: @unchecked Sendable {
    private var counter: UInt32 = 0
    private let lock = NSLock()
    
    init(startingAt: UInt32 = 1) {
        self.counter = startingAt
    }
    
    /// Generate the next query ID.
    func next() -> QueryId {
        lock.lock()
        defer { lock.unlock() }
        
        let id = counter
        counter &+= 1  // Wrapping addition
        return QueryId(id)
    }
    
    /// Get the current counter value (for testing).
    var current: UInt32 {
        lock.lock()
        defer { lock.unlock() }
        return counter
    }
}
