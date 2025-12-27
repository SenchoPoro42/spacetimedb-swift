# SpacetimeDB Swift SDK — API Reference

This document provides a comprehensive reference for the SpacetimeDB Swift SDK's public API.

## Table of Contents

- [Connection](#connection)
  - [SpacetimeDBConnection](#spacetimedbconnection)
  - [ConnectionBuilder](#connectionbuilder)
  - [ConnectionState](#connectionstate)
  - [TransportConfiguration](#transportconfiguration)
- [Subscriptions](#subscriptions)
  - [SubscriptionBuilder](#subscriptionbuilder)
  - [SubscriptionHandle](#subscriptionhandle)
- [Cache](#cache)
  - [ClientCache](#clientcache)
  - [TableCache](#tablecache)
- [Reducers](#reducers)
  - [ReducerResult](#reducerresult)
  - [CallReducerFlags](#callreducerflags)
- [Serialization](#serialization)
  - [BSATNEncoder](#bsatnencoder)
  - [BSATNDecoder](#bsatndecoder)
  - [BSATNCodable](#bsatncodable)
- [Types](#types)
  - [Identity](#identity)
  - [ConnectionId](#connectionid)
  - [Timestamp](#timestamp)
  - [UInt128 / UInt256](#uint128--uint256)
- [Errors](#errors)
  - [ConnectionError](#connectionerror)

---

## Connection

### SpacetimeDBConnection

The main actor for managing a connection to a SpacetimeDB server.

```swift
public actor SpacetimeDBConnection
```

#### Properties

| Property | Type | Description |
|----------|------|-------------|
| `state` | `ConnectionState` | Current connection state |
| `isConnected` | `Bool` | Whether actively connected |
| `identity` | `Identity?` | User identity (after connection) |
| `connectionId` | `ConnectionId?` | Session connection ID |
| `moduleName` | `String` | The module name |
| `db` | `ClientCache` | Client-side cache |

#### Methods

##### `builder()`

Create a new `ConnectionBuilder`.

```swift
public static func builder() -> ConnectionBuilder
```

##### `connect()`

Establish the WebSocket connection.

```swift
public func connect() async throws
```

**Throws:** `ConnectionError.connectionFailed` if connection fails.

##### `disconnect()`

Gracefully close the connection.

```swift
public func disconnect() async
```

##### `subscribe(_:)`

Subscribe to SQL queries.

```swift
@discardableResult
public func subscribe(_ queries: String...) async throws -> SubscriptionHandle
```

**Parameters:**
- `queries` — One or more SQL SELECT statements

**Returns:** A `SubscriptionHandle` for unsubscribing

**Throws:** `ConnectionError.notConnected`, `ConnectionError.subscriptionFailed`

##### `subscriptionBuilder()`

Create a subscription builder for advanced subscription options.

```swift
public nonisolated func subscriptionBuilder() -> SubscriptionBuilder
```

##### `unsubscribe(_:)`

Remove a subscription.

```swift
public func unsubscribe(_ handle: SubscriptionHandle) async throws
```

##### `callReducer(_:args:flags:)`

Call a reducer with BSATN-encoded arguments.

```swift
public func callReducer(
    _ name: String,
    args: Data,
    flags: CallReducerFlags = .fullUpdate
) async throws -> ReducerResult
```

**Parameters:**
- `name` — Reducer name
- `args` — BSATN-encoded arguments
- `flags` — Call flags (default: `.fullUpdate`)

**Returns:** `ReducerResult` with status and metadata

**Throws:** `ConnectionError.notConnected`, `ConnectionError.reducerTimeout`

##### `callReducer(_:args:flags:)` (Generic)

Call a reducer with encodable arguments.

```swift
public func callReducer<T: BSATNEncodable>(
    _ name: String,
    args: T,
    flags: CallReducerFlags = .fullUpdate
) async throws -> ReducerResult
```

---

### ConnectionBuilder

Builder for constructing `SpacetimeDBConnection` instances.

```swift
public struct ConnectionBuilder: Sendable
```

#### Methods

##### `withUri(_:)`

Set the WebSocket URI. **Required.**

```swift
public func withUri(_ uri: URL) -> ConnectionBuilder
```

##### `withModuleName(_:)`

Set the module name. **Required.**

```swift
public func withModuleName(_ name: String) -> ConnectionBuilder
```

##### `withToken(_:)`

Set an authentication token for reconnection.

```swift
public func withToken(_ token: String) -> ConnectionBuilder
```

##### `withConfiguration(_:)`

Set custom transport configuration.

```swift
public func withConfiguration(_ configuration: TransportConfiguration) -> ConnectionBuilder
```

##### `withReducerCallTimeout(_:)`

Set timeout for reducer calls (default: 30 seconds).

```swift
public func withReducerCallTimeout(_ timeout: TimeInterval) -> ConnectionBuilder
```

##### `withoutAutoConnect()`

Disable automatic connection on `build()`.

```swift
public func withoutAutoConnect() -> ConnectionBuilder
```

##### `onConnect(_:)`

Set callback for successful connection.

```swift
public func onConnect(_ handler: @escaping OnConnectCallback) -> ConnectionBuilder

// Callback signature:
public typealias OnConnectCallback = @Sendable (SpacetimeDBConnection, Identity, String) async -> Void
```

##### `onDisconnect(_:)`

Set callback for disconnection.

```swift
public func onDisconnect(_ handler: @escaping OnDisconnectCallback) -> ConnectionBuilder

// Callback signature:
public typealias OnDisconnectCallback = @Sendable (Error?) async -> Void
```

##### `onIdentityReceived(_:)`

Set callback for identity token receipt.

```swift
public func onIdentityReceived(_ handler: @escaping OnIdentityCallback) -> ConnectionBuilder

// Callback signature:
public typealias OnIdentityCallback = @Sendable (Identity, String, ConnectionId) async -> Void
```

##### `build()`

Build and optionally connect.

```swift
public func build() async throws -> SpacetimeDBConnection
```

**Throws:** `ConnectionError.builderMissingConfiguration` if required fields missing.

---

### ConnectionState

Connection state enumeration.

```swift
public enum ConnectionState: Equatable, Sendable {
    case disconnected
    case connecting
    case connected
    case reconnecting(attempt: Int)
}
```

#### Properties

| Property | Type | Description |
|----------|------|-------------|
| `isConnected` | `Bool` | True only for `.connected` state |

---

### TransportConfiguration

WebSocket transport configuration.

```swift
public struct TransportConfiguration: Sendable
```

#### Properties

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `maxReconnectAttempts` | `Int` | `5` | Max reconnection attempts |
| `initialReconnectDelay` | `TimeInterval` | `1.0` | First reconnect delay |
| `maxReconnectDelay` | `TimeInterval` | `30.0` | Maximum delay between attempts |
| `enableCompression` | `Bool` | `true` | Enable WebSocket compression |

#### Static Properties

```swift
public static let `default`: TransportConfiguration
```

---

## Subscriptions

### SubscriptionBuilder

Builder for creating subscriptions with advanced options.

```swift
public struct SubscriptionBuilder
```

#### Methods

##### `subscribe(_:)`

Add queries to subscribe to.

```swift
public func subscribe(_ queries: [String]) -> SubscriptionBuilder
public func subscribe(_ queries: String...) -> SubscriptionBuilder
```

##### `asBatchSubscription()`

Send all queries as a single batch subscription.

```swift
public func asBatchSubscription() -> SubscriptionBuilder
```

##### `build()`

Execute the subscription.

```swift
public func build() async throws -> SubscriptionHandle
```

---

### SubscriptionHandle

Handle for managing an active subscription.

```swift
public struct SubscriptionHandle: Sendable
```

#### Properties

| Property | Type | Description |
|----------|------|-------------|
| `queryId` | `QueryId?` | Query ID (for single subscriptions) |
| `queries` | `[String]` | The subscribed queries |
| `requestId` | `UInt32` | Request ID |
| `isBatchSubscription` | `Bool` | Whether this is a batch |

---

## Cache

### ClientCache

In-memory cache of subscribed table data.

```swift
public actor ClientCache
```

#### Methods

##### `table(named:)`

Get a table cache by name.

```swift
public func table(named name: String) -> TableCache
```

---

### TableCache

Cache for a single table's rows.

```swift
public final class TableCache
```

#### Properties

| Property | Type | Description |
|----------|------|-------------|
| `count` | `Int` | Number of cached rows |
| `tableName` | `String` | Name of the table |

#### Methods

##### `iter()`

Iterate all cached rows.

```swift
public func iter() -> [Data]
```

**Returns:** Array of BSATN-encoded row data.

##### `find(byPrimaryKey:)`

Find a row by its primary key.

```swift
public func find(byPrimaryKey key: Data) -> Data?
```

**Parameters:**
- `key` — BSATN-encoded primary key

**Returns:** Row data if found, nil otherwise.

##### `onInsert(_:)`

Register a callback for row insertions.

```swift
public func onInsert(_ callback: @escaping @Sendable (Data) -> Void)
```

##### `onDelete(_:)`

Register a callback for row deletions.

```swift
public func onDelete(_ callback: @escaping @Sendable (Data) -> Void)
```

##### `onUpdate(_:)`

Register a callback for row updates.

```swift
public func onUpdate(_ callback: @escaping @Sendable (Data, Data) -> Void)
```

**Parameters:** Callback receives (old row data, new row data).

---

## Reducers

### ReducerResult

Result of a reducer call.

```swift
public struct ReducerResult: Sendable
```

#### Properties

| Property | Type | Description |
|----------|------|-------------|
| `reducerName` | `String` | Name of the reducer |
| `requestId` | `UInt32` | Request ID |
| `status` | `Status` | Result status |
| `timestamp` | `Timestamp` | Server timestamp |
| `energyUsed` | `Int64` | Energy consumed |
| `executionDuration` | `TimeDuration` | Server execution time |

#### Status Enum

```swift
public enum Status: Sendable {
    case success
    case failed(String)
    case outOfEnergy
}
```

---

### CallReducerFlags

Flags for reducer calls.

```swift
public struct CallReducerFlags: OptionSet, Sendable
```

#### Options

| Flag | Description |
|------|-------------|
| `.fullUpdate` | Request full transaction update |
| `.noSuccessResponse` | Suppress success response |

---

## Serialization

### BSATNEncoder

Encoder for BSATN binary format.

```swift
public struct BSATNEncoder
```

#### Properties

| Property | Type | Description |
|----------|------|-------------|
| `data` | `Data` | Encoded data |

#### Initializer

```swift
public init()
```

#### Usage

```swift
var encoder = BSATNEncoder()
try myValue.encode(to: &encoder)
let data = encoder.data
```

---

### BSATNDecoder

Decoder for BSATN binary format.

```swift
public struct BSATNDecoder
```

#### Static Methods

##### `decode(_:from:)`

Decode a value from BSATN data.

```swift
public static func decode<T: BSATNDecodable>(_ type: T.Type, from data: Data) throws -> T
```

#### Usage

```swift
let user = try BSATNDecoder.decode(User.self, from: rowData)
```

---

### BSATNCodable

Combined encoding and decoding protocol.

```swift
public typealias BSATNCodable = BSATNEncodable & BSATNDecodable
```

#### BSATNEncodable

```swift
public protocol BSATNEncodable {
    func encode(to encoder: inout BSATNEncoder) throws
}
```

#### BSATNDecodable

```swift
public protocol BSATNDecodable {
    init(from decoder: inout BSATNDecoder) throws
}
```

#### Built-in Conformances

The following types conform to `BSATNCodable`:

- `Bool`
- `Int8`, `Int16`, `Int32`, `Int64`
- `UInt8`, `UInt16`, `UInt32`, `UInt64`
- `Float`, `Double`
- `String`
- `Data`
- `Array<T>` where `T: BSATNCodable`
- `Optional<T>` where `T: BSATNCodable`
- `Dictionary<K, V>` where `K: BSATNCodable & Hashable, V: BSATNCodable`
- `Identity`, `ConnectionId`, `Timestamp`
- `UInt128`, `UInt256`

---

## Types

### Identity

A SpacetimeDB user identity (256-bit).

```swift
public struct Identity: BSATNCodable, Equatable, Hashable, Sendable
```

#### Properties

| Property | Type | Description |
|----------|------|-------------|
| `bytes` | `[UInt8]` | Raw 32-byte identity |

#### Initializers

```swift
public init(bytes: [UInt8])
public init(hexString: String) throws
```

#### Methods

##### `toHexString()`

```swift
public func toHexString() -> String
```

---

### ConnectionId

A connection identifier (128-bit).

```swift
public struct ConnectionId: BSATNCodable, Equatable, Hashable, Sendable
```

#### Properties

| Property | Type | Description |
|----------|------|-------------|
| `bytes` | `[UInt8]` | Raw 16-byte ID |

---

### Timestamp

A SpacetimeDB timestamp (microseconds since epoch).

```swift
public struct Timestamp: BSATNCodable, Equatable, Hashable, Comparable, Sendable
```

#### Properties

| Property | Type | Description |
|----------|------|-------------|
| `microseconds` | `Int64` | Microseconds since Unix epoch |

#### Initializers

```swift
public init(microseconds: Int64)
public init(date: Date)
```

#### Methods

##### `toDate()`

```swift
public func toDate() -> Date
```

---

### UInt128 / UInt256

Extended precision unsigned integers.

```swift
public struct UInt128: BSATNCodable, Equatable, Hashable, Sendable
public struct UInt256: BSATNCodable, Equatable, Hashable, Sendable
```

#### Properties

| Property | Type | Description |
|----------|------|-------------|
| `bytes` | `[UInt8]` | Raw bytes (16 or 32) |

---

## Errors

### ConnectionError

Errors that can occur during connection operations.

```swift
public enum ConnectionError: Error
```

#### Cases

| Case | Description |
|------|-------------|
| `.connectionFailed(underlying: Error)` | WebSocket connection failed |
| `.notConnected` | Operation requires active connection |
| `.builderMissingConfiguration(field: String)` | Required builder field missing |
| `.reducerTimeout(reducerName: String, timeoutSeconds: TimeInterval)` | Reducer call timed out |
| `.subscriptionFailed(message: String)` | Subscription query failed |
| `.reconnectFailed(attempts: Int)` | All reconnection attempts exhausted |
| `.cancelled` | Operation was cancelled |
| `.connectionClosed(reason: String?)` | Connection closed unexpectedly |

#### Example

```swift
do {
    try await connection.callReducer("my_reducer", args: args)
} catch let error as ConnectionError {
    switch error {
    case .notConnected:
        print("Not connected to server")
    case .reducerTimeout(let name, let timeout):
        print("Reducer '\(name)' timed out after \(timeout)s")
    case .connectionFailed(let underlying):
        print("Connection failed: \(underlying)")
    default:
        print("Error: \(error)")
    }
}
```

---

## Complete Example

```swift
import SpacetimeDB

// Define types
struct User: BSATNCodable {
    let id: UInt64
    let name: String
    let email: String?
    let createdAt: Timestamp
}

struct CreateUserArgs: BSATNEncodable {
    let name: String
    let email: String?
}

// Connect
let connection = try await SpacetimeDBConnection.builder()
    .withUri(URL(string: "ws://localhost:3000")!)
    .withModuleName("my_module")
    .withConfiguration(TransportConfiguration(
        maxReconnectAttempts: 10,
        enableCompression: true
    ))
    .onConnect { conn, identity, token in
        print("Connected as: \(identity.toHexString())")
        try await conn.subscribe("SELECT * FROM user")
    }
    .onDisconnect { error in
        print("Disconnected: \(error?.localizedDescription ?? "clean")")
    }
    .build()

// Read data
let userTable = await connection.db.table(named: "user")
for rowData in userTable.iter() {
    let user = try BSATNDecoder.decode(User.self, from: rowData)
    print("User: \(user.name)")
}

// Register callbacks
userTable.onInsert { data in
    if let user = try? BSATNDecoder.decode(User.self, from: data) {
        print("New user: \(user.name)")
    }
}

// Call reducer
let result = try await connection.callReducer(
    "create_user",
    args: CreateUserArgs(name: "Alice", email: nil)
)

switch result.status {
case .success:
    print("Created user successfully")
case .failed(let message):
    print("Failed: \(message)")
case .outOfEnergy:
    print("Out of energy")
}

// Disconnect
await connection.disconnect()
```
