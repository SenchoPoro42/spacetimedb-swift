//
//  RowCallbacks.swift
//  SpacetimeDB
//
//  Callback infrastructure for observing row changes in the client cache.
//

import Foundation

// MARK: - RowOperation

/// The type of operation performed on a row.
public enum RowOperation: Sendable {
    /// A new row was inserted into the cache.
    case insert(Data)
    
    /// A row was deleted from the cache.
    case delete(Data)
    
    /// A row was updated (delete + insert with same primary key).
    case update(old: Data, new: Data)
}

extension RowOperation {
    /// The row data involved in this operation.
    ///
    /// For updates, returns the new row data.
    public var rowData: Data {
        switch self {
        case .insert(let data):
            return data
        case .delete(let data):
            return data
        case .update(_, let new):
            return new
        }
    }
    
    /// Whether this is an insert operation.
    public var isInsert: Bool {
        if case .insert = self { return true }
        return false
    }
    
    /// Whether this is a delete operation.
    public var isDelete: Bool {
        if case .delete = self { return true }
        return false
    }
    
    /// Whether this is an update operation.
    public var isUpdate: Bool {
        if case .update = self { return true }
        return false
    }
}

// MARK: - CallbackHandle

/// A handle for managing registered callbacks.
///
/// Use this to unregister a callback when it's no longer needed.
public struct CallbackHandle: Hashable, Sendable {
    /// Unique identifier for this callback registration.
    public let id: UUID
    
    /// The table name this callback is registered for, if table-specific.
    public let tableName: String?
    
    /// Create a new callback handle.
    internal init(id: UUID = UUID(), tableName: String? = nil) {
        self.id = id
        self.tableName = tableName
    }
}

// MARK: - Callback Type Aliases

/// Callback invoked when a row changes.
///
/// - Parameters:
///   - tableName: The name of the table that changed.
///   - operation: The operation that occurred.
public typealias RowChangeCallback = @Sendable (String, RowOperation) -> Void

/// Callback invoked for row inserts.
///
/// - Parameters:
///   - tableName: The name of the table.
///   - rowData: The BSATN-encoded row data that was inserted.
public typealias RowInsertCallback = @Sendable (String, Data) -> Void

/// Callback invoked for row deletes.
///
/// - Parameters:
///   - tableName: The name of the table.
///   - rowData: The BSATN-encoded row data that was deleted.
public typealias RowDeleteCallback = @Sendable (String, Data) -> Void

// MARK: - CallbackRegistry

/// Registry for managing row change callbacks.
///
/// This class is not thread-safe on its own and should be accessed
/// through the `ClientCache` actor.
public final class CallbackRegistry: @unchecked Sendable {
    
    // MARK: - Storage
    
    /// Global callbacks for any table change.
    private var globalCallbacks: [UUID: RowChangeCallback] = [:]
    
    /// Per-table insert callbacks.
    private var insertCallbacks: [String: [UUID: RowInsertCallback]] = [:]
    
    /// Per-table delete callbacks.
    private var deleteCallbacks: [String: [UUID: RowDeleteCallback]] = [:]
    
    /// Per-table change callbacks (all operations).
    private var tableCallbacks: [String: [UUID: RowChangeCallback]] = [:]
    
    // MARK: - Initialization
    
    public init() {}
    
    // MARK: - Registration
    
    /// Register a callback for any row change in any table.
    ///
    /// - Parameter callback: The callback to invoke.
    /// - Returns: A handle to unregister the callback.
    @discardableResult
    public func onAnyChange(_ callback: @escaping RowChangeCallback) -> CallbackHandle {
        let handle = CallbackHandle()
        globalCallbacks[handle.id] = callback
        return handle
    }
    
    /// Register a callback for row inserts in a specific table.
    ///
    /// - Parameters:
    ///   - tableName: The table to observe.
    ///   - callback: The callback to invoke.
    /// - Returns: A handle to unregister the callback.
    @discardableResult
    public func onInsert(tableName: String, _ callback: @escaping RowInsertCallback) -> CallbackHandle {
        let handle = CallbackHandle(tableName: tableName)
        insertCallbacks[tableName, default: [:]][handle.id] = callback
        return handle
    }
    
    /// Register a callback for row deletes in a specific table.
    ///
    /// - Parameters:
    ///   - tableName: The table to observe.
    ///   - callback: The callback to invoke.
    /// - Returns: A handle to unregister the callback.
    @discardableResult
    public func onDelete(tableName: String, _ callback: @escaping RowDeleteCallback) -> CallbackHandle {
        let handle = CallbackHandle(tableName: tableName)
        deleteCallbacks[tableName, default: [:]][handle.id] = callback
        return handle
    }
    
    /// Register a callback for any change in a specific table.
    ///
    /// - Parameters:
    ///   - tableName: The table to observe.
    ///   - callback: The callback to invoke.
    /// - Returns: A handle to unregister the callback.
    @discardableResult
    public func onChange(tableName: String, _ callback: @escaping RowChangeCallback) -> CallbackHandle {
        let handle = CallbackHandle(tableName: tableName)
        tableCallbacks[tableName, default: [:]][handle.id] = callback
        return handle
    }
    
    /// Remove a callback registration.
    ///
    /// - Parameter handle: The handle returned when registering.
    /// - Returns: True if the callback was found and removed.
    @discardableResult
    public func remove(_ handle: CallbackHandle) -> Bool {
        // Try global callbacks
        if globalCallbacks.removeValue(forKey: handle.id) != nil {
            return true
        }
        
        // Try table-specific callbacks
        if let tableName = handle.tableName {
            if insertCallbacks[tableName]?.removeValue(forKey: handle.id) != nil {
                return true
            }
            if deleteCallbacks[tableName]?.removeValue(forKey: handle.id) != nil {
                return true
            }
            if tableCallbacks[tableName]?.removeValue(forKey: handle.id) != nil {
                return true
            }
        }
        
        return false
    }
    
    /// Remove all callbacks.
    public func removeAll() {
        globalCallbacks.removeAll()
        insertCallbacks.removeAll()
        deleteCallbacks.removeAll()
        tableCallbacks.removeAll()
    }
    
    // MARK: - Notification
    
    /// Notify all relevant callbacks of a row insert.
    ///
    /// - Parameters:
    ///   - tableName: The table that changed.
    ///   - rowData: The inserted row data.
    public func notifyInsert(tableName: String, rowData: Data) {
        let operation = RowOperation.insert(rowData)
        
        // Fire table-specific insert callbacks
        if let callbacks = insertCallbacks[tableName] {
            for callback in callbacks.values {
                callback(tableName, rowData)
            }
        }
        
        // Fire table-specific change callbacks
        if let callbacks = tableCallbacks[tableName] {
            for callback in callbacks.values {
                callback(tableName, operation)
            }
        }
        
        // Fire global callbacks
        for callback in globalCallbacks.values {
            callback(tableName, operation)
        }
    }
    
    /// Notify all relevant callbacks of a row delete.
    ///
    /// - Parameters:
    ///   - tableName: The table that changed.
    ///   - rowData: The deleted row data.
    public func notifyDelete(tableName: String, rowData: Data) {
        let operation = RowOperation.delete(rowData)
        
        // Fire table-specific delete callbacks
        if let callbacks = deleteCallbacks[tableName] {
            for callback in callbacks.values {
                callback(tableName, rowData)
            }
        }
        
        // Fire table-specific change callbacks
        if let callbacks = tableCallbacks[tableName] {
            for callback in callbacks.values {
                callback(tableName, operation)
            }
        }
        
        // Fire global callbacks
        for callback in globalCallbacks.values {
            callback(tableName, operation)
        }
    }
    
    /// Notify all relevant callbacks of a row update.
    ///
    /// - Parameters:
    ///   - tableName: The table that changed.
    ///   - oldData: The old row data.
    ///   - newData: The new row data.
    public func notifyUpdate(tableName: String, oldData: Data, newData: Data) {
        let operation = RowOperation.update(old: oldData, new: newData)
        
        // For updates, fire both insert and delete callbacks for backward compatibility
        if let callbacks = deleteCallbacks[tableName] {
            for callback in callbacks.values {
                callback(tableName, oldData)
            }
        }
        
        if let callbacks = insertCallbacks[tableName] {
            for callback in callbacks.values {
                callback(tableName, newData)
            }
        }
        
        // Fire table-specific change callbacks
        if let callbacks = tableCallbacks[tableName] {
            for callback in callbacks.values {
                callback(tableName, operation)
            }
        }
        
        // Fire global callbacks
        for callback in globalCallbacks.values {
            callback(tableName, operation)
        }
    }
}
