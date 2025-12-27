# SpacetimeDB Swift SDK

A native Swift SDK for [SpacetimeDB](https://spacetimedb.com), providing full BSATN binary protocol support for real-time database synchronization on Apple platforms.

## Features

- **Native BSATN Support** — Full binary protocol implementation for optimal performance
- **Async/Await** — Modern Swift concurrency with actors and AsyncStream
- **All Apple Platforms** — iOS 16+, macOS 13+, tvOS 16+, watchOS 9+, visionOS 1+
- **Type-Safe** — Generated bindings for your SpacetimeDB module's tables and reducers
- **Real-Time Sync** — WebSocket-based subscription to database changes

## Installation

### Swift Package Manager

Add the following to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/SenchoPoro42/spacetimedb-swift.git", from: "0.1.0")
]
```

Or in Xcode: File → Add Package Dependencies → Enter the repository URL.

## Quick Start

```swift
import SpacetimeDB

// Connect to a SpacetimeDB module
let connection = try await SpacetimeDBConnection.builder()
    .withUri(URL(string: "ws://localhost:3000")!)
    .withModuleName("my_module")
    .onConnect { conn, identity in
        print("Connected with identity: \(identity)")
        
        // Subscribe to tables
        try await conn.subscriptionBuilder()
            .subscribe("SELECT * FROM users", "SELECT * FROM messages")
    }
    .onDisconnect { error in
        print("Disconnected: \(error?.localizedDescription ?? "clean")")
    }
    .build()

// Call a reducer
try await connection.reducers.sendMessage(text: "Hello, SpacetimeDB!")

// Access cached data
let users = connection.db.users.iter()
```

## Architecture

```
┌─────────────────────────────────────────────────────┐
│                 Generated Bindings                   │
│  (Tables, Reducers, Types — per module)             │
├─────────────────────────────────────────────────────┤
│                   SDK Core Library                   │
│  ┌─────────────┐ ┌──────────────┐ ┌──────────────┐  │
│  │ Connection  │ │ Client Cache │ │ Serialization│  │
│  │ (WebSocket) │ │ (in-memory)  │ │ (BSATN)      │  │
│  └─────────────┘ └──────────────┘ └──────────────┘  │
├─────────────────────────────────────────────────────┤
│               WebSocket Transport                    │
│            (v1.bsatn.spacetimedb)                   │
└─────────────────────────────────────────────────────┘
```

## Documentation

- [BSATN Format Specification](https://spacetimedb.com/docs/bsatn)
- [SpacetimeDB Documentation](https://spacetimedb.com/docs)

## Status

🚧 **Under Development** — This SDK is being built for the [Parallax](https://github.com/SenchoPoro42/Parallax-one) project.

### Roadmap

- [x] BSATN encoder/decoder
- [x] Protocol messages (ClientMessage, ServerMessage)
- [x] WebSocket transport
- [x] Client cache
- [ ] Connection manager
- [ ] Code generator

## License

Apache License 2.0 — See [LICENSE](LICENSE) for details.

## Contributing

Contributions are welcome! This SDK aims to be contributed upstream to [SpacetimeDB](https://github.com/clockworklabs/SpacetimeDB) once stable.

## Acknowledgments

- [SpacetimeDB](https://spacetimedb.com) by Clockwork Labs
- Architecture patterns from the official TypeScript, C#, and Rust SDKs
