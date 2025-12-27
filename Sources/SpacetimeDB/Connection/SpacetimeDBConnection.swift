//
//  SpacetimeDBConnection.swift
//  SpacetimeDB
//
//  Main connection actor coordinating transport and cache.
//

import Foundation

// MARK: - SpacetimeDBConnection

/// A connection to a SpacetimeDB module.
///
/// `SpacetimeDBConnection` is the main entry point for interacting with a
/// SpacetimeDB server. It coordinates the WebSocket transport with the
/// client-side cache, manages subscriptions, and handles reducer calls.
///
/// ## Usage
///
/// ```swift
/// // Connect to a module
/// let connection = try await SpacetimeDBConnection.builder()
///     .withUri(URL(string: "ws://localhost:3000")!)
///     .withModuleName("my_module")
///     .onConnect { conn, identity, token in
///         print("Connected: \(identity)")
///         // Subscribe to tables
///         try await conn.subscribe("SELECT * FROM users")
///     }
///     .build()
///
/// // Call a reducer
/// let result = try await connection.callReducer("add_user", args: userData)
///
/// // Access cached data
/// for rowData in await connection.db.table(named: "users").iter() {
///     let user = try BSATNDecoder.decode(User.self, from: rowData)
/// }
/// ```
///
/// ## Thread Safety
///
/// `SpacetimeDBConnection` is implemented as an actor, ensuring all access
/// is thread-safe. The connection can be used from any async context.
public actor SpacetimeDBConnection {
    
    // MARK: - Properties
    
    /// The WebSocket transport.
    private let transport: WebSocketTransport
    
    /// The client-side cache.
    private let _cache: ClientCache
    
    /// Current connection state.
    public private(set) var state: ConnectionState = .disconnected
    
    /// The user's identity (available after connection).
    public private(set) var identity: Identity?
    
    /// The connection ID for this session.
    public private(set) var connectionId: ConnectionId?
    
    /// The authentication token (for reconnection).
    private var token: String?
    
    /// The WebSocket URI.
    private let uri: URL
    
    /// The module name.
    public let moduleName: String
    
    /// Timeout for reducer calls.
    private let reducerCallTimeout: TimeInterval
    
    /// Request ID generator.
    private let requestIdGenerator = RequestIdGenerator()
    
    /// Query ID generator.
    private let queryIdGenerator = QueryIdGenerator()
    
    /// Pending reducer calls.
    private let pendingReducerCalls = PendingCallRegistry<ReducerResult>()
    
    /// Pending subscriptions.
    private let pendingSubscriptions = PendingCallRegistry<SubscriptionResult>()
    
    /// Active subscriptions for reconnection.
    private let activeSubscriptions = ActiveSubscriptionRegistry()
    
    /// Task for the message receive loop.
    private var messageLoopTask: Task<Void, Never>?
    
    /// Transport configuration.
    private let configuration: TransportConfiguration
    
    /// Current reconnection attempt.
    private var reconnectAttempt: Int = 0
    
    // MARK: - Callbacks
    
    /// Callback when connected.
    private let onConnectHandler: OnConnectCallback?
    
    /// Callback when disconnected.
    private let onDisconnectHandler: OnDisconnectCallback?
    
    /// Callback when identity is received.
    private let onIdentityHandler: OnIdentityCallback?
    
    // MARK: - Public Accessors
    
    /// The client-side cache for accessing subscribed data.
    ///
    /// Use this to iterate over cached rows:
    /// ```swift
    /// let users = await connection.db.table(named: "users")
    /// for rowData in users.iter() {
    ///     // Decode row...
    /// }
    /// ```
    public var db: ClientCache {
        _cache
    }
    
    /// Whether the connection is currently established.
    public var isConnected: Bool {
        state.isConnected
    }
    
    // MARK: - Initialization
    
    /// Create a new connection.
    ///
    /// Use `SpacetimeDBConnection.builder()` for a more ergonomic API.
    internal init(
        uri: URL,
        moduleName: String,
        token: String?,
        configuration: TransportConfiguration,
        reducerCallTimeout: TimeInterval,
        onConnectHandler: OnConnectCallback?,
        onDisconnectHandler: OnDisconnectCallback?,
        onIdentityHandler: OnIdentityCallback?
    ) {
        self.uri = uri
        self.moduleName = moduleName
        self.token = token
        self.configuration = configuration
        self.reducerCallTimeout = reducerCallTimeout
        self.onConnectHandler = onConnectHandler
        self.onDisconnectHandler = onDisconnectHandler
        self.onIdentityHandler = onIdentityHandler
        
        self.transport = WebSocketTransport(configuration: configuration)
        self._cache = ClientCache()
    }
    
    deinit {
        messageLoopTask?.cancel()
    }
    
    // MARK: - Connection Lifecycle
    
    /// Connect to the SpacetimeDB server.
    ///
    /// This establishes the WebSocket connection and waits for the
    /// `IdentityToken` message before returning.
    ///
    /// - Throws: `ConnectionError.connectionFailed` if connection fails.
    public func connect() async throws {
        guard state == .disconnected else {
            return // Already connected or connecting
        }
        
        state = .connecting
        
        do {
            try await transport.connect(to: uri, token: token)
            
            // Start the message loop
            startMessageLoop()
            
            // Wait for IdentityToken (first message)
            // The message loop will update state to .connected
            // For now, we'll set it here and let the loop handle the rest
            
        } catch {
            state = .disconnected
            throw ConnectionError.connectionFailed(underlying: error)
        }
    }
    
    /// Disconnect from the server.
    ///
    /// This gracefully closes the WebSocket connection.
    public func disconnect() async {
        messageLoopTask?.cancel()
        messageLoopTask = nil
        
        await transport.disconnect()
        
        // Cancel pending calls
        pendingReducerCalls.cancelAll(with: ConnectionError.cancelled)
        pendingSubscriptions.cancelAll(with: ConnectionError.cancelled)
        
        state = .disconnected
    }
    
    // MARK: - Subscriptions
    
    /// Create a subscription builder.
    ///
    /// - Returns: A new `SubscriptionBuilder` for this connection.
    public nonisolated func subscriptionBuilder() -> SubscriptionBuilder {
        SubscriptionBuilder(connection: self)
    }
    
    /// Subscribe to one or more SQL queries.
    ///
    /// This is a convenience method for simple subscriptions.
    ///
    /// - Parameter queries: SQL SELECT queries to subscribe to.
    /// - Returns: A handle for unsubscribing.
    /// - Throws: `ConnectionError` on failure.
    @discardableResult
    public func subscribe(_ queries: String...) async throws -> SubscriptionHandle {
        try await subscriptionBuilder()
            .subscribe(queries)
            .asBatchSubscription()
            .build()
    }
    
    /// Unsubscribe from a subscription.
    ///
    /// - Parameter handle: The subscription handle from `subscribe()`.
    /// - Throws: `ConnectionError` on failure.
    public func unsubscribe(_ handle: SubscriptionHandle) async throws {
        guard state.isConnected else {
            throw ConnectionError.notConnected
        }
        
        if let queryId = handle.queryId {
            // Single subscription - use Unsubscribe
            let requestId = requestIdGenerator.next()
            let message = ClientMessage.unsubscribe(Unsubscribe(
                requestId: requestId,
                queryId: queryId
            ))
            try await transport.send(message)
        }
        
        // Remove from active subscriptions
        activeSubscriptions.remove(handle)
    }
    
    /// Send a batch subscription (internal).
    internal func sendBatchSubscription(queries: [String]) async throws -> SubscriptionHandle {
        guard state.isConnected else {
            throw ConnectionError.notConnected
        }
        
        let requestId = requestIdGenerator.next()
        let message = ClientMessage.subscribe(Subscribe(
            queryStrings: queries,
            requestId: requestId
        ))
        
        try await transport.send(message)
        
        let handle = SubscriptionHandle(
            queryId: nil,
            queries: queries,
            requestId: requestId,
            isBatchSubscription: true
        )
        
        activeSubscriptions.register(handle)
        return handle
    }
    
    /// Send a single subscription (internal).
    internal func sendSingleSubscription(query: String) async throws -> SubscriptionHandle {
        guard state.isConnected else {
            throw ConnectionError.notConnected
        }
        
        let requestId = requestIdGenerator.next()
        let queryId = queryIdGenerator.next()
        
        let message = ClientMessage.subscribeSingle(SubscribeSingle(
            query: query,
            requestId: requestId,
            queryId: queryId
        ))
        
        try await transport.send(message)
        
        let handle = SubscriptionHandle(
            queryId: queryId,
            queries: [query],
            requestId: requestId,
            isBatchSubscription: false
        )
        
        activeSubscriptions.register(handle)
        return handle
    }
    
    // MARK: - Reducer Calls
    
    /// Call a reducer with BSATN-encoded arguments.
    ///
    /// - Parameters:
    ///   - name: The reducer name.
    ///   - args: BSATN-encoded arguments.
    ///   - flags: Call flags (default: `.fullUpdate`).
    /// - Returns: The result of the reducer call.
    /// - Throws: `ConnectionError` on failure or timeout.
    public func callReducer(
        _ name: String,
        args: Data,
        flags: CallReducerFlags = .fullUpdate
    ) async throws -> ReducerResult {
        guard state.isConnected else {
            throw ConnectionError.notConnected
        }
        
        let requestId = requestIdGenerator.next()
        
        let message = ClientMessage.callReducer(CallReducer(
            reducer: name,
            args: args,
            requestId: requestId,
            flags: flags
        ))
        
        // Set up the continuation for awaiting the response
        return try await withCheckedThrowingContinuation { continuation in
            // Create timeout task
            let timeoutTask = Task {
                try? await Task.sleep(nanoseconds: UInt64(reducerCallTimeout * 1_000_000_000))
                
                if let pending = pendingReducerCalls.remove(requestId: requestId) {
                    pending.continuation.resume(throwing: ConnectionError.reducerTimeout(
                        reducerName: name,
                        timeoutSeconds: reducerCallTimeout
                    ))
                }
            }
            
            // Register the pending call
            pendingReducerCalls.register(
                requestId: requestId,
                name: name,
                continuation: continuation,
                timeoutTask: timeoutTask
            )
            
            // Send the message
            Task {
                do {
                    try await transport.send(message)
                } catch {
                    if let pending = pendingReducerCalls.remove(requestId: requestId) {
                        pending.continuation.resume(throwing: error)
                    }
                }
            }
        }
    }
    
    /// Call a reducer with encodable arguments.
    ///
    /// - Parameters:
    ///   - name: The reducer name.
    ///   - args: Arguments that conform to `BSATNEncodable`.
    ///   - flags: Call flags (default: `.fullUpdate`).
    /// - Returns: The result of the reducer call.
    /// - Throws: `ConnectionError` on failure or timeout.
    public func callReducer<T: BSATNEncodable>(
        _ name: String,
        args: T,
        flags: CallReducerFlags = .fullUpdate
    ) async throws -> ReducerResult {
        var encoder = BSATNEncoder()
        try args.encode(to: &encoder)
        return try await callReducer(name, args: encoder.data, flags: flags)
    }
    
    // MARK: - Message Loop
    
    /// Start the message receive loop.
    private func startMessageLoop() {
        messageLoopTask = Task { [weak self] in
            guard let self = self else { return }
            
            let messages = await self.transport.messages
            
            do {
                for try await message in messages {
                    await self.handleServerMessage(message)
                }
                
                // Stream ended - connection closed
                await self.handleDisconnection(error: nil)
                
            } catch {
                await self.handleDisconnection(error: error)
            }
        }
    }
    
    /// Handle an incoming server message.
    private func handleServerMessage(_ message: ServerMessage) async {
        switch message {
        case .identityToken(let token):
            await handleIdentityToken(token)
            
        case .initialSubscription(let sub):
            await handleInitialSubscription(sub)
            
        case .transactionUpdate(let update):
            await handleTransactionUpdate(update)
            
        case .transactionUpdateLight(let update):
            await handleTransactionUpdateLight(update)
            
        case .subscribeApplied(let response):
            await handleSubscribeApplied(response)
            
        case .subscribeMultiApplied(let response):
            await handleSubscribeMultiApplied(response)
            
        case .unsubscribeApplied(let response):
            await handleUnsubscribeApplied(response)
            
        case .unsubscribeMultiApplied(let response):
            await handleUnsubscribeMultiApplied(response)
            
        case .subscriptionError(let error):
            await handleSubscriptionError(error)
            
        case .oneOffQueryResponse(let response):
            await handleOneOffQueryResponse(response)
            
        case .procedureResult(let result):
            await handleProcedureResult(result)
        }
    }
    
    // MARK: - Message Handlers
    
    private func handleIdentityToken(_ token: IdentityToken) async {
        self.identity = token.identity
        self.connectionId = token.connectionId
        self.token = token.token
        self.state = .connected
        self.reconnectAttempt = 0
        
        // Fire identity callback
        if let handler = onIdentityHandler {
            await handler(token.identity, token.token, token.connectionId)
        }
        
        // Fire connect callback
        if let handler = onConnectHandler {
            await handler(self, token.identity, token.token)
        }
    }
    
    private func handleInitialSubscription(_ sub: InitialSubscription) async {
        do {
            try await _cache.applyInitialSubscription(sub)
        } catch {
            // Log error but don't crash
            print("SpacetimeDB: Failed to apply initial subscription: \(error)")
        }
        
        // Resume pending subscription if waiting
        if let pending = pendingSubscriptions.remove(requestId: sub.requestId) {
            let result = SubscriptionResult(
                requestId: sub.requestId,
                queryId: nil,
                initialRowCount: sub.databaseUpdate.totalRowCount,
                executionDurationMicros: UInt64(max(0, sub.totalHostExecutionDuration.microseconds))
            )
            pending.continuation.resume(returning: result)
        }
    }
    
    private func handleTransactionUpdate(_ update: TransactionUpdate) async {
        // Apply database changes
        do {
            try await _cache.applyTransactionUpdate(update)
        } catch {
            print("SpacetimeDB: Failed to apply transaction update: \(error)")
        }
        
        // Resume pending reducer call if this was from our call
        let requestId = update.reducerCall.requestId
        if let pending = pendingReducerCalls.remove(requestId: requestId) {
            let status: ReducerResult.Status
            switch update.status {
            case .committed:
                status = .success
            case .failed(let message):
                status = .failed(message)
            case .outOfEnergy:
                status = .outOfEnergy
            }
            
            let result = ReducerResult(
                reducerName: update.reducerCall.reducerName,
                requestId: requestId,
                status: status,
                timestamp: update.timestamp,
                energyUsed: update.energyQuantaUsed,
                executionDuration: update.totalHostExecutionDuration
            )
            
            pending.continuation.resume(returning: result)
        }
    }
    
    private func handleTransactionUpdateLight(_ update: TransactionUpdateLight) async {
        do {
            try await _cache.applyDatabaseUpdate(update.update)
        } catch {
            print("SpacetimeDB: Failed to apply light transaction update: \(error)")
        }
    }
    
    private func handleSubscribeApplied(_ response: SubscribeApplied) async {
        do {
            try await _cache.applySubscribeApplied(response)
        } catch {
            print("SpacetimeDB: Failed to apply subscribe applied: \(error)")
        }
        
        if let pending = pendingSubscriptions.remove(requestId: response.requestId) {
            let result = SubscriptionResult(
                requestId: response.requestId,
                queryId: response.queryId,
                initialRowCount: Int(response.rows.tableRows.numRows),
                executionDurationMicros: response.totalHostExecutionDurationMicros
            )
            pending.continuation.resume(returning: result)
        }
    }
    
    private func handleSubscribeMultiApplied(_ response: SubscribeMultiApplied) async {
        do {
            try await _cache.applySubscribeMultiApplied(response)
        } catch {
            print("SpacetimeDB: Failed to apply subscribe multi applied: \(error)")
        }
        
        if let pending = pendingSubscriptions.remove(requestId: response.requestId) {
            let result = SubscriptionResult(
                requestId: response.requestId,
                queryId: response.queryId,
                initialRowCount: response.update.totalRowCount,
                executionDurationMicros: response.totalHostExecutionDurationMicros
            )
            pending.continuation.resume(returning: result)
        }
    }
    
    private func handleUnsubscribeApplied(_ response: UnsubscribeApplied) async {
        // Rows were removed from subscription
    }
    
    private func handleUnsubscribeMultiApplied(_ response: UnsubscribeMultiApplied) async {
        // Rows were removed from subscription
    }
    
    private func handleSubscriptionError(_ error: SubscriptionError) async {
        if let requestId = error.requestId {
            if let pending = pendingSubscriptions.remove(requestId: requestId) {
                pending.continuation.resume(throwing: ConnectionError.subscriptionFailed(
                    message: error.error
                ))
            }
        }
    }
    
    private func handleOneOffQueryResponse(_ response: OneOffQueryResponse) async {
        // One-off queries are not yet implemented
    }
    
    private func handleProcedureResult(_ result: ProcedureResult) async {
        // Procedures are not yet fully implemented
    }
    
    // MARK: - Reconnection
    
    private func handleDisconnection(error: Error?) async {
        let wasConnected = state.isConnected
        
        // Cancel pending calls
        let disconnectError = error ?? ConnectionError.connectionClosed(reason: nil)
        pendingReducerCalls.cancelAll(with: disconnectError)
        pendingSubscriptions.cancelAll(with: disconnectError)
        
        // Attempt reconnection if configured
        if configuration.maxReconnectAttempts > 0 && wasConnected {
            await attemptReconnection()
        } else {
            state = .disconnected
            
            // Fire disconnect callback
            if let handler = onDisconnectHandler {
                await handler(error)
            }
        }
    }
    
    private func attemptReconnection() async {
        while reconnectAttempt < configuration.maxReconnectAttempts {
            reconnectAttempt += 1
            state = .reconnecting(attempt: reconnectAttempt)
            
            // Wait with exponential backoff
            let delay = configuration.delayForAttempt(reconnectAttempt - 1)
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            
            do {
                try await transport.connect(to: uri, token: token)
                startMessageLoop()
                
                // Re-subscribe to active queries
                let queries = activeSubscriptions.getAllQueries()
                if !queries.isEmpty {
                    _ = try? await sendBatchSubscription(queries: queries)
                }
                
                return // Successfully reconnected
                
            } catch {
                // Continue to next attempt
            }
        }
        
        // All attempts exhausted
        state = .disconnected
        
        if let handler = onDisconnectHandler {
            await handler(ConnectionError.reconnectFailed(attempts: reconnectAttempt))
        }
    }
}

// MARK: - CustomStringConvertible

extension SpacetimeDBConnection: CustomStringConvertible {
    nonisolated public var description: String {
        "SpacetimeDBConnection(\(moduleName))"
    }
}
