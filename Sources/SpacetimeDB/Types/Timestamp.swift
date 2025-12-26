//
//  Timestamp.swift
//  SpacetimeDB
//
//  SpacetimeDB timestamp types.
//

import Foundation

/// A point in time, measured in microseconds since the Unix epoch.
///
/// SpacetimeDB uses microsecond precision for timestamps.
public struct Timestamp: Hashable, Sendable {
    /// Microseconds since Unix epoch (January 1, 1970 00:00:00 UTC).
    public var microseconds: UInt64
    
    /// Create a timestamp from microseconds since Unix epoch.
    public init(microseconds: UInt64) {
        self.microseconds = microseconds
    }
    
    /// Create a timestamp from a Date.
    public init(_ date: Date) {
        self.microseconds = UInt64(date.timeIntervalSince1970 * 1_000_000)
    }
    
    /// Create a timestamp for the current time.
    public static var now: Timestamp {
        Timestamp(Date())
    }
    
    /// The Unix epoch (January 1, 1970 00:00:00 UTC).
    public static var epoch: Timestamp {
        Timestamp(microseconds: 0)
    }
    
    /// Convert to a Date.
    public func toDate() -> Date {
        Date(timeIntervalSince1970: Double(microseconds) / 1_000_000)
    }
    
    /// Seconds since Unix epoch (with microsecond precision).
    public var secondsSinceEpoch: Double {
        Double(microseconds) / 1_000_000
    }
    
    /// Milliseconds since Unix epoch.
    public var milliseconds: UInt64 {
        microseconds / 1_000
    }
}

// MARK: - BSATN

extension Timestamp: BSATNCodable {
    public func encode(to encoder: inout BSATNEncoder) throws {
        encoder.encode(microseconds)
    }
    
    public init(from decoder: inout BSATNDecoder) throws {
        self.microseconds = try decoder.decode(UInt64.self)
    }
}

// MARK: - Comparable

extension Timestamp: Comparable {
    public static func < (lhs: Timestamp, rhs: Timestamp) -> Bool {
        lhs.microseconds < rhs.microseconds
    }
}

// MARK: - CustomStringConvertible

extension Timestamp: CustomStringConvertible {
    public var description: String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: toDate())
    }
}

// MARK: - Codable (JSON)

extension Timestamp: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        self.microseconds = try container.decode(UInt64.self)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(microseconds)
    }
}

// MARK: - TimeDelta

/// A span or delta in time, measured in microseconds.
///
/// Can be positive (future) or negative (past).
public struct TimeDelta: Hashable, Sendable {
    /// The duration in microseconds. Negative values represent past time.
    public var microseconds: Int64
    
    /// Create a time delta from microseconds.
    public init(microseconds: Int64) {
        self.microseconds = microseconds
    }
    
    /// Create a time delta from seconds.
    public init(seconds: Double) {
        self.microseconds = Int64(seconds * 1_000_000)
    }
    
    /// Zero duration.
    public static var zero: TimeDelta {
        TimeDelta(microseconds: 0)
    }
    
    /// Create a time delta representing the given number of seconds.
    public static func seconds(_ value: Double) -> TimeDelta {
        TimeDelta(seconds: value)
    }
    
    /// Create a time delta representing the given number of milliseconds.
    public static func milliseconds(_ value: Int64) -> TimeDelta {
        TimeDelta(microseconds: value * 1_000)
    }
    
    /// Create a time delta representing the given number of minutes.
    public static func minutes(_ value: Double) -> TimeDelta {
        TimeDelta(seconds: value * 60)
    }
    
    /// Create a time delta representing the given number of hours.
    public static func hours(_ value: Double) -> TimeDelta {
        TimeDelta(seconds: value * 3600)
    }
    
    /// Get the duration in seconds.
    public var seconds: Double {
        Double(microseconds) / 1_000_000
    }
    
    /// Get the absolute duration in microseconds.
    public var absoluteMicroseconds: UInt64 {
        UInt64(abs(microseconds))
    }
}

// MARK: - TimeDelta BSATN

extension TimeDelta: BSATNCodable {
    public func encode(to encoder: inout BSATNEncoder) throws {
        encoder.encode(microseconds)
    }
    
    public init(from decoder: inout BSATNDecoder) throws {
        self.microseconds = try decoder.decode(Int64.self)
    }
}

// MARK: - TimeDelta Comparable

extension TimeDelta: Comparable {
    public static func < (lhs: TimeDelta, rhs: TimeDelta) -> Bool {
        lhs.microseconds < rhs.microseconds
    }
}

// MARK: - Timestamp + TimeDelta Arithmetic

extension Timestamp {
    public static func + (lhs: Timestamp, rhs: TimeDelta) -> Timestamp {
        if rhs.microseconds >= 0 {
            return Timestamp(microseconds: lhs.microseconds + UInt64(rhs.microseconds))
        } else {
            let delta = UInt64(abs(rhs.microseconds))
            return Timestamp(microseconds: lhs.microseconds > delta ? lhs.microseconds - delta : 0)
        }
    }
    
    public static func - (lhs: Timestamp, rhs: TimeDelta) -> Timestamp {
        lhs + TimeDelta(microseconds: -rhs.microseconds)
    }
    
    public static func - (lhs: Timestamp, rhs: Timestamp) -> TimeDelta {
        TimeDelta(microseconds: Int64(lhs.microseconds) - Int64(rhs.microseconds))
    }
}
