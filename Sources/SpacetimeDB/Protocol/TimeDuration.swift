//
//  TimeDuration.swift
//  SpacetimeDB
//
//  Duration type for host execution times.
//  Distinct from TimeDelta which uses microseconds.
//

import Foundation

// MARK: - TimeDuration

/// A duration measured in nanoseconds, used for host execution times.
///
/// This is distinct from `TimeDelta` which uses microseconds.
/// SpacetimeDB uses `TimeDuration` for measuring reducer execution times
/// and other host-side durations.
public struct TimeDuration: Hashable, Sendable {
    /// The duration in nanoseconds.
    public let nanoseconds: Int64
    
    /// Create a duration from nanoseconds.
    public init(nanoseconds: Int64) {
        self.nanoseconds = nanoseconds
    }
    
    /// Create a duration from microseconds.
    public init(microseconds: Int64) {
        self.nanoseconds = microseconds * 1_000
    }
    
    /// Create a duration from milliseconds.
    public init(milliseconds: Int64) {
        self.nanoseconds = milliseconds * 1_000_000
    }
    
    /// Create a duration from seconds.
    public init(seconds: Double) {
        self.nanoseconds = Int64(seconds * 1_000_000_000)
    }
    
    /// Zero duration.
    public static var zero: TimeDuration {
        TimeDuration(nanoseconds: 0)
    }
    
    /// Get the duration in microseconds.
    public var microseconds: Int64 {
        nanoseconds / 1_000
    }
    
    /// Get the duration in milliseconds.
    public var milliseconds: Int64 {
        nanoseconds / 1_000_000
    }
    
    /// Get the duration in seconds.
    public var seconds: Double {
        Double(nanoseconds) / 1_000_000_000
    }
    
    /// Convert to Foundation TimeInterval (seconds).
    public var timeInterval: TimeInterval {
        seconds
    }
}

// MARK: - BSATN

extension TimeDuration: BSATNCodable {
    public func encode(to encoder: inout BSATNEncoder) throws {
        encoder.encode(nanoseconds)
    }
    
    public init(from decoder: inout BSATNDecoder) throws {
        self.nanoseconds = try decoder.decode(Int64.self)
    }
}

// MARK: - Comparable

extension TimeDuration: Comparable {
    public static func < (lhs: TimeDuration, rhs: TimeDuration) -> Bool {
        lhs.nanoseconds < rhs.nanoseconds
    }
}

// MARK: - CustomStringConvertible

extension TimeDuration: CustomStringConvertible {
    public var description: String {
        if nanoseconds < 1_000 {
            return "\(nanoseconds)ns"
        } else if nanoseconds < 1_000_000 {
            return String(format: "%.2fµs", Double(nanoseconds) / 1_000)
        } else if nanoseconds < 1_000_000_000 {
            return String(format: "%.2fms", Double(nanoseconds) / 1_000_000)
        } else {
            return String(format: "%.3fs", Double(nanoseconds) / 1_000_000_000)
        }
    }
}

// MARK: - Arithmetic

extension TimeDuration {
    public static func + (lhs: TimeDuration, rhs: TimeDuration) -> TimeDuration {
        TimeDuration(nanoseconds: lhs.nanoseconds + rhs.nanoseconds)
    }
    
    public static func - (lhs: TimeDuration, rhs: TimeDuration) -> TimeDuration {
        TimeDuration(nanoseconds: lhs.nanoseconds - rhs.nanoseconds)
    }
}
