# Getting Started with SpacetimeDB Swift SDK

This guide walks you through setting up the SpacetimeDB Swift SDK from scratch, connecting to a module, and building a simple application.

## Prerequisites

Before you begin, ensure you have:

- **Swift 5.9+** installed
- **Xcode 15+** (for iOS/macOS/visionOS development)
- A SpacetimeDB server (local or cloud)

## Step 1: Set Up SpacetimeDB (Local Development)

If you don't have a SpacetimeDB server, install the CLI and start a local instance:

```bash
# Install SpacetimeDB CLI
curl -sSf https://install.spacetimedb.com | sh

# Start a local server
spacetime start
```

The server runs at `http://localhost:3000` by default.

## Step 2: Create or Deploy a Module

SpacetimeDB modules define your database schema and server-side logic. Modules are written in Rust, C#, or TypeScript.

For this guide, we'll use a simple example module. If you have an existing module, skip to Step 3.

### Example Rust Module

Create `lib.rs`:

```rust
use spacetimedb::{reducer, table, Identity, Timestamp};

#[table(name = user, public)]
pub struct User {
    #[primary_key]
    #[auto_inc]
    id: u64,
    name: String,
    created_at: Timestamp,
}

#[reducer]
pub fn create_user(ctx: &ReducerContext, name: String) {
    ctx.db.user().insert(User {
        id: 0, // auto-generated
        name,
        created_at: ctx.timestamp,
    });
}
```

### Publish the Module

```bash
# Build and publish
spacetime publish my_module --project-path ./path/to/module
```

## Step 3: Add the SDK to Your Project

### Swift Package Manager (Package.swift)

```swift
// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MyApp",
    platforms: [
        .iOS(.v16),
        .macOS(.v13),
        .visionOS(.v1)
    ],
    dependencies: [
        .package(url: "https://github.com/SenchoPoro42/spacetimedb-swift.git", from: "0.1.0")
    ],
    targets: [
        .executableTarget(
            name: "MyApp",
            dependencies: [
                .product(name: "SpacetimeDB", package: "spacetimedb-swift")
            ]
        )
    ]
)
```

### Xcode Project

1. Open your project in Xcode
2. File → Add Package Dependencies
3. Enter: `https://github.com/SenchoPoro42/spacetimedb-swift.git`
4. Select version `0.1.0` or later
5. Add `SpacetimeDB` to your target

## Step 4: Generate Type-Safe Bindings (Optional but Recommended)

Generate Swift types from your module schema:

```bash
# Get the schema
spacetime describe my_module --json > schema.json

# Build the code generator
cd path/to/spacetimedb-swift
swift build -c release

# Generate bindings
.build/release/spacetimedb-codegen \
    --schema-file /path/to/schema.json \
    --out-dir /path/to/your/project/Generated
```

Add the generated files to your Xcode project.

## Step 5: Connect to SpacetimeDB

### Basic Connection

```swift
import SpacetimeDB

@main
struct MyApp {
    static func main() async throws {
        // Connect to the server
        let connection = try await SpacetimeDBConnection.builder()
            .withUri(URL(string: "ws://localhost:3000")!)
            .withModuleName("my_module")
            .onConnect { conn, identity, token in
                print("Connected! Identity: \(identity)")
                
                // Subscribe to all users
                try await conn.subscribe("SELECT * FROM user")
            }
            .onDisconnect { error in
                if let error = error {
                    print("Disconnected: \(error)")
                }
            }
            .build()
        
        // Keep running
        try await Task.sleep(for: .seconds(3600))
    }
}
```

### SwiftUI App

```swift
import SwiftUI
import SpacetimeDB

@main
struct MyApp: App {
    @StateObject private var viewModel = SpacetimeViewModel()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(viewModel)
                .task {
                    await viewModel.connect()
                }
        }
    }
}

@MainActor
class SpacetimeViewModel: ObservableObject {
    @Published var users: [User] = []
    @Published var isConnected = false
    
    private var connection: SpacetimeDBConnection?
    
    func connect() async {
        do {
            connection = try await SpacetimeDBConnection.builder()
                .withUri(URL(string: "ws://localhost:3000")!)
                .withModuleName("my_module")
                .onConnect { [weak self] conn, identity, token in
                    try await conn.subscribe("SELECT * FROM user")
                    await MainActor.run {
                        self?.isConnected = true
                    }
                    await self?.refreshUsers()
                }
                .onDisconnect { [weak self] _ in
                    await MainActor.run {
                        self?.isConnected = false
                    }
                }
                .build()
        } catch {
            print("Connection failed: \(error)")
        }
    }
    
    func refreshUsers() async {
        guard let db = await connection?.db else { return }
        let table = db.table(named: "user")
        
        users = table.iter().compactMap { rowData in
            try? BSATNDecoder.decode(User.self, from: rowData)
        }
    }
    
    func createUser(name: String) async {
        guard let connection = connection else { return }
        
        do {
            _ = try await connection.callReducer(
                "create_user",
                args: CreateUserArgs(name: name)
            )
            await refreshUsers()
        } catch {
            print("Failed to create user: \(error)")
        }
    }
}

// Define the User type to match your schema
struct User: BSATNCodable {
    let id: UInt64
    let name: String
    let createdAt: Timestamp
}

struct CreateUserArgs: BSATNEncodable {
    let name: String
}
```

## Step 6: Working with Data

### Reading Data

```swift
// Get a table
let userTable = await connection.db.table(named: "user")

// Count rows
print("Total users: \(userTable.count)")

// Iterate all rows
for rowData in userTable.iter() {
    let user = try BSATNDecoder.decode(User.self, from: rowData)
    print("User: \(user.name)")
}
```

### Reacting to Changes

```swift
let userTable = await connection.db.table(named: "user")

// Called when a new row is inserted
userTable.onInsert { rowData in
    if let user = try? BSATNDecoder.decode(User.self, from: rowData) {
        print("New user: \(user.name)")
    }
}

// Called when a row is deleted
userTable.onDelete { rowData in
    if let user = try? BSATNDecoder.decode(User.self, from: rowData) {
        print("User deleted: \(user.name)")
    }
}

// Called when a row is updated
userTable.onUpdate { oldData, newData in
    if let oldUser = try? BSATNDecoder.decode(User.self, from: oldData),
       let newUser = try? BSATNDecoder.decode(User.self, from: newData) {
        print("User updated: \(oldUser.name) → \(newUser.name)")
    }
}
```

### Calling Reducers

```swift
// Define arguments that match your reducer signature
struct CreateUserArgs: BSATNEncodable {
    let name: String
}

// Call the reducer
let result = try await connection.callReducer(
    "create_user",
    args: CreateUserArgs(name: "Alice")
)

// Check the result
switch result.status {
case .success:
    print("User created successfully!")
case .failed(let message):
    print("Failed: \(message)")
case .outOfEnergy:
    print("Out of energy")
}
```

## Step 7: Token Persistence (Reconnection)

SpacetimeDB uses tokens to identify clients. Save the token to reconnect with the same identity:

```swift
let connection = try await SpacetimeDBConnection.builder()
    .withUri(URL(string: "ws://localhost:3000")!)
    .withModuleName("my_module")
    // Use saved token if available
    .withToken(UserDefaults.standard.string(forKey: "spacetimedb_token") ?? "")
    .onIdentityReceived { identity, token, connectionId in
        // Save token for next launch
        UserDefaults.standard.set(token, forKey: "spacetimedb_token")
        print("Identity: \(identity)")
    }
    .build()
```

## Next Steps

- **[Code Generator Guide](CODE_GENERATOR.md)** — Generate type-safe bindings
- **[API Reference](API_REFERENCE.md)** — Full API documentation
- **[SpacetimeDB Docs](https://spacetimedb.com/docs)** — Server and module documentation

## Troubleshooting

### Connection Failed

```
Error: connectionFailed(underlying: ...)
```

- Verify the server is running: `spacetime start`
- Check the URL scheme (`ws://` for local, `wss://` for production)
- Ensure the module name is correct

### Module Not Found

```
Error: subscriptionFailed(message: "module not found")
```

- Verify the module is published: `spacetime list`
- Check the module name matches exactly

### Decoder Errors

```
Error: BSATNDecoder failed to decode...
```

- Ensure your Swift types match the module schema exactly
- Field names in Swift should match BSATN field names (typically snake_case)
- Use generated bindings to avoid manual type definitions

### WebSocket Closes Immediately

- Check server logs: `spacetime logs my_module`
- Ensure you're using the correct protocol version
- Verify there are no firewall issues
