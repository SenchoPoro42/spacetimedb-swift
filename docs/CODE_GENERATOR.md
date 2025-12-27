# SpacetimeDB Swift Code Generator

The SpacetimeDB Swift SDK includes a command-line tool that generates type-safe Swift bindings from your SpacetimeDB module schema. This eliminates manual type definitions and provides compile-time safety for database operations.

## Overview

The code generator (`spacetimedb-codegen`) takes a SpacetimeDB module schema and produces:

- **Type Definitions** — Swift structs for each table row type with `BSATNCodable` conformance
- **Table Wrappers** — Typed accessors with iteration, lookup, and change callbacks
- **Reducer Methods** — Type-safe methods for calling server-side reducers
- **Integration Code** — Extensions to connect everything to `SpacetimeDBConnection`

## Installation

### Building from Source

```bash
# Clone the SDK repository
git clone https://github.com/SenchoPoro42/spacetimedb-swift.git
cd spacetimedb-swift

# Build in release mode
swift build -c release

# The executable is located at:
.build/release/spacetimedb-codegen

# Optionally, install to PATH
cp .build/release/spacetimedb-codegen /usr/local/bin/
```

### Verifying Installation

```bash
spacetimedb-codegen --version
# Output: 0.1.0

spacetimedb-codegen --help
```

## Usage

### Basic Usage

```bash
# Generate from a local schema file
spacetimedb-codegen --schema-file schema.json --out-dir ./Generated

# Generate from a running SpacetimeDB server
spacetimedb-codegen --server ws://localhost:3000 --module-name my_module --out-dir ./Generated
```

### Command-Line Options

| Option | Short | Description |
|--------|-------|-------------|
| `--schema-file` | `-f` | Path to a JSON schema file |
| `--server` | `-s` | SpacetimeDB server URL |
| `--module-name` | `-m` | Module name (required with `--server`) |
| `--out-dir` | `-o` | Output directory for generated files |
| `--force` | | Overwrite existing files |
| `--verbose` | | Print detailed output |
| `--version` | | Print version number |
| `--help` | `-h` | Show help |

### Getting a Schema File

Export your module's schema using the SpacetimeDB CLI:

```bash
# From a published module
spacetime describe my_module --json > schema.json

# From a local build (during development)
spacetime describe --project-path ./my-module --json > schema.json
```

## Generated Output

### Directory Structure

```
Generated/
├── Types/
│   ├── User.swift
│   ├── Message.swift
│   └── GameState.swift
├── Tables/
│   ├── UserTable.swift
│   ├── MessageTable.swift
│   └── GameStateTable.swift
├── Reducers/
│   ├── CreateUserReducer.swift
│   ├── SendMessageReducer.swift
│   └── UpdateGameReducer.swift
├── RemoteTables.swift
├── RemoteReducers.swift
├── DbConnection+Module.swift
└── Reducer.swift
```

### Generated Types

For each table in your module, a Swift struct is generated:

```swift
// Generated/Types/User.swift

import Foundation
import SpacetimeDB

/// Row type for the `user` table.
public struct User: BSATNCodable, Equatable, Hashable, Sendable {
    /// Primary key
    public let id: UInt64
    
    /// The user's display name
    public let name: String
    
    /// Email address (optional)
    public let email: String?
    
    /// When the user was created
    public let createdAt: Timestamp
    
    public init(id: UInt64, name: String, email: String?, createdAt: Timestamp) {
        self.id = id
        self.name = name
        self.email = email
        self.createdAt = createdAt
    }
}
```

### Generated Table Wrappers

Table wrappers provide typed access to cached data:

```swift
// Generated/Tables/UserTable.swift

import Foundation
import SpacetimeDB

/// Typed wrapper for the `user` table.
public final class UserTable: Sendable {
    private let cache: TableCache
    
    internal init(cache: TableCache) {
        self.cache = cache
    }
    
    /// Number of rows in the table.
    public var count: Int {
        cache.count
    }
    
    /// Iterate all rows.
    public func iter() -> [User] {
        cache.iter().compactMap { try? BSATNDecoder.decode(User.self, from: $0) }
    }
    
    /// Find a row by primary key.
    public func find(byId id: UInt64) -> User? {
        var encoder = BSATNEncoder()
        try? id.encode(to: &encoder)
        guard let data = cache.find(byPrimaryKey: encoder.data) else { return nil }
        return try? BSATNDecoder.decode(User.self, from: data)
    }
    
    /// Register a callback for row insertions.
    public func onInsert(_ callback: @escaping @Sendable (User) -> Void) {
        cache.onInsert { data in
            if let user = try? BSATNDecoder.decode(User.self, from: data) {
                callback(user)
            }
        }
    }
    
    /// Register a callback for row deletions.
    public func onDelete(_ callback: @escaping @Sendable (User) -> Void) {
        cache.onDelete { data in
            if let user = try? BSATNDecoder.decode(User.self, from: data) {
                callback(user)
            }
        }
    }
    
    /// Register a callback for row updates.
    public func onUpdate(_ callback: @escaping @Sendable (User, User) -> Void) {
        cache.onUpdate { oldData, newData in
            if let oldUser = try? BSATNDecoder.decode(User.self, from: oldData),
               let newUser = try? BSATNDecoder.decode(User.self, from: newData) {
                callback(oldUser, newUser)
            }
        }
    }
}
```

### Generated Reducer Methods

Reducer bindings provide type-safe method calls:

```swift
// Generated/Reducers/CreateUserReducer.swift

import Foundation
import SpacetimeDB

extension RemoteReducers {
    /// Call the `create_user` reducer.
    ///
    /// - Parameters:
    ///   - name: The user's name
    ///   - email: Optional email address
    /// - Returns: The reducer call result
    public func createUser(name: String, email: String? = nil) async throws -> ReducerResult {
        struct Args: BSATNEncodable {
            let name: String
            let email: String?
        }
        return try await connection.callReducer("create_user", args: Args(name: name, email: email))
    }
}
```

### Integration Code

The generator produces integration code to tie everything together:

```swift
// Generated/RemoteTables.swift

import Foundation
import SpacetimeDB

/// Provides typed access to all tables in the module.
public struct RemoteTables: Sendable {
    public let users: UserTable
    public let messages: MessageTable
    
    internal init(cache: ClientCache) {
        self.users = UserTable(cache: cache.table(named: "user"))
        self.messages = MessageTable(cache: cache.table(named: "message"))
    }
}
```

```swift
// Generated/RemoteReducers.swift

import Foundation
import SpacetimeDB

/// Provides typed access to all reducers in the module.
public struct RemoteReducers: Sendable {
    internal let connection: SpacetimeDBConnection
    
    internal init(connection: SpacetimeDBConnection) {
        self.connection = connection
    }
}
```

```swift
// Generated/DbConnection+Module.swift

import Foundation
import SpacetimeDB

extension SpacetimeDBConnection {
    /// Typed access to tables.
    public var tables: RemoteTables {
        get async { RemoteTables(cache: await db) }
    }
    
    /// Typed access to reducers.
    public var reducers: RemoteReducers {
        RemoteReducers(connection: self)
    }
}
```

## Usage in Your App

### With Generated Bindings

```swift
import SpacetimeDB

// Connect
let connection = try await SpacetimeDBConnection.builder()
    .withUri(URL(string: "ws://localhost:3000")!)
    .withModuleName("my_module")
    .onConnect { conn, _, _ in
        try await conn.subscribe("SELECT * FROM user")
    }
    .build()

// Access typed tables
let users = await connection.tables.users.iter()
for user in users {
    print("User: \(user.name)")  // No decoding needed!
}

// Find by primary key
if let user = await connection.tables.users.find(byId: 42) {
    print("Found: \(user.name)")
}

// Call typed reducers
try await connection.reducers.createUser(name: "Alice", email: "alice@example.com")

// Typed callbacks
await connection.tables.users.onInsert { user in
    print("New user: \(user.name)")
}
```

### Without Generated Bindings (Manual)

```swift
import SpacetimeDB

// Define types manually
struct User: BSATNCodable {
    let id: UInt64
    let name: String
}

// Access raw cache
let table = await connection.db.table(named: "user")
for rowData in table.iter() {
    let user = try BSATNDecoder.decode(User.self, from: rowData)
    print("User: \(user.name)")
}

// Call reducers manually
struct CreateUserArgs: BSATNEncodable {
    let name: String
}
try await connection.callReducer("create_user", args: CreateUserArgs(name: "Alice"))
```

## Type Mappings

The code generator maps SpacetimeDB types to Swift types:

| SpacetimeDB Type | Swift Type |
|------------------|------------|
| `bool` | `Bool` |
| `u8` | `UInt8` |
| `u16` | `UInt16` |
| `u32` | `UInt32` |
| `u64` | `UInt64` |
| `u128` | `UInt128` |
| `u256` | `UInt256` |
| `i8` | `Int8` |
| `i16` | `Int16` |
| `i32` | `Int32` |
| `i64` | `Int64` |
| `i128` | `Int128` |
| `f32` | `Float` |
| `f64` | `Double` |
| `String` | `String` |
| `bytes` | `Data` |
| `Identity` | `Identity` |
| `ConnectionId` | `ConnectionId` |
| `Timestamp` | `Timestamp` |
| `Array<T>` | `[T]` |
| `Option<T>` | `T?` |
| `Map<K, V>` | `[K: V]` |

Custom types (structs, enums) defined in your module are generated as Swift types with matching structure.

## Build Integration

### Xcode Build Phase

To regenerate bindings on each build:

1. Select your target in Xcode
2. Go to Build Phases
3. Click + → New Run Script Phase
4. Drag it above "Compile Sources"
5. Add the script:

```bash
# Regenerate SpacetimeDB bindings

SCHEMA_FILE="${SRCROOT}/schema.json"
OUTPUT_DIR="${SRCROOT}/Generated"
CODEGEN="${BUILD_DIR}/../../SourcePackages/checkouts/spacetimedb-swift/.build/release/spacetimedb-codegen"

if [ -f "$SCHEMA_FILE" ]; then
    if [ -f "$CODEGEN" ]; then
        "$CODEGEN" --schema-file "$SCHEMA_FILE" --out-dir "$OUTPUT_DIR" --force
    else
        echo "warning: spacetimedb-codegen not built. Run 'swift build -c release' in the SDK directory."
    fi
fi
```

### Swift Package Plugin (Future)

A Swift Package Manager build plugin is planned for automatic code generation during package resolution.

## Troubleshooting

### "Schema file not found"

Ensure the path to `schema.json` is correct:

```bash
ls -la schema.json
```

### "Invalid schema format"

The schema must be in the format produced by `spacetime describe --json`. Verify:

```bash
cat schema.json | jq .
```

### "Type not found"

If a referenced type isn't generated:

1. Check that the type is defined in your module
2. Ensure it's used by a public table or reducer
3. Try regenerating with `--verbose` for details

### Generated code doesn't compile

1. Ensure you're using the latest SDK version
2. Check that `SpacetimeDB` is properly imported
3. Verify type names don't conflict with Swift keywords

### Reducer arguments mismatch

The generated reducer methods must match your module's reducer signatures exactly. If they don't:

1. Regenerate bindings with a fresh schema export
2. Verify argument types match the type mappings table above

## Schema Format Reference

The code generator expects a JSON schema in the `RawModuleDef` format:

```json
{
  "typespace": {
    "types": [
      {
        "Product": {
          "elements": [
            { "name": "id", "algebraicType": { "Builtin": "U64" } },
            { "name": "name", "algebraicType": { "Builtin": "String" } }
          ]
        }
      }
    ]
  },
  "tables": [
    {
      "name": "user",
      "productTypeRef": 0,
      "primaryKey": [0],
      "indexes": []
    }
  ],
  "reducers": [
    {
      "name": "create_user",
      "params": {
        "elements": [
          { "name": "name", "algebraicType": { "Builtin": "String" } }
        ]
      }
    }
  ]
}
```

This format is automatically produced by `spacetime describe --json`.
