//
//  DatabaseUpdate.swift
//  SpacetimeDB
//
//  Types for representing database row updates.
//

import Foundation

// MARK: - RowSizeHint

/// Hint about row sizes in a BsatnRowList to facilitate decoding.
public enum RowSizeHint: Sendable {
    /// Each row in the list has the same fixed size.
    case fixedSize(UInt16)
    
    /// Variable-size rows with offsets marking the start of each row.
    /// The end of each row is inferred from the start of the next row or the data length.
    case rowOffsets([UInt64])
}

extension RowSizeHint: BSATNCodable {
    public func encode(to encoder: inout BSATNEncoder) throws {
        switch self {
        case .fixedSize(let size):
            encoder.encode(UInt8(0))  // tag
            encoder.encode(size)
        case .rowOffsets(let offsets):
            encoder.encode(UInt8(1))  // tag
            try offsets.encode(to: &encoder)
        }
    }
    
    public init(from decoder: inout BSATNDecoder) throws {
        let tag = try decoder.decode(UInt8.self)
        switch tag {
        case 0:
            let size = try decoder.decode(UInt16.self)
            self = .fixedSize(size)
        case 1:
            let offsets = try [UInt64](from: &decoder)
            self = .rowOffsets(offsets)
        default:
            throw BSATNDecodingError.invalidEnumTag(tag: tag, typeName: "RowSizeHint")
        }
    }
}

// MARK: - BsatnRowList

/// A packed list of BSATN-encoded rows.
///
/// Contains a flattened byte array of row data plus hints about row boundaries.
public struct BsatnRowList: Sendable {
    /// Hint about row sizes for efficient decoding.
    public let sizeHint: RowSizeHint
    
    /// The flattened BSATN-encoded row data.
    public let rowsData: Data
    
    /// Create a new row list.
    public init(sizeHint: RowSizeHint, rowsData: Data) {
        self.sizeHint = sizeHint
        self.rowsData = rowsData
    }
    
    /// Create an empty row list.
    public static var empty: BsatnRowList {
        BsatnRowList(sizeHint: .rowOffsets([]), rowsData: Data())
    }
    
    /// The number of rows in the list.
    public var count: Int {
        switch sizeHint {
        case .fixedSize(let size):
            guard size > 0 else { return 0 }
            return rowsData.count / Int(size)
        case .rowOffsets(let offsets):
            return offsets.count
        }
    }
    
    /// Whether the list is empty.
    public var isEmpty: Bool {
        count == 0
    }
    
    /// The total size of row data in bytes.
    public var byteCount: Int {
        rowsData.count
    }
    
    /// Get the byte range for a row at the given index.
    public func rowRange(at index: Int) -> Range<Int>? {
        let dataEnd = rowsData.count
        
        switch sizeHint {
        case .fixedSize(let size):
            let rowSize = Int(size)
            let start = index * rowSize
            if start >= dataEnd {
                return nil
            }
            let end = (index + 1) * rowSize
            return start..<end
            
        case .rowOffsets(let offsets):
            guard index < offsets.count else { return nil }
            let start = Int(offsets[index])
            let end = index + 1 < offsets.count ? Int(offsets[index + 1]) : dataEnd
            return start..<end
        }
    }
    
    /// Get the raw bytes for a row at the given index.
    public func rowData(at index: Int) -> Data? {
        guard let range = rowRange(at: index) else { return nil }
        return rowsData.subdata(in: range)
    }
    
    /// Iterate over all row data.
    public func makeIterator() -> BsatnRowListIterator {
        BsatnRowListIterator(list: self)
    }
}

extension BsatnRowList: BSATNCodable {
    public func encode(to encoder: inout BSATNEncoder) throws {
        try sizeHint.encode(to: &encoder)
        try rowsData.encode(to: &encoder)
    }
    
    public init(from decoder: inout BSATNDecoder) throws {
        self.sizeHint = try RowSizeHint(from: &decoder)
        self.rowsData = try Data(from: &decoder)
    }
}

/// Iterator for BsatnRowList rows.
public struct BsatnRowListIterator: IteratorProtocol {
    private let list: BsatnRowList
    private var index: Int = 0
    
    init(list: BsatnRowList) {
        self.list = list
    }
    
    public mutating func next() -> Data? {
        guard let data = list.rowData(at: index) else { return nil }
        index += 1
        return data
    }
}

extension BsatnRowList: Sequence {
    public typealias Iterator = BsatnRowListIterator
}

// MARK: - QueryUpdate

/// Update data for a single query, containing deleted and inserted rows.
public struct QueryUpdate: Sendable {
    /// Rows deleted by this update.
    /// Empty for initial subscription data.
    public let deletes: BsatnRowList
    
    /// Rows inserted by this update.
    /// For initial subscriptions, contains all matching rows.
    public let inserts: BsatnRowList
    
    /// Create a query update.
    public init(deletes: BsatnRowList, inserts: BsatnRowList) {
        self.deletes = deletes
        self.inserts = inserts
    }
    
    /// Create an empty query update.
    public static var empty: QueryUpdate {
        QueryUpdate(deletes: .empty, inserts: .empty)
    }
    
    /// Total number of rows affected.
    public var totalRowCount: Int {
        deletes.count + inserts.count
    }
}

extension QueryUpdate: BSATNCodable {
    public func encode(to encoder: inout BSATNEncoder) throws {
        try deletes.encode(to: &encoder)
        try inserts.encode(to: &encoder)
    }
    
    public init(from decoder: inout BSATNDecoder) throws {
        self.deletes = try BsatnRowList(from: &decoder)
        self.inserts = try BsatnRowList(from: &decoder)
    }
}

// MARK: - CompressableQueryUpdate

/// A query update that may be compressed.
public enum CompressableQueryUpdate: Sendable {
    /// Uncompressed query update data.
    case uncompressed(QueryUpdate)
    
    /// Brotli-compressed query update data.
    case brotli(Data)
    
    /// Gzip-compressed query update data.
    case gzip(Data)
}

extension CompressableQueryUpdate: BSATNCodable {
    public func encode(to encoder: inout BSATNEncoder) throws {
        switch self {
        case .uncompressed(let update):
            encoder.encode(UInt8(0))
            try update.encode(to: &encoder)
        case .brotli(let data):
            encoder.encode(UInt8(1))
            try data.encode(to: &encoder)
        case .gzip(let data):
            encoder.encode(UInt8(2))
            try data.encode(to: &encoder)
        }
    }
    
    public init(from decoder: inout BSATNDecoder) throws {
        let tag = try decoder.decode(UInt8.self)
        switch tag {
        case 0:
            let update = try QueryUpdate(from: &decoder)
            self = .uncompressed(update)
        case 1:
            let data = try Data(from: &decoder)
            self = .brotli(data)
        case 2:
            let data = try Data(from: &decoder)
            self = .gzip(data)
        default:
            throw BSATNDecodingError.invalidEnumTag(tag: tag, typeName: "CompressableQueryUpdate")
        }
    }
}

// MARK: - TableUpdate

/// Update data for a single table within a database update.
public struct TableUpdate: Sendable {
    /// The ID of the table.
    /// Clients should prefer `tableName` as it's more stable.
    public let tableId: TableId
    
    /// The name of the table.
    public let tableName: String
    
    /// Total number of rows in this update.
    public let numRows: UInt64
    
    /// The actual update data, possibly from multiple queries.
    public let updates: [CompressableQueryUpdate]
    
    /// Create a table update.
    public init(tableId: TableId, tableName: String, numRows: UInt64, updates: [CompressableQueryUpdate]) {
        self.tableId = tableId
        self.tableName = tableName
        self.numRows = numRows
        self.updates = updates
    }
    
    /// Create an empty table update.
    public static func empty(tableId: TableId, tableName: String) -> TableUpdate {
        TableUpdate(tableId: tableId, tableName: tableName, numRows: 0, updates: [])
    }
}

extension TableUpdate: BSATNCodable {
    public func encode(to encoder: inout BSATNEncoder) throws {
        try tableId.encode(to: &encoder)
        try tableName.encode(to: &encoder)
        encoder.encode(numRows)
        try updates.encode(to: &encoder)
    }
    
    public init(from decoder: inout BSATNDecoder) throws {
        self.tableId = try TableId(from: &decoder)
        self.tableName = try String(from: &decoder)
        self.numRows = try decoder.decode(UInt64.self)
        self.updates = try [CompressableQueryUpdate](from: &decoder)
    }
}

// MARK: - DatabaseUpdate

/// A collection of table updates, contained in a TransactionUpdate or SubscriptionUpdate.
public struct DatabaseUpdate: Sendable {
    /// Updates for each affected table.
    public let tables: [TableUpdate]
    
    /// Create a database update.
    public init(tables: [TableUpdate]) {
        self.tables = tables
    }
    
    /// Create an empty database update.
    public static var empty: DatabaseUpdate {
        DatabaseUpdate(tables: [])
    }
    
    /// Whether this update is empty (no table updates).
    public var isEmpty: Bool {
        tables.isEmpty
    }
    
    /// Total number of rows across all table updates.
    public var totalRowCount: Int {
        tables.reduce(0) { $0 + Int($1.numRows) }
    }
}

extension DatabaseUpdate: BSATNCodable {
    public func encode(to encoder: inout BSATNEncoder) throws {
        try tables.encode(to: &encoder)
    }
    
    public init(from decoder: inout BSATNDecoder) throws {
        self.tables = try [TableUpdate](from: &decoder)
    }
}

// MARK: - SubscribeRows

/// The matching rows for a single-query subscription response.
public struct SubscribeRows: Sendable {
    /// The table ID.
    public let tableId: TableId
    
    /// The table name.
    public let tableName: String
    
    /// The row data for this table.
    public let tableRows: TableUpdate
    
    /// Create subscribe rows.
    public init(tableId: TableId, tableName: String, tableRows: TableUpdate) {
        self.tableId = tableId
        self.tableName = tableName
        self.tableRows = tableRows
    }
}

extension SubscribeRows: BSATNCodable {
    public func encode(to encoder: inout BSATNEncoder) throws {
        try tableId.encode(to: &encoder)
        try tableName.encode(to: &encoder)
        try tableRows.encode(to: &encoder)
    }
    
    public init(from decoder: inout BSATNDecoder) throws {
        self.tableId = try TableId(from: &decoder)
        self.tableName = try String(from: &decoder)
        self.tableRows = try TableUpdate(from: &decoder)
    }
}
