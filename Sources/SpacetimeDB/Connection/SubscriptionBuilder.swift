//
//  SubscriptionBuilder.swift
//  SpacetimeDB
//
//  Fluent API for managing database subscriptions.
//

import Foundation

// MARK: - SubscriptionHandle

/// A handle representing an active subscription.
///
/// Use this handle to unsubscribe from queries.
public struct SubscriptionHandle: Sendable, Hashable {
    /// The query ID for single subscriptions.
    public let queryId: QueryId?
    
    /// The queries that were subscribed.
    public let queries: [String]
    
    /// The request ID used for this subscription.
    public let requestId: UInt32
    
    /// Whether this was a batch subscription (Subscribe) or single (SubscribeSingle/Multi).
    public let isBatchSubscription: Bool
    
    internal init(queryId: QueryId?, queries: [String], requestId: UInt32, isBatchSubscription: Bool) {
        self.queryId = queryId
        self.queries = queries
        self.requestId = requestId
        self.isBatchSubscription = isBatchSubscription
    }
}

// MARK: - SubscriptionHandle CustomStringConvertible

extension SubscriptionHandle: CustomStringConvertible {
    public var description: String {
        if let queryId = queryId {
            return "SubscriptionHandle(queryId: \(queryId), queries: \(queries.count))"
        }
        return "SubscriptionHandle(batch, queries: \(queries.count))"
    }
}

// MARK: - SubscriptionBuilder

/// Builder for creating database subscriptions.
///
/// ## Usage
///
/// ```swift
/// // Subscribe to multiple tables
/// let handle = try await connection.subscriptionBuilder()
///     .subscribe("SELECT * FROM users")
///     .subscribe("SELECT * FROM messages")
///     .build()
///
/// // Later, unsubscribe
/// try await connection.unsubscribe(handle)
/// ```
///
/// ## Subscription Modes
///
/// - **Batch subscription** (`Subscribe`): Replaces all existing subscriptions.
///   Use when you want to set the complete subscription set at once.
///
/// - **Single subscription** (`SubscribeSingle`/`SubscribeMulti`): Adds to existing
///   subscriptions. Use when you want to incrementally add subscriptions.
public final class SubscriptionBuilder: @unchecked Sendable {
    
    // MARK: - Properties
    
    private weak var connection: SpacetimeDBConnection?
    private var queries: [String] = []
    private var useBatchMode: Bool = false
    private var onAppliedCallback: ((@Sendable (SubscriptionResult) async -> Void))?
    
    // MARK: - Initialization
    
    /// Create a new subscription builder.
    ///
    /// - Parameter connection: The connection to subscribe through.
    internal init(connection: SpacetimeDBConnection) {
        self.connection = connection
    }
    
    // MARK: - Query Building
    
    /// Add a SQL query to the subscription.
    ///
    /// - Parameter query: A SQL SELECT query.
    /// - Returns: The builder for chaining.
    @discardableResult
    public func subscribe(_ query: String) -> SubscriptionBuilder {
        queries.append(query)
        return self
    }
    
    /// Add multiple SQL queries to the subscription.
    ///
    /// - Parameter queries: SQL SELECT queries.
    /// - Returns: The builder for chaining.
    @discardableResult
    public func subscribe(_ queries: String...) -> SubscriptionBuilder {
        self.queries.append(contentsOf: queries)
        return self
    }
    
    /// Add multiple SQL queries to the subscription.
    ///
    /// - Parameter queries: Array of SQL SELECT queries.
    /// - Returns: The builder for chaining.
    @discardableResult
    public func subscribe(_ queries: [String]) -> SubscriptionBuilder {
        self.queries.append(contentsOf: queries)
        return self
    }
    
    // MARK: - Mode Configuration
    
    /// Use batch subscription mode.
    ///
    /// In batch mode, all queries are sent as a single `Subscribe` message,
    /// which replaces all existing subscriptions. This is the default for
    /// initial subscriptions.
    ///
    /// - Returns: The builder for chaining.
    @discardableResult
    public func asBatchSubscription() -> SubscriptionBuilder {
        useBatchMode = true
        return self
    }
    
    /// Use incremental subscription mode.
    ///
    /// In incremental mode, queries are sent as `SubscribeSingle` or
    /// `SubscribeMulti` messages, adding to existing subscriptions.
    ///
    /// - Returns: The builder for chaining.
    @discardableResult
    public func asIncrementalSubscription() -> SubscriptionBuilder {
        useBatchMode = false
        return self
    }
    
    // MARK: - Callbacks
    
    /// Set a callback for when the subscription is applied.
    ///
    /// - Parameter callback: Called with the subscription result.
    /// - Returns: The builder for chaining.
    @discardableResult
    public func onApplied(_ callback: @escaping @Sendable (SubscriptionResult) async -> Void) -> SubscriptionBuilder {
        onAppliedCallback = callback
        return self
    }
    
    // MARK: - Build
    
    /// Execute the subscription.
    ///
    /// - Returns: A handle that can be used to unsubscribe.
    /// - Throws: `ConnectionError.notConnected` if not connected,
    ///           `ConnectionError.subscriptionFailed` on server error.
    public func build() async throws -> SubscriptionHandle {
        guard let connection = connection else {
            throw ConnectionError.notConnected
        }
        
        guard !queries.isEmpty else {
            throw ConnectionError.subscriptionFailed(message: "No queries specified")
        }
        
        let result: SubscriptionHandle
        
        if useBatchMode || queries.count > 1 {
            // Use batch Subscribe for multiple queries or explicit batch mode
            result = try await connection.sendBatchSubscription(queries: queries)
        } else {
            // Use SubscribeSingle for a single query in incremental mode
            result = try await connection.sendSingleSubscription(query: queries[0])
        }
        
        // Fire callback if provided
        if let callback = onAppliedCallback {
            let subscriptionResult = SubscriptionResult(
                requestId: result.requestId,
                queryId: result.queryId,
                initialRowCount: 0, // Will be populated by the connection
                executionDurationMicros: 0
            )
            await callback(subscriptionResult)
        }
        
        return result
    }
}

// MARK: - ActiveSubscriptionRegistry

/// Tracks active subscriptions for reconnection replay.
internal final class ActiveSubscriptionRegistry: @unchecked Sendable {
    
    /// Active subscriptions by query ID.
    private var subscriptions: [UInt32: SubscriptionHandle] = [:]
    
    /// All active query strings (for batch re-subscribe).
    private var allQueries: Set<String> = []
    
    /// Lock for thread-safe access.
    private let lock = NSLock()
    
    init() {}
    
    /// Register an active subscription.
    func register(_ handle: SubscriptionHandle) {
        lock.lock()
        defer { lock.unlock() }
        
        subscriptions[handle.requestId] = handle
        allQueries.formUnion(handle.queries)
    }
    
    /// Remove a subscription.
    func remove(_ handle: SubscriptionHandle) {
        lock.lock()
        defer { lock.unlock() }
        
        subscriptions.removeValue(forKey: handle.requestId)
        
        // Rebuild the query set from remaining subscriptions
        allQueries.removeAll()
        for sub in subscriptions.values {
            allQueries.formUnion(sub.queries)
        }
    }
    
    /// Get all active queries for re-subscription.
    func getAllQueries() -> [String] {
        lock.lock()
        defer { lock.unlock() }
        return Array(allQueries)
    }
    
    /// Clear all subscriptions.
    func clear() {
        lock.lock()
        defer { lock.unlock() }
        
        subscriptions.removeAll()
        allQueries.removeAll()
    }
    
    /// The number of active subscriptions.
    var count: Int {
        lock.lock()
        defer { lock.unlock() }
        return subscriptions.count
    }
}
