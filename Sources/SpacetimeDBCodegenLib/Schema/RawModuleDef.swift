//
//  RawModuleDef.swift
//  SpacetimeDBCodegen
//
//  Models for SpacetimeDB's RawModuleDef JSON schema.
//  This is the top-level schema format returned by the /schema endpoint.
//

import Foundation

// MARK: - RawModuleDef

/// The top-level module definition from SpacetimeDB.
///
/// This is returned by `GET /v1/database/:name/schema?version=9`
/// or `spacetime describe <module> --json`.
public struct RawModuleDef: Codable, Sendable {
    /// The typespace containing all type definitions.
    public let typespace: Typespace
    
    /// Table definitions.
    public let tables: [TableDef]
    
    /// Reducer definitions.
    public let reducers: [ReducerDef]
    
    public init(typespace: Typespace, tables: [TableDef], reducers: [ReducerDef]) {
        self.typespace = typespace
        self.tables = tables
        self.reducers = reducers
    }
}

// MARK: - Typespace

/// The typespace contains all algebraic type definitions for a module.
public struct Typespace: Codable, Sendable {
    /// The type definitions, indexed by position.
    public let types: [AlgebraicType]
    
    public init(types: [AlgebraicType]) {
        self.types = types
    }
    
    /// Resolve a type reference to its definition.
    public func resolve(_ ref: Int) -> AlgebraicType? {
        guard ref >= 0 && ref < types.count else { return nil }
        return types[ref]
    }
    
    /// Fully resolve a type, following any references.
    public func fullyResolve(_ type: AlgebraicType) -> AlgebraicType {
        switch type {
        case .ref(let index):
            if let resolved = resolve(index) {
                return fullyResolve(resolved)
            }
            return type
        default:
            return type
        }
    }
}

// MARK: - TableDef

/// Definition of a table in the module.
public struct TableDef: Codable, Sendable {
    /// The name of the table.
    public let name: String
    
    /// Reference to the product type defining the row structure.
    public let productTypeRef: Int
    
    /// Column indices that form the primary key.
    /// Empty array means no explicit primary key.
    public let primaryKey: [Int]
    
    /// Index definitions for this table.
    public let indexes: [IndexDef]
    
    /// Constraint definitions.
    public let constraints: [ConstraintDef]
    
    /// Sequence definitions (for auto-increment).
    public let sequences: [SequenceDef]
    
    /// Schedule configuration (for scheduled tables).
    public let schedule: ScheduleOption
    
    /// Whether this is a user or system table.
    public let tableType: TableType
    
    /// Access level (public/private).
    public let tableAccess: TableAccess
    
    private enum CodingKeys: String, CodingKey {
        case name
        case productTypeRef = "product_type_ref"
        case primaryKey = "primary_key"
        case indexes
        case constraints
        case sequences
        case schedule
        case tableType = "table_type"
        case tableAccess = "table_access"
    }
    
    public init(
        name: String,
        productTypeRef: Int,
        primaryKey: [Int] = [],
        indexes: [IndexDef] = [],
        constraints: [ConstraintDef] = [],
        sequences: [SequenceDef] = [],
        schedule: ScheduleOption = .none,
        tableType: TableType = .user,
        tableAccess: TableAccess = .private
    ) {
        self.name = name
        self.productTypeRef = productTypeRef
        self.primaryKey = primaryKey
        self.indexes = indexes
        self.constraints = constraints
        self.sequences = sequences
        self.schedule = schedule
        self.tableType = tableType
        self.tableAccess = tableAccess
    }
}

// MARK: - IndexDef

/// Definition of an index on a table.
public struct IndexDef: Codable, Sendable {
    /// The name of the index.
    public let name: String
    
    /// The type of index.
    public let indexType: IndexType
    
    /// Column indices included in this index.
    public let columns: [Int]
    
    private enum CodingKeys: String, CodingKey {
        case name
        case indexType = "index_type"
        case columns
    }
    
    public init(name: String, indexType: IndexType, columns: [Int]) {
        self.name = name
        self.indexType = indexType
        self.columns = columns
    }
}

/// Types of indexes supported.
public enum IndexType: Codable, Sendable {
    case btree
    case hash
    
    private enum CodingKeys: String, CodingKey {
        case BTree, Hash
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if container.contains(.BTree) {
            self = .btree
        } else if container.contains(.Hash) {
            self = .hash
        } else {
            throw DecodingError.dataCorrupted(
                DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Unknown IndexType")
            )
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .btree: try container.encode([String](), forKey: .BTree)
        case .hash: try container.encode([String](), forKey: .Hash)
        }
    }
}

// MARK: - ConstraintDef

/// Definition of a constraint on a table.
public struct ConstraintDef: Codable, Sendable {
    /// The name of the constraint.
    public let name: String
    
    /// The type of constraint.
    public let constraintType: ConstraintType
    
    /// Column indices this constraint applies to.
    public let columns: [Int]
    
    private enum CodingKeys: String, CodingKey {
        case name
        case constraintType = "constraint_type"
        case columns
    }
    
    public init(name: String, constraintType: ConstraintType, columns: [Int]) {
        self.name = name
        self.constraintType = constraintType
        self.columns = columns
    }
}

/// Types of constraints supported.
public enum ConstraintType: Codable, Sendable {
    case unique
    
    private enum CodingKeys: String, CodingKey {
        case Unique
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if container.contains(.Unique) {
            self = .unique
        } else {
            throw DecodingError.dataCorrupted(
                DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Unknown ConstraintType")
            )
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .unique: try container.encode([String](), forKey: .Unique)
        }
    }
}

// MARK: - SequenceDef

/// Definition of a sequence (auto-increment) for a column.
public struct SequenceDef: Codable, Sendable {
    /// The name of the sequence.
    public let name: String
    
    /// The column index this sequence applies to.
    public let column: Int
    
    public init(name: String, column: Int) {
        self.name = name
        self.column = column
    }
}

// MARK: - ScheduleOption

/// Whether a table is used for scheduling reducers.
public enum ScheduleOption: Codable, Sendable {
    case none
    case some(String) // reducer name
    
    private enum CodingKeys: String, CodingKey {
        case none, some
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if container.contains(.none) {
            self = .none
        } else if let reducer = try container.decodeIfPresent(String.self, forKey: .some) {
            self = .some(reducer)
        } else {
            throw DecodingError.dataCorrupted(
                DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Unknown ScheduleOption")
            )
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .none: try container.encode([String](), forKey: .none)
        case .some(let reducer): try container.encode(reducer, forKey: .some)
        }
    }
}

// MARK: - TableType

/// Whether a table is user-defined or system.
public enum TableType: Codable, Sendable {
    case user
    case system
    
    private enum CodingKeys: String, CodingKey {
        case User, System
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if container.contains(.User) {
            self = .user
        } else if container.contains(.System) {
            self = .system
        } else {
            throw DecodingError.dataCorrupted(
                DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Unknown TableType")
            )
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .user: try container.encode([String](), forKey: .User)
        case .system: try container.encode([String](), forKey: .System)
        }
    }
}

// MARK: - TableAccess

/// Access level for a table.
public enum TableAccess: Codable, Sendable {
    case `public`
    case `private`
    
    private enum CodingKeys: String, CodingKey {
        case Public, Private
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if container.contains(.Public) {
            self = .public
        } else if container.contains(.Private) {
            self = .private
        } else {
            throw DecodingError.dataCorrupted(
                DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Unknown TableAccess")
            )
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .public: try container.encode([String](), forKey: .Public)
        case .private: try container.encode([String](), forKey: .Private)
        }
    }
}

// MARK: - ReducerDef

/// Definition of a reducer in the module.
public struct ReducerDef: Codable, Sendable {
    /// The name of the reducer.
    public let name: String
    
    /// The parameters of the reducer as a product type.
    public let params: ProductType
    
    /// Lifecycle type of this reducer.
    public let lifecycle: ReducerLifecycle
    
    public init(name: String, params: ProductType, lifecycle: ReducerLifecycle = .none) {
        self.name = name
        self.params = params
        self.lifecycle = lifecycle
    }
}

// MARK: - ReducerLifecycle

/// Lifecycle type for a reducer.
public enum ReducerLifecycle: Sendable, Equatable {
    /// Regular reducer, callable by clients.
    case none
    
    /// Init reducer, called once when module is first published.
    case onInit
    
    /// Connect reducer, called when a client connects.
    case onConnect
    
    /// Disconnect reducer, called when a client disconnects.
    case onDisconnect
    
    /// Whether this reducer should be exposed to clients.
    public var isCallable: Bool {
        self == .none
    }
}

extension ReducerLifecycle: Codable {
    private enum CodingKeys: String, CodingKey {
        case none, some
    }
    
    private enum LifecycleTypeKeys: String, CodingKey {
        case OnInit, OnConnect, OnDisconnect
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        if container.contains(.none) {
            self = .none
            return
        }
        
        // Try to decode the "some" variant which contains lifecycle type
        if container.contains(.some) {
            let someContainer = try container.nestedContainer(keyedBy: LifecycleTypeKeys.self, forKey: .some)
            if someContainer.contains(.OnInit) {
                self = .onInit
            } else if someContainer.contains(.OnConnect) {
                self = .onConnect
            } else if someContainer.contains(.OnDisconnect) {
                self = .onDisconnect
            } else {
                self = .none
            }
            return
        }
        
        self = .none
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .none:
            try container.encode([String](), forKey: .none)
        case .onInit:
            var nested = container.nestedContainer(keyedBy: LifecycleTypeKeys.self, forKey: .some)
            try nested.encode([String](), forKey: .OnInit)
        case .onConnect:
            var nested = container.nestedContainer(keyedBy: LifecycleTypeKeys.self, forKey: .some)
            try nested.encode([String](), forKey: .OnConnect)
        case .onDisconnect:
            var nested = container.nestedContainer(keyedBy: LifecycleTypeKeys.self, forKey: .some)
            try nested.encode([String](), forKey: .OnDisconnect)
        }
    }
}

// MARK: - Convenience Extensions

extension TableDef {
    /// Whether this table has an explicit primary key.
    public var hasPrimaryKey: Bool {
        !primaryKey.isEmpty
    }
    
    /// Whether this table is public (readable by clients).
    public var isPublic: Bool {
        tableAccess == .public
    }
}

extension ReducerDef {
    /// Whether this reducer can be called by clients.
    public var isCallable: Bool {
        lifecycle.isCallable
    }
}
