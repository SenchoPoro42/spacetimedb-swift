//
//  WebSocketTransport.swift
//  SpacetimeDB
//
//  WebSocket transport layer for SpacetimeDB communication.
//

import Foundation

/// WebSocket transport for SpacetimeDB communication.
///
/// This actor handles the low-level WebSocket connection to a SpacetimeDB server,
/// including message encoding/decoding and compression handling.
///
/// Usage:
/// ```swift
/// let transport = WebSocketTransport()
/// try await transport.connect(to: serverURL, token: authToken)
///
/// // Send messages
/// try await transport.send(.subscribe(Subscribe(...)))
///
/// // Receive messages
/// for try await message in transport.messages {
///     switch message {
///     case .identityToken(let token):
///         print("Connected with identity: \(token.identity)")
///     // ...
///     }
/// }
/// ```
public actor WebSocketTransport {
    
    // MARK: - Properties
    
    /// Configuration for the transport.
    public let configuration: TransportConfiguration
    
    /// The underlying WebSocket task.
    private var webSocketTask: URLSessionWebSocketTask?
    
    /// The URL session used for connections.
    private let urlSession: URLSession
    
    /// Stream continuation for incoming messages.
    private var messageContinuation: AsyncThrowingStream<ServerMessage, Error>.Continuation?
    
    /// The stream of incoming server messages.
    private var _messages: AsyncThrowingStream<ServerMessage, Error>?
    
    /// Whether the transport is currently connected.
    public var isConnected: Bool {
        webSocketTask?.state == .running
    }
    
    /// Task for the receive loop.
    private var receiveTask: Task<Void, Never>?
    
    /// Task for the ping loop.
    private var pingTask: Task<Void, Never>?
    
    // MARK: - Initialization
    
    /// Creates a new WebSocket transport.
    ///
    /// - Parameter configuration: Configuration for the transport (default: `.default`).
    public init(configuration: TransportConfiguration = .default) {
        self.configuration = configuration
        
        let sessionConfig = URLSessionConfiguration.default
        sessionConfig.timeoutIntervalForRequest = configuration.connectionTimeout
        self.urlSession = URLSession(configuration: sessionConfig)
    }
    
    deinit {
        receiveTask?.cancel()
        pingTask?.cancel()
    }
    
    // MARK: - Connection
    
    /// Connect to a SpacetimeDB server.
    ///
    /// - Parameters:
    ///   - url: The WebSocket URL of the SpacetimeDB server.
    ///   - token: Optional authentication token.
    /// - Throws: `TransportError.connectionFailed` if connection fails,
    ///           `TransportError.alreadyConnected` if already connected.
    public func connect(to url: URL, token: String? = nil) async throws {
        guard webSocketTask == nil || webSocketTask?.state != .running else {
            throw TransportError.alreadyConnected
        }
        
        // Build the connection URL with database path
        var request = URLRequest(url: url)
        request.timeoutInterval = configuration.connectionTimeout
        
        // Set the SpacetimeDB BSATN protocol
        request.setValue(BIN_PROTOCOL, forHTTPHeaderField: "Sec-WebSocket-Protocol")
        
        // Add authorization token if provided
        if let token = token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        // Create WebSocket task
        let task = urlSession.webSocketTask(with: request)
        task.maximumMessageSize = 16 * 1024 * 1024 // 16 MB max message size
        
        // Create the message stream
        let (stream, continuation) = AsyncThrowingStream<ServerMessage, Error>.makeStream()
        self._messages = stream
        self.messageContinuation = continuation
        
        // Start the connection
        task.resume()
        self.webSocketTask = task
        
        // Start the receive loop
        startReceiveLoop()
        
        // Start ping loop if configured
        if configuration.pingInterval != nil {
            startPingLoop()
        }
    }
    
    /// Disconnect from the server.
    ///
    /// - Parameter code: The close code to send (default: `.normalClosure`).
    public func disconnect(code: URLSessionWebSocketTask.CloseCode = .normalClosure) async {
        pingTask?.cancel()
        pingTask = nil
        
        receiveTask?.cancel()
        receiveTask = nil
        
        webSocketTask?.cancel(with: code, reason: nil)
        webSocketTask = nil
        
        messageContinuation?.finish()
        messageContinuation = nil
    }
    
    // MARK: - Messaging
    
    /// Stream of incoming server messages.
    ///
    /// Use `for try await` to receive messages:
    /// ```swift
    /// for try await message in transport.messages {
    ///     // Handle message
    /// }
    /// ```
    public var messages: AsyncThrowingStream<ServerMessage, Error> {
        get async {
            if let existing = _messages {
                return existing
            }
            // Return an empty stream if not connected
            return AsyncThrowingStream { $0.finish() }
        }
    }
    
    /// Send a message to the server.
    ///
    /// - Parameter message: The client message to send.
    /// - Throws: `TransportError.notConnected` if not connected,
    ///           `TransportError.encodingFailed` if encoding fails,
    ///           `TransportError.sendFailed` if sending fails.
    public func send(_ message: ClientMessage) async throws {
        guard let task = webSocketTask, task.state == .running else {
            throw TransportError.notConnected
        }
        
        // Encode the message to BSATN
        let data: Data
        do {
            var encoder = BSATNEncoder()
            try message.encode(to: &encoder)
            data = encoder.data
        } catch {
            throw TransportError.encodingFailed(underlying: error)
        }
        
        // Send as binary message
        do {
            try await task.send(.data(data))
        } catch {
            throw TransportError.sendFailed(underlying: error)
        }
    }
    
    // MARK: - Private Methods
    
    /// Start the receive loop to process incoming messages.
    private func startReceiveLoop() {
        receiveTask = Task { [weak self] in
            guard let self = self else { return }
            
            while !Task.isCancelled {
                do {
                    guard let task = await self.webSocketTask, task.state == .running else {
                        break
                    }
                    
                    let message = try await task.receive()
                    await self.handleReceivedMessage(message)
                } catch {
                    // Connection closed or error
                    await self.handleReceiveError(error)
                    break
                }
            }
        }
    }
    
    /// Handle a received WebSocket message.
    private func handleReceivedMessage(_ message: URLSessionWebSocketTask.Message) {
        switch message {
        case .data(let data):
            processIncomingData(data)
            
        case .string(let string):
            // SpacetimeDB BSATN protocol should only send binary messages
            // but handle string as UTF-8 data just in case
            if let data = string.data(using: .utf8) {
                processIncomingData(data)
            } else {
                messageContinuation?.yield(with: .failure(
                    TransportError.invalidMessage(description: "Received non-UTF8 string message")
                ))
            }
            
        @unknown default:
            messageContinuation?.yield(with: .failure(
                TransportError.invalidMessage(description: "Unknown message type")
            ))
        }
    }
    
    /// Process incoming binary data.
    private func processIncomingData(_ data: Data) {
        do {
            // Decompress if needed (handles compression tag)
            let decompressedData = try decompressServerMessage(data)
            
            // Decode the server message
            var decoder = BSATNDecoder(data: decompressedData)
            let serverMessage = try ServerMessage(from: &decoder)
            
            messageContinuation?.yield(serverMessage)
        } catch let error as DecompressionError {
            switch error {
            case .unknownCompressionTag(let tag):
                messageContinuation?.yield(with: .failure(TransportError.unknownCompressionTag(tag)))
            case .decompressionFailed(let algorithm):
                messageContinuation?.yield(with: .failure(TransportError.decompressionFailed(compressionType: algorithm)))
            case .insufficientData:
                messageContinuation?.yield(with: .failure(TransportError.invalidMessage(description: "Empty message")))
            }
        } catch {
            messageContinuation?.yield(with: .failure(TransportError.decodingFailed(underlying: error)))
        }
    }
    
    /// Handle receive loop errors.
    private func handleReceiveError(_ error: Error) {
        // Check if this is a cancellation
        if Task.isCancelled {
            messageContinuation?.finish()
            return
        }
        
        // Check for close code
        if let urlError = error as? URLError {
            let closeCode = urlError.code.rawValue
            messageContinuation?.finish(throwing: TransportError.connectionClosed(
                closeCode: closeCode,
                reason: urlError.localizedDescription
            ))
        } else {
            messageContinuation?.finish(throwing: TransportError.connectionFailed(underlying: error))
        }
    }
    
    /// Start the ping loop to keep the connection alive.
    private func startPingLoop() {
        guard let interval = configuration.pingInterval else { return }
        
        pingTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
                
                guard !Task.isCancelled else { break }
                guard let self = self else { break }
                
                guard let task = await self.webSocketTask, task.state == .running else {
                    break
                }
                
                task.sendPing { error in
                    if let error = error {
                        // Ping failed - connection may be dead
                        Task { [weak self] in
                            await self?.handleReceiveError(error)
                        }
                    }
                }
            }
        }
    }
}

// MARK: - URL Building Helpers

extension WebSocketTransport {
    
    /// Build a WebSocket URL for connecting to a SpacetimeDB module.
    ///
    /// - Parameters:
    ///   - host: The server host (e.g., "localhost:3000" or "spacetimedb.com").
    ///   - moduleName: The name or identity of the database module.
    ///   - secure: Whether to use secure WebSocket (wss://) or plain (ws://).
    /// - Returns: The constructed WebSocket URL.
    public static func buildURL(
        host: String,
        moduleName: String,
        secure: Bool = true
    ) -> URL? {
        let scheme = secure ? "wss" : "ws"
        let urlString = "\(scheme)://\(host)/database/subscribe/\(moduleName)"
        return URL(string: urlString)
    }
}

// MARK: - Testing Support

extension WebSocketTransport {
    
    /// For testing: directly process incoming data as if received from WebSocket.
    internal func testProcessIncomingData(_ data: Data) {
        processIncomingData(data)
    }
}
