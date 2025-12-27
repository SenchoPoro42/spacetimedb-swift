# SpacetimeDB Swift SDK

A native Swift SDK for [SpacetimeDB](https://spacetimedb.com), providing full BSATN binary protocol support for real-time database synchronization on Apple platforms.

## Features

- **Native BSATN Support** — Full binary protocol implementation for optimal performance
- **Async/Await** — Modern Swift concurrency with actors and AsyncStream
- **All Apple Platforms** — iOS 16+, macOS 13+, tvOS 16+, watchOS 9+, visionOS 1+
- **Type-Safe** — Generated bindings for your SpacetimeDB module's tables and reducers
- **Real-Time Sync** — WebSocket-based subscription to database changes
- **Code Generator** — CLI tool to generate Swift bindings from your module schema

## Table of Contents

- [Prerequisites](#prerequisites)
- [Installation](#installation)
- [Quick Start](#quick-start)
- [Usage Guide](#usage-guide)
  - [Connecting](#connecting)
  - [Subscribing to Tables](#subscribing-to-tables)
  - [Accessing Data](#accessing-data)
  - [Calling Reducers](#calling-reducers)
  - [Row Callbacks](#row-callbacks)
  - [Disconnecting](#disconnecting)
- [Code Generator](#code-generator)
- [Architecture](#architecture)
- [API Reference](#api-reference)
- [Error Handling](#error-handling)
- [Platform Notes](#platform-notes)
- [Status](#status)
- [License](#license)

## Prerequisites

- **Swift 5.9+**
- **Xcode 15+** (for iOS/macOS/visionOS development)
- **SpacetimeDB Server** — Either:
  - [SpacetimeDB Cloud](https://spacetimedb.com) (managed)
  - Local instance via [SpacetimeDB CLI](https://spacetimedb.com/docs/getting-started)

### Installing SpacetimeDB CLI (for local development)

```bash
# macOS/Linux
curl -sSf https://install.spacetimedb.com | sh

# Verify installation
spacetime version
```

## Installation

### Swift Package Manager

**In Package.swift:**

```swift
dependencies: [
    .package(url: "https://github.com/SenchoPoro42/spacetimedb-swift.git", from: "0.1.0")
],
targets: [
    .target(
        name: "YourApp",
        dependencies: [
            .product(name: "SpacetimeDB", package: "spacetimedb-swift")
        ]
    )
]
```

**In Xcode:**

1. File → Add Package Dependencies
2. Enter: `https://github.com/SenchoPoro42/spacetimedb-swift.git`
3. Select version: `0.1.0` or later
4. Add `SpacetimeDB` to your target

## Quick Start

```swift
import SpacetimeDB

// 1. Connect to a SpacetimeDB module
let connection = try await SpacetimeDBConnection.builder()
    .withUri(URL(string: "ws://localhost:3000")!)
    .withModuleName("my_module")
    .onConnect { conn, identity, token in
        print("Connected with identity: \(identity)")
        
        // 2. Subscribe to tables
        try await conn.subscribe("SELECT * FROM users")
    }
    .build()

// 3. Access cached data
let usersTable = await connection.db.table(named: "users")
for rowData in usersTable.iter() {
    let user = try BSATNDecoder.decode(User.self, from: rowData)
    print("User: \(user.name)")
}

// 4. Call a reducer
try await connection.callReducer("create_user", args: CreateUserArgs(name: "Alice"))
```

## Usage Guide

### Connecting

Use the builder pattern to configure and establish a connection:

```swift
import SpacetimeDB

let connection = try await SpacetimeDBConnection.builder()
    // Required: Server URL and module name
    .withUri(URL(string: "wss://your-instance.spacetimedb.com")!)
    .withModuleName("your_module")
    
    // Optional: Reconnect with existing token
    .withToken(savedToken)
    
    // Optional: Custom configuration
    .withConfiguration(TransportConfiguration(
        maxReconnectAttempts: 5,
        reconnectDelay: 2.0
    ))
    
    // Optional: Callbacks
    .onConnect { connection, identity, token in
        // Save token for reconnection
        UserDefaults.standard.set(token, forKey: "spacetimedb_token")
        
        // Set up subscriptions
        try await connection.subscribe(
            "SELECT * FROM users",
            "SELECT * FROM messages WHERE room_id = 1"
        )
    }
    .onDisconnect { error in
        if let error = error {
            print("Disconnected with error: \(error)")
        } else {
            print("Disconnected cleanly")
        }
    }
    .onIdentityReceived { identity, token, connectionId in
        print("Identity: \(identity)")
    }
    
    // Build and connect
    .build()
```

#### Connection States

```swift
// Check connection status
if await connection.isConnected {
    // Ready to use
}

// Connection state enum
switch await connection.state {
case .disconnected:
    print("Not connected")
case .connecting:
    print("Connecting...")
case .connected:
    print("Connected")
case .reconnecting(let attempt):
    print("Reconnecting (attempt \(attempt))")
}
```

### Subscribing to Tables

Subscriptions tell the server which rows to sync to your client cache:

```swift
// Simple subscription
try await connection.subscribe(
    "SELECT * FROM users",
    "SELECT * FROM messages"
)

// Using the subscription builder for more control
let handle = try await connection.subscriptionBuilder()
    .subscribe(["SELECT * FROM users WHERE active = true"])
    .asBatchSubscription()  // Groups queries together
    .build()

// Unsubscribe later
try await connection.unsubscribe(handle)
```

### Accessing Data

The client cache stores synced rows locally:

```swift
// Get a table from the cache
let usersTable = await connection.db.table(named: "users")

// Iterate all rows
for rowData in usersTable.iter() {
    let user = try BSATNDecoder.decode(User.self, from: rowData)
    print("User: \(user.name)")
}

// Count rows
let count = usersTable.count

// Find by primary key (requires generated bindings)
if let row = usersTable.find(byPrimaryKey: userIdBytes) {
    let user = try BSATNDecoder.decode(User.self, from: row)
}
```

### Calling Reducers

Reducers are server-side functions that modify the database:

```swift
// Call with BSATN-encodable arguments
struct CreateUserArgs: BSATNEncodable {
    let name: String
    let email: String
}

let result = try await connection.callReducer(
    "create_user",
    args: CreateUserArgs(name: "Alice", email: "alice@example.com")
)

// Check the result
switch result.status {
case .success:
    print("User created!")
case .failed(let message):
    print("Failed: \(message)")
case .outOfEnergy:
    print("Out of energy")
}

// Call with raw BSATN data
var encoder = BSATNEncoder()
try myArgs.encode(to: &encoder)
let result = try await connection.callReducer("my_reducer", args: encoder.data)
```

### Row Callbacks

Get notified when rows change via `ClientCache`:

```swift
let db = await connection.db

// Called on row insert
db.onInsert(tableName: "users") { tableName, rowData in
    let user = try? BSATNDecoder.decode(User.self, from: rowData)
    print("User inserted: \(user?.name ?? "unknown")")
}

// Called on row delete
db.onDelete(tableName: "users") { tableName, rowData in
    let user = try? BSATNDecoder.decode(User.self, from: rowData)
    print("User deleted: \(user?.name ?? "unknown")")
}

// Called on any change (handles inserts, deletes, and updates)
db.onChange(tableName: "users") { tableName, operation in
    switch operation {
    case .insert(let data):
        print("Insert")
    case .delete(let data):
        print("Delete")
    case .update(let oldData, let newData):
        print("Update")
    }
}
```

### Disconnecting

```swift
// Gracefully disconnect
await connection.disconnect()
```

## Code Generator

The SDK includes a CLI tool to generate type-safe Swift bindings from your SpacetimeDB module schema.

### Building the Code Generator

```bash
# Clone the SDK
git clone https://github.com/SenchoPoro42/spacetimedb-swift.git
cd spacetimedb-swift

# Build the CLI tool
swift build -c release

# The binary is at:
.build/release/spacetimedb-codegen
```

### Usage

```bash
# Generate from a schema file
spacetimedb-codegen --schema-file schema.json --out-dir ./ModuleBindings

# Generate from a running server
spacetimedb-codegen --server ws://localhost:3000 --module-name my_module --out-dir ./ModuleBindings

# With verbose output
spacetimedb-codegen --schema-file schema.json --out-dir ./ModuleBindings --verbose

# Force overwrite existing files
spacetimedb-codegen --schema-file schema.json --out-dir ./ModuleBindings --force
```

### Getting a Schema File

```bash
# From SpacetimeDB CLI
spacetime describe my_module --json > schema.json
```

### Generated Structure

```
ModuleBindings/
├── Types/
│   ├── User.swift              # struct User: BSATNCodable
│   └── Message.swift           # struct Message: BSATNCodable
├── Tables/
│   ├── UserTable.swift         # Typed table wrapper
│   └── MessageTable.swift
├── Reducers/
│   ├── CreateUserReducer.swift # extension RemoteReducers
│   └── SendMessageReducer.swift
├── RemoteTables.swift          # Aggregates all tables
├── RemoteReducers.swift        # Aggregates all reducers
├── DbConnection+Module.swift   # Extension adding .tables, .reducers
└── Reducer.swift               # Enum for pattern matching
```

### Using Generated Bindings

With generated bindings, you get type-safe access:

```swift
import SpacetimeDB

// Access tables with types
for user in await connection.tables.users.iter() {
    print("User: \(user.name)")  // No manual decoding!
}

// Find by primary key
if let user = await connection.tables.users.find(byId: userId) {
    print("Found: \(user.name)")
}

// Call reducers with types
try await connection.reducers.createUser(name: "Alice", email: "alice@example.com")

// Row callbacks with types
await connection.tables.users.onInsert { user in
    print("New user: \(user.name)")
}
```

### Xcode Build Phase Integration

To regenerate bindings automatically:

1. Select your target → Build Phases → + → New Run Script Phase
2. Add:

```bash
if [ -f "$SRCROOT/schema.json" ]; then
    "${BUILD_DIR}/../../SourcePackages/checkouts/spacetimedb-swift/.build/release/spacetimedb-codegen" \
        --schema-file "$SRCROOT/schema.json" \
        --out-dir "$SRCROOT/Generated" \
        --force
fi
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

### Core Components

- **SpacetimeDBConnection** — Main actor coordinating transport, cache, and subscriptions
- **WebSocketTransport** — Handles WebSocket communication with BSATN protocol
- **ClientCache** — In-memory cache of subscribed rows with change tracking
- **BSATN Encoder/Decoder** — Binary serialization matching SpacetimeDB's format
- **Code Generator** — Produces type-safe Swift bindings from module schemas

## API Reference

### SpacetimeDBConnection

| Property/Method | Description |
|-----------------|-------------|
| `builder()` | Create a `ConnectionBuilder` |
| `state` | Current `ConnectionState` |
| `isConnected` | Whether connected |
| `identity` | User's `Identity` (after connection) |
| `moduleName` | The module name |
| `db` | Access to `ClientCache` |
| `connect()` | Establish connection |
| `disconnect()` | Close connection |
| `subscribe(_:)` | Subscribe to SQL queries |
| `subscriptionBuilder()` | Create a `SubscriptionBuilder` |
| `callReducer(_:args:)` | Call a server-side reducer |

### TransportConfiguration

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `pingInterval` | `TimeInterval?` | `30.0` | Keep-alive ping interval |
| `connectionTimeout` | `TimeInterval` | `10.0` | Connection timeout |
| `maxReconnectAttempts` | `Int` | `3` | Max reconnection attempts |
| `reconnectDelay` | `TimeInterval` | `1.0` | Base delay between reconnects |
| `maxReconnectDelay` | `TimeInterval` | `30.0` | Max delay with backoff |

### ConnectionBuilder

| Method | Description |
|--------|-------------|
| `withUri(_:)` | Set server URL (required) |
| `withModuleName(_:)` | Set module name (required) |
| `withToken(_:)` | Set auth token for reconnection |
| `withConfiguration(_:)` | Set `TransportConfiguration` |
| `withReducerCallTimeout(_:)` | Set reducer call timeout |
| `withoutAutoConnect()` | Disable auto-connect on build |
| `onConnect(_:)` | Connection established callback |
| `onDisconnect(_:)` | Connection lost callback |
| `onIdentityReceived(_:)` | Identity received callback |
| `build()` | Build and optionally connect |

### ClientCache / TableCache

| Method | Description |
|--------|-------------|
| `table(named:)` | Get a `TableCache` by name |
| `onInsert(tableName:_:)` | Register insert callback |
| `onDelete(tableName:_:)` | Register delete callback |
| `onChange(tableName:_:)` | Register change callback |

### TableCache

| Method | Description |
|--------|-------------|
| `iter()` | Iterate all rows (returns `AnySequence<Data>`) |
| `count` | Number of rows |
| `find(byPrimaryKey:)` | Find row by primary key |

### BSATN

| Type | Description |
|------|-------------|
| `BSATNEncodable` | Protocol for encoding to BSATN |
| `BSATNDecodable` | Protocol for decoding from BSATN |
| `BSATNCodable` | Combines both |
| `BSATNEncoder` | Encoder instance |
| `BSATNDecoder` | Decoder instance |

## Error Handling

```swift
do {
    let connection = try await SpacetimeDBConnection.builder()
        .withUri(URL(string: "ws://localhost:3000")!)
        .withModuleName("my_module")
        .build()
} catch ConnectionError.connectionFailed(let underlying) {
    print("Connection failed: \(underlying)")
} catch ConnectionError.builderMissingConfiguration(let field) {
    print("Missing configuration: \(field)")
} catch {
    print("Unexpected error: \(error)")
}

// Reducer errors
do {
    let result = try await connection.callReducer("my_reducer", args: args)
    switch result.status {
    case .success:
        print("Success!")
    case .failed(let message):
        print("Reducer failed: \(message)")
    case .outOfEnergy:
        print("Out of energy")
    }
} catch ConnectionError.notConnected {
    print("Not connected")
} catch ConnectionError.reducerTimeout(let name, let timeout) {
    print("Reducer \(name) timed out after \(timeout)s")
}
```

### ConnectionError Cases

- `.connectionFailed(underlying:)` — WebSocket connection failed
- `.notConnected` — Operation requires active connection
- `.builderMissingConfiguration(field:)` — Required builder field missing
- `.reducerTimeout(reducerName:timeoutSeconds:)` — Reducer call timed out
- `.reducerCallFailed(reducerName:message:)` — Reducer returned an error
- `.reducerOutOfEnergy(reducerName:)` — Reducer ran out of energy
- `.subscriptionFailed(message:)` — Subscription query failed
- `.reconnectFailed(attempts:)` — All reconnection attempts exhausted
- `.cancelled` — Operation was cancelled
- `.connectionClosed(reason:)` — Connection closed unexpectedly

## Platform Notes

### iOS / visionOS

```swift
// Handle app lifecycle
class AppDelegate: UIApplicationDelegate {
    var connection: SpacetimeDBConnection?
    
    func applicationDidEnterBackground(_ application: UIApplication) {
        // Connection will auto-reconnect when foregrounded
    }
}
```

### SwiftUI

```swift
@MainActor
class SpacetimeViewModel: ObservableObject {
    @Published var users: [User] = []
    private var connection: SpacetimeDBConnection?
    
    func connect() async throws {
        connection = try await SpacetimeDBConnection.builder()
            .withUri(URL(string: "ws://localhost:3000")!)
            .withModuleName("my_module")
            .onConnect { [weak self] conn, _, _ in
                try await conn.subscribe("SELECT * FROM users")
                await self?.refreshUsers()
            }
            .build()
    }
    
    private func refreshUsers() async {
        guard let db = await connection?.db else { return }
        let table = db.table(named: "users")
        users = table.iter().compactMap { try? BSATNDecoder.decode(User.self, from: $0) }
    }
}
```

## Status

✅ **Feature Complete** — All core SDK components are implemented.

### Implemented Features

- [x] BSATN encoder/decoder
- [x] Protocol messages (ClientMessage, ServerMessage)
- [x] WebSocket transport with auto-reconnection
- [x] Client cache with row callbacks
- [x] Connection manager with builder pattern
- [x] Code generator CLI

### Future Enhancements

- [ ] SwiftUI property wrappers (`@SpacetimeQuery`)
- [ ] Combine publishers for reactive updates
- [ ] AsyncSequence for table changes
- [ ] Swift Package Manager plugin for code generation

## License

Apache License 2.0 — See [LICENSE](LICENSE) for details.

## Contributing

Contributions are welcome! This SDK aims to be contributed upstream to [SpacetimeDB](https://github.com/clockworklabs/SpacetimeDB) once stable.

1. Fork the repository
2. Create a feature branch
3. Make your changes with tests
4. Submit a pull request

## Acknowledgments

- [SpacetimeDB](https://spacetimedb.com) by Clockwork Labs
- Architecture patterns from the official TypeScript, C#, and Rust SDKs

## Additional Documentation

- [Getting Started Guide](docs/GETTING_STARTED.md)
- [Code Generator Guide](docs/CODE_GENERATOR.md)
- [API Reference](docs/API_REFERENCE.md)
