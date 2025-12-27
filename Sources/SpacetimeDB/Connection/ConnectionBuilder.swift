//
//  ConnectionBuilder.swift
//  SpacetimeDB
//
//  Builder pattern for constructing SpacetimeDB connections.
//

import Foundation

// MARK: - Callback Type Aliases

/// Callback invoked when a connection is established.
///
/// - Parameters:
///   - connection: The connected `SpacetimeDBConnection`.
///   - identity: The user's identity.
///   - token: The authentication token for reconnection.
public typealias OnConnectCallback = @Sendable (SpacetimeDBConnection, Identity, String) async -> Void

/// Callback invoked when a connection is lost.
///
/// - Parameter error: The error that caused the disconnection, if any.
public typealias OnDisconnectCallback = @Sendable (Error?) async -> Void

/// Callback invoked when identity information is received.
///
/// Use this to persist the token for future reconnection.
///
/// - Parameters:
///   - identity: The user's identity.
///   - token: The authentication token.
///   - connectionId: The connection ID for this session.
public typealias OnIdentityCallback = @Sendable (Identity, String, ConnectionId) async -> Void

// MARK: - ConnectionBuilder

/// Builder for constructing `SpacetimeDBConnection` instances.
///
/// ## Usage
///
/// ```swift
/// let connection = try await SpacetimeDBConnection.builder()
///     .withUri(URL(string: "ws://localhost:3000")!)
///     .withModuleName("my_module")
///     .onConnect { conn, identity, token in
///         print("Connected with identity: \(identity)")
///     }
///     .build()
/// ```
///
/// ## Required Configuration
///
/// - `withUri(_:)` — The WebSocket URL of the SpacetimeDB server
/// - `withModuleName(_:)` — The name of the database module
///
/// ## Optional Configuration
///
/// - `withToken(_:)` — Existing authentication token for reconnection
/// - `withConfiguration(_:)` — Custom transport configuration
/// - `onConnect(_:)` — Callback when connection is established
/// - `onDisconnect(_:)` — Callback when connection is lost
/// - `onIdentityReceived(_:)` — Callback for token persistence
public struct ConnectionBuilder: Sendable {
    
    // MARK: - Properties
    
    internal var uri: URL?
    internal var moduleName: String?
    internal var token: String?
    internal var configuration: TransportConfiguration
    internal var onConnectHandler: OnConnectCallback?
    internal var onDisconnectHandler: OnDisconnectCallback?
    internal var onIdentityHandler: OnIdentityCallback?
    internal var autoConnect: Bool
    internal var reducerCallTimeout: TimeInterval
    
    // MARK: - Initialization
    
    /// Create a new connection builder with default settings.
    public init() {
        self.configuration = .default
        self.autoConnect = true
        self.reducerCallTimeout = 30.0
    }
    
    // MARK: - Required Configuration
    
    /// Set the WebSocket URI for the SpacetimeDB server.
    ///
    /// - Parameter uri: The WebSocket URL (ws:// or wss://).
    /// - Returns: The builder for chaining.
    public func withUri(_ uri: URL) -> ConnectionBuilder {
        var builder = self
        builder.uri = uri
        return builder
    }
    
    /// Set the database module name.
    ///
    /// - Parameter name: The module name or identity.
    /// - Returns: The builder for chaining.
    public func withModuleName(_ name: String) -> ConnectionBuilder {
        var builder = self
        builder.moduleName = name
        return builder
    }
    
    // MARK: - Optional Configuration
    
    /// Set an existing authentication token.
    ///
    /// Use this to reconnect with a previously obtained token.
    ///
    /// - Parameter token: The authentication token.
    /// - Returns: The builder for chaining.
    public func withToken(_ token: String) -> ConnectionBuilder {
        var builder = self
        builder.token = token
        return builder
    }
    
    /// Set custom transport configuration.
    ///
    /// - Parameter configuration: The transport configuration.
    /// - Returns: The builder for chaining.
    public func withConfiguration(_ configuration: TransportConfiguration) -> ConnectionBuilder {
        var builder = self
        builder.configuration = configuration
        return builder
    }
    
    /// Set the timeout for reducer calls.
    ///
    /// - Parameter timeout: Timeout in seconds (default: 30).
    /// - Returns: The builder for chaining.
    public func withReducerCallTimeout(_ timeout: TimeInterval) -> ConnectionBuilder {
        var builder = self
        builder.reducerCallTimeout = timeout
        return builder
    }
    
    /// Disable automatic connection when building.
    ///
    /// When disabled, you must call `connect()` manually after `build()`.
    ///
    /// - Returns: The builder for chaining.
    public func withoutAutoConnect() -> ConnectionBuilder {
        var builder = self
        builder.autoConnect = false
        return builder
    }
    
    // MARK: - Callbacks
    
    /// Set the callback for when a connection is established.
    ///
    /// This is called after the `IdentityToken` is received from the server.
    ///
    /// - Parameter handler: The callback to invoke.
    /// - Returns: The builder for chaining.
    public func onConnect(_ handler: @escaping OnConnectCallback) -> ConnectionBuilder {
        var builder = self
        builder.onConnectHandler = handler
        return builder
    }
    
    /// Set the callback for when a connection is lost.
    ///
    /// This is called when the WebSocket connection closes unexpectedly
    /// or all reconnection attempts are exhausted.
    ///
    /// - Parameter handler: The callback to invoke.
    /// - Returns: The builder for chaining.
    public func onDisconnect(_ handler: @escaping OnDisconnectCallback) -> ConnectionBuilder {
        var builder = self
        builder.onDisconnectHandler = handler
        return builder
    }
    
    /// Set the callback for when identity information is received.
    ///
    /// Use this to persist the token for future reconnection.
    ///
    /// - Parameter handler: The callback to invoke.
    /// - Returns: The builder for chaining.
    public func onIdentityReceived(_ handler: @escaping OnIdentityCallback) -> ConnectionBuilder {
        var builder = self
        builder.onIdentityHandler = handler
        return builder
    }
    
    // MARK: - Build
    
    /// Build the connection.
    ///
    /// If `autoConnect` is true (default), this will also initiate the connection.
    ///
    /// - Returns: The configured `SpacetimeDBConnection`.
    /// - Throws: `ConnectionError.builderMissingConfiguration` if required fields are missing,
    ///           or connection errors if auto-connect is enabled.
    public func build() async throws -> SpacetimeDBConnection {
        // Validate required configuration
        guard let uri = uri else {
            throw ConnectionError.builderMissingConfiguration(field: "uri")
        }
        guard let moduleName = moduleName else {
            throw ConnectionError.builderMissingConfiguration(field: "moduleName")
        }
        
        // Build the full WebSocket URL
        let fullUri = buildWebSocketURL(baseUri: uri, moduleName: moduleName)
        
        // Create the connection
        let connection = SpacetimeDBConnection(
            uri: fullUri,
            moduleName: moduleName,
            token: token,
            configuration: configuration,
            reducerCallTimeout: reducerCallTimeout,
            onConnectHandler: onConnectHandler,
            onDisconnectHandler: onDisconnectHandler,
            onIdentityHandler: onIdentityHandler
        )
        
        // Auto-connect if enabled
        if autoConnect {
            try await connection.connect()
        }
        
        return connection
    }
    
    // MARK: - Private
    
    /// Build the full WebSocket URL with the module path.
    private func buildWebSocketURL(baseUri: URL, moduleName: String) -> URL {
        // If the URL already has the database path, use it as-is
        if baseUri.path.contains("/database/subscribe/") {
            return baseUri
        }
        
        // Otherwise, append the standard path
        var components = URLComponents(url: baseUri, resolvingAgainstBaseURL: true)!
        components.path = "/database/subscribe/\(moduleName)"
        return components.url!
    }
}

// MARK: - SpacetimeDBConnection Builder Entry Point

extension SpacetimeDBConnection {
    /// Create a new connection builder.
    ///
    /// ## Usage
    ///
    /// ```swift
    /// let connection = try await SpacetimeDBConnection.builder()
    ///     .withUri(URL(string: "ws://localhost:3000")!)
    ///     .withModuleName("my_module")
    ///     .build()
    /// ```
    ///
    /// - Returns: A new `ConnectionBuilder`.
    public static func builder() -> ConnectionBuilder {
        ConnectionBuilder()
    }
}
