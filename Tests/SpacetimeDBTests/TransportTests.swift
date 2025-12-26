//
//  TransportTests.swift
//  SpacetimeDB
//
//  Unit tests for the transport layer.
//

import XCTest
@testable import SpacetimeDB

final class TransportTests: XCTestCase {
    
    // MARK: - Compression Type Tests
    
    func testCompressionTypeFromTag() {
        XCTAssertEqual(CompressionType(tag: 0), CompressionType.none)
        XCTAssertEqual(CompressionType(tag: 1), .brotli)
        XCTAssertEqual(CompressionType(tag: 2), .gzip)
        XCTAssertNil(CompressionType(tag: 3))
        XCTAssertNil(CompressionType(tag: 255))
    }
    
    func testCompressionTypeRawValue() {
        XCTAssertEqual(CompressionType.none.rawValue, 0)
        XCTAssertEqual(CompressionType.brotli.rawValue, 1)
        XCTAssertEqual(CompressionType.gzip.rawValue, 2)
    }
    
    // MARK: - Decompression Tests
    
    func testDecompressUncompressedData() throws {
        let original = Data("Hello, SpacetimeDB!".utf8)
        
        // Create data with no-compression tag
        let taggedData = Data([0]) + original
        
        let decompressed = try decompressServerMessage(taggedData)
        XCTAssertEqual(decompressed, original)
    }
    
    func testDecompressEmptyUncompressedData() throws {
        // Just the tag, no payload
        let taggedData = Data([0])
        
        let decompressed = try decompressServerMessage(taggedData)
        XCTAssertEqual(decompressed, Data())
    }
    
    func testDecompressBrotliData() throws {
        let original = Data("Hello, SpacetimeDB! This is a test message for Brotli compression.".utf8)
        
        // Compress using our test helper
        guard let compressed = compressForTesting(original, type: .brotli) else {
            XCTFail("Failed to compress test data")
            return
        }
        
        // Decompress
        let decompressed = try decompressServerMessage(compressed)
        XCTAssertEqual(decompressed, original)
    }
    
    func testDecompressGzipData() throws {
        let original = Data("Hello, SpacetimeDB! This is a test message for Gzip compression.".utf8)
        
        // Compress using our test helper
        guard let compressed = compressForTesting(original, type: .gzip) else {
            XCTFail("Failed to compress test data")
            return
        }
        
        // Decompress
        let decompressed = try decompressServerMessage(compressed)
        XCTAssertEqual(decompressed, original)
    }
    
    func testDecompressLargeData() throws {
        // Create a larger payload to test buffer resizing
        var original = Data()
        for i in 0..<1000 {
            original.append(contentsOf: "Line \(i): This is test data for compression testing.\n".utf8)
        }
        
        // Test with Brotli
        guard let brotliCompressed = compressForTesting(original, type: .brotli) else {
            XCTFail("Failed to compress with Brotli")
            return
        }
        let brotliDecompressed = try decompressServerMessage(brotliCompressed)
        XCTAssertEqual(brotliDecompressed, original)
        
        // Verify compression actually reduced size
        XCTAssertLessThan(brotliCompressed.count, original.count)
    }
    
    func testDecompressUnknownTag() {
        let data = Data([99, 1, 2, 3])  // Unknown tag 99
        
        XCTAssertThrowsError(try decompressServerMessage(data)) { error in
            guard case DecompressionError.unknownCompressionTag(99) = error else {
                XCTFail("Expected unknownCompressionTag error, got \(error)")
                return
            }
        }
    }
    
    func testDecompressEmptyData() {
        XCTAssertThrowsError(try decompressServerMessage(Data())) { error in
            guard case DecompressionError.insufficientData = error else {
                XCTFail("Expected insufficientData error, got \(error)")
                return
            }
        }
    }
    
    // MARK: - Transport Configuration Tests
    
    func testDefaultConfiguration() {
        let config = TransportConfiguration.default
        
        XCTAssertEqual(config.pingInterval, 30.0)
        XCTAssertEqual(config.connectionTimeout, 10.0)
        XCTAssertEqual(config.maxReconnectAttempts, 3)
        XCTAssertEqual(config.reconnectDelay, 1.0)
        XCTAssertEqual(config.maxReconnectDelay, 30.0)
    }
    
    func testNoReconnectConfiguration() {
        let config = TransportConfiguration.noReconnect
        
        XCTAssertEqual(config.maxReconnectAttempts, 0)
    }
    
    func testCustomConfiguration() {
        let config = TransportConfiguration(
            pingInterval: 60.0,
            connectionTimeout: 5.0,
            maxReconnectAttempts: 5,
            reconnectDelay: 2.0,
            maxReconnectDelay: 60.0
        )
        
        XCTAssertEqual(config.pingInterval, 60.0)
        XCTAssertEqual(config.connectionTimeout, 5.0)
        XCTAssertEqual(config.maxReconnectAttempts, 5)
        XCTAssertEqual(config.reconnectDelay, 2.0)
        XCTAssertEqual(config.maxReconnectDelay, 60.0)
    }
    
    func testDisabledPingConfiguration() {
        let config = TransportConfiguration(pingInterval: nil)
        XCTAssertNil(config.pingInterval)
    }
    
    func testExponentialBackoffDelay() {
        let config = TransportConfiguration(
            reconnectDelay: 1.0,
            maxReconnectDelay: 30.0
        )
        
        // Test exponential backoff: delay * 2^attempt
        XCTAssertEqual(config.delayForAttempt(0), 1.0)   // 1 * 2^0 = 1
        XCTAssertEqual(config.delayForAttempt(1), 2.0)   // 1 * 2^1 = 2
        XCTAssertEqual(config.delayForAttempt(2), 4.0)   // 1 * 2^2 = 4
        XCTAssertEqual(config.delayForAttempt(3), 8.0)   // 1 * 2^3 = 8
        XCTAssertEqual(config.delayForAttempt(4), 16.0)  // 1 * 2^4 = 16
        XCTAssertEqual(config.delayForAttempt(5), 30.0)  // 1 * 2^5 = 32, capped at 30
        XCTAssertEqual(config.delayForAttempt(10), 30.0) // Way over max, capped at 30
    }
    
    func testConfigurationDescription() {
        let config = TransportConfiguration.default
        let description = config.description
        
        XCTAssertTrue(description.contains("ping: 30.0s"))
        XCTAssertTrue(description.contains("timeout: 10.0s"))
        XCTAssertTrue(description.contains("reconnect: 3 attempts"))
    }
    
    func testConfigurationDescriptionDisabled() {
        let config = TransportConfiguration(
            pingInterval: nil,
            maxReconnectAttempts: 0
        )
        let description = config.description
        
        XCTAssertTrue(description.contains("ping: disabled"))
        XCTAssertTrue(description.contains("reconnect: disabled"))
    }
    
    // MARK: - Transport Error Tests
    
    func testTransportErrorDescriptions() {
        struct TestError: Error {
            var localizedDescription: String { "test error" }
        }
        
        let errors: [(TransportError, String)] = [
            (.connectionFailed(underlying: TestError()), "Connection failed"),
            (.connectionClosed(closeCode: 1000, reason: "goodbye"), "Connection closed"),
            (.connectionClosed(closeCode: 1000, reason: nil), "Connection closed"),
            (.sendFailed(underlying: TestError()), "Failed to send"),
            (.encodingFailed(underlying: TestError()), "Failed to encode"),
            (.decodingFailed(underlying: TestError()), "Failed to decode"),
            (.decompressionFailed(compressionType: .brotli), "Decompression failed"),
            (.invalidMessage(description: "bad data"), "Invalid message"),
            (.timeout, "timed out"),
            (.notConnected, "not connected"),
            (.alreadyConnected, "already connected"),
            (.unknownCompressionTag(99), "Unknown compression tag: 99"),
        ]
        
        for (error, expectedSubstring) in errors {
            let description = error.localizedDescription
            XCTAssertTrue(
                description.lowercased().contains(expectedSubstring.lowercased()),
                "Error description '\(description)' should contain '\(expectedSubstring)'"
            )
        }
    }
    
    // MARK: - WebSocket Close Code Tests
    
    func testCloseCodeDescriptions() {
        let codes: [(URLSessionWebSocketTask.CloseCode, String)] = [
            (.normalClosure, "Normal"),
            (.goingAway, "Going away"),
            (.protocolError, "Protocol"),
            (.unsupportedData, "Unsupported"),
            (.noStatusReceived, "No status"),
            (.abnormalClosure, "Abnormal"),
            (.invalidFramePayloadData, "Invalid frame"),
            (.policyViolation, "Policy"),
            (.messageTooBig, "too big"),
            (.mandatoryExtensionMissing, "extension"),
            (.internalServerError, "Internal server"),
            (.tlsHandshakeFailure, "TLS"),
        ]
        
        for (code, expectedSubstring) in codes {
            let description = code.description
            XCTAssertTrue(
                description.lowercased().contains(expectedSubstring.lowercased()),
                "Close code description '\(description)' should contain '\(expectedSubstring)'"
            )
        }
    }
    
    // MARK: - URL Building Tests
    
    func testBuildURLSecure() {
        let url = WebSocketTransport.buildURL(
            host: "testcloud.spacetimedb.com",
            moduleName: "my-game",
            secure: true
        )
        
        XCTAssertNotNil(url)
        XCTAssertEqual(url?.scheme, "wss")
        XCTAssertEqual(url?.host, "testcloud.spacetimedb.com")
        XCTAssertEqual(url?.path, "/database/subscribe/my-game")
    }
    
    func testBuildURLInsecure() {
        let url = WebSocketTransport.buildURL(
            host: "localhost:3000",
            moduleName: "test-module",
            secure: false
        )
        
        XCTAssertNotNil(url)
        XCTAssertEqual(url?.scheme, "ws")
        XCTAssertEqual(url?.host, "localhost")
        XCTAssertEqual(url?.port, 3000)
        XCTAssertEqual(url?.path, "/database/subscribe/test-module")
    }
    
    // MARK: - WebSocket Transport Actor Tests
    
    func testTransportInitialization() async {
        let transport = WebSocketTransport()
        let isConnected = await transport.isConnected
        XCTAssertFalse(isConnected)
    }
    
    func testTransportWithCustomConfiguration() async {
        let config = TransportConfiguration(
            pingInterval: 60.0,
            connectionTimeout: 5.0
        )
        let transport = WebSocketTransport(configuration: config)
        let actualConfig = await transport.configuration
        
        XCTAssertEqual(actualConfig.pingInterval, 60.0)
        XCTAssertEqual(actualConfig.connectionTimeout, 5.0)
    }
    
    func testSendWhenNotConnected() async {
        let transport = WebSocketTransport()
        
        let message = ClientMessage.subscribe(Subscribe(
            queryStrings: ["SELECT * FROM users"],
            requestId: 1
        ))
        
        do {
            try await transport.send(message)
            XCTFail("Expected notConnected error")
        } catch TransportError.notConnected {
            // Expected
        } catch {
            XCTFail("Expected notConnected error, got \(error)")
        }
    }
    
    // MARK: - Roundtrip Compression Tests
    
    func testCompressionRoundtripWithServerMessage() throws {
        // Create a simple server message
        let identityValue = UInt256(b0: 1, b1: 2, b2: 3, b3: 4)
        let identity = Identity(identityValue)
        let connectionId = ConnectionId(12345)
        
        let identityToken = IdentityToken(
            identity: identity,
            token: "test-token-abc123",
            connectionId: connectionId
        )
        
        // Encode the message
        var encoder = BSATNEncoder()
        try ServerMessage.identityToken(identityToken).encode(to: &encoder)
        let originalData = encoder.data
        
        // Test with each compression type
        for compressionType in [CompressionType.none, .brotli, .gzip] {
            guard let compressed = compressForTesting(originalData, type: compressionType) else {
                XCTFail("Failed to compress with \(compressionType)")
                continue
            }
            
            let decompressed = try decompressServerMessage(compressed)
            XCTAssertEqual(decompressed, originalData, "Roundtrip failed for \(compressionType)")
            
            // Verify we can decode the message
            var decoder = BSATNDecoder(data: decompressed)
            let message = try ServerMessage(from: &decoder)
            
            if case .identityToken(let decoded) = message {
                XCTAssertEqual(decoded.token, "test-token-abc123")
                XCTAssertEqual(decoded.connectionId.value, 12345)
            } else {
                XCTFail("Expected identityToken message")
            }
        }
    }
}
