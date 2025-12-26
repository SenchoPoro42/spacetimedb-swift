//
//  Compression.swift
//  SpacetimeDB
//
//  Compression utilities for handling server message decompression.
//

import Foundation
import Compression

// MARK: - Compression Type

/// Compression algorithm used for server messages.
///
/// SpacetimeDB servers may compress large messages using Brotli or Gzip.
/// The compression type is indicated by the first byte of the message.
public enum CompressionType: UInt8, Sendable {
    /// No compression (tag 0).
    case none = 0
    
    /// Brotli compression (tag 1).
    case brotli = 1
    
    /// Gzip compression (tag 2).
    case gzip = 2
    
    /// Initialize from a raw tag byte.
    public init?(tag: UInt8) {
        self.init(rawValue: tag)
    }
}

// MARK: - Decompression

/// Errors that can occur during decompression.
public enum DecompressionError: Error, Sendable {
    /// The compression tag byte is not recognized.
    case unknownCompressionTag(UInt8)
    
    /// Decompression failed.
    case decompressionFailed(algorithm: CompressionType)
    
    /// The input data is empty or too short.
    case insufficientData
}

extension DecompressionError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .unknownCompressionTag(let tag):
            return "Unknown compression tag: \(tag)"
        case .decompressionFailed(let algorithm):
            return "Decompression failed for algorithm: \(algorithm)"
        case .insufficientData:
            return "Insufficient data for decompression"
        }
    }
}

/// Decompress server message data.
///
/// Server messages from SpacetimeDB are prefixed with a compression tag byte:
/// - 0: No compression
/// - 1: Brotli compression
/// - 2: Gzip compression
///
/// - Parameter data: The raw message data including the compression tag.
/// - Returns: The decompressed message data (without the tag byte).
/// - Throws: `DecompressionError` if decompression fails.
public func decompressServerMessage(_ data: Data) throws -> Data {
    guard !data.isEmpty else {
        throw DecompressionError.insufficientData
    }
    
    let tag = data[data.startIndex]
    guard let compressionType = CompressionType(tag: tag) else {
        throw DecompressionError.unknownCompressionTag(tag)
    }
    
    let payload = data.dropFirst()
    
    switch compressionType {
    case .none:
        return Data(payload)
        
    case .brotli:
        return try decompress(Data(payload), algorithm: COMPRESSION_BROTLI)
        
    case .gzip:
        // Gzip uses raw deflate for the data portion
        return try decompress(Data(payload), algorithm: COMPRESSION_ZLIB)
    }
}

/// Decompress data using the specified algorithm.
///
/// - Parameters:
///   - data: The compressed data.
///   - algorithm: The compression algorithm to use.
/// - Returns: The decompressed data.
/// - Throws: `DecompressionError.decompressionFailed` if decompression fails.
private func decompress(_ data: Data, algorithm: compression_algorithm) throws -> Data {
    guard !data.isEmpty else {
        return Data()
    }
    
    // Start with a reasonable buffer size (4x compressed size is a good heuristic)
    var destinationBuffer = [UInt8](repeating: 0, count: data.count * 4)
    
    let decompressedSize = data.withUnsafeBytes { sourceBuffer -> Int in
        guard let sourcePointer = sourceBuffer.baseAddress?.assumingMemoryBound(to: UInt8.self) else {
            return 0
        }
        
        return compression_decode_buffer(
            &destinationBuffer,
            destinationBuffer.count,
            sourcePointer,
            data.count,
            nil,  // scratch buffer (nil = allocate internally)
            algorithm
        )
    }
    
    // If decompression failed or buffer was too small, try with larger buffer
    if decompressedSize == 0 || decompressedSize == destinationBuffer.count {
        // Try with a much larger buffer
        destinationBuffer = [UInt8](repeating: 0, count: data.count * 64)
        
        let retrySize = data.withUnsafeBytes { sourceBuffer -> Int in
            guard let sourcePointer = sourceBuffer.baseAddress?.assumingMemoryBound(to: UInt8.self) else {
                return 0
            }
            
            return compression_decode_buffer(
                &destinationBuffer,
                destinationBuffer.count,
                sourcePointer,
                data.count,
                nil,
                algorithm
            )
        }
        
        if retrySize == 0 {
            let type: CompressionType = algorithm == COMPRESSION_BROTLI ? .brotli : .gzip
            throw DecompressionError.decompressionFailed(algorithm: type)
        }
        
        return Data(destinationBuffer.prefix(retrySize))
    }
    
    return Data(destinationBuffer.prefix(decompressedSize))
}

// MARK: - Testing Helpers

/// Compress data using the specified algorithm (for testing purposes).
///
/// - Parameters:
///   - data: The data to compress.
///   - type: The compression type to use.
/// - Returns: The compressed data with the compression tag prefix.
internal func compressForTesting(_ data: Data, type: CompressionType) -> Data? {
    switch type {
    case .none:
        return Data([type.rawValue]) + data
        
    case .brotli:
        guard let compressed = compress(data, algorithm: COMPRESSION_BROTLI) else {
            return nil
        }
        return Data([type.rawValue]) + compressed
        
    case .gzip:
        guard let compressed = compress(data, algorithm: COMPRESSION_ZLIB) else {
            return nil
        }
        return Data([type.rawValue]) + compressed
    }
}

/// Compress data using the specified algorithm.
private func compress(_ data: Data, algorithm: compression_algorithm) -> Data? {
    guard !data.isEmpty else {
        return Data()
    }
    
    var destinationBuffer = [UInt8](repeating: 0, count: data.count + 64)
    
    let compressedSize = data.withUnsafeBytes { sourceBuffer -> Int in
        guard let sourcePointer = sourceBuffer.baseAddress?.assumingMemoryBound(to: UInt8.self) else {
            return 0
        }
        
        return compression_encode_buffer(
            &destinationBuffer,
            destinationBuffer.count,
            sourcePointer,
            data.count,
            nil,
            algorithm
        )
    }
    
    guard compressedSize > 0 else {
        return nil
    }
    
    return Data(destinationBuffer.prefix(compressedSize))
}
