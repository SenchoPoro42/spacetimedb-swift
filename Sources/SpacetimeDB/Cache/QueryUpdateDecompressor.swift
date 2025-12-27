//
//  QueryUpdateDecompressor.swift
//  SpacetimeDB
//
//  Decompression utilities for CompressableQueryUpdate data.
//

import Foundation
import Compression

// MARK: - QueryUpdateDecompressor

/// Handles decompression of `CompressableQueryUpdate` data.
///
/// Query updates from the server may be compressed using Brotli or Gzip
/// to reduce bandwidth. This struct provides utilities to decompress
/// them back to `QueryUpdate` form.
public struct QueryUpdateDecompressor {
    
    private init() {}
    
    /// Decompress a `CompressableQueryUpdate` to a `QueryUpdate`.
    ///
    /// - Parameter compressable: The possibly-compressed query update.
    /// - Returns: The decompressed `QueryUpdate`.
    /// - Throws: `QueryUpdateDecompressionError` if decompression fails.
    public static func decompress(_ compressable: CompressableQueryUpdate) throws -> QueryUpdate {
        switch compressable {
        case .uncompressed(let update):
            return update
            
        case .brotli(let compressedData):
            let decompressed = try decompressData(compressedData, algorithm: COMPRESSION_BROTLI)
            return try decodeQueryUpdate(from: decompressed)
            
        case .gzip(let compressedData):
            let decompressed = try decompressData(compressedData, algorithm: COMPRESSION_ZLIB)
            return try decodeQueryUpdate(from: decompressed)
        }
    }
    
    /// Decompress data using the specified algorithm.
    private static func decompressData(_ data: Data, algorithm: compression_algorithm) throws -> Data {
        guard !data.isEmpty else {
            return Data()
        }
        
        // Start with a reasonable buffer size (4x compressed size)
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
                nil,
                algorithm
            )
        }
        
        // If buffer was too small, try with larger buffer
        if decompressedSize == 0 || decompressedSize == destinationBuffer.count {
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
                let algorithmName = algorithm == COMPRESSION_BROTLI ? "brotli" : "gzip"
                throw QueryUpdateDecompressionError.decompressionFailed(algorithm: algorithmName)
            }
            
            return Data(destinationBuffer.prefix(retrySize))
        }
        
        return Data(destinationBuffer.prefix(decompressedSize))
    }
    
    /// Decode a QueryUpdate from decompressed data.
    private static func decodeQueryUpdate(from data: Data) throws -> QueryUpdate {
        var decoder = BSATNDecoder(data: data)
        do {
            return try QueryUpdate(from: &decoder)
        } catch {
            throw QueryUpdateDecompressionError.decodingFailed(underlying: error)
        }
    }
}

// MARK: - QueryUpdateDecompressionError

/// Errors that can occur during query update decompression.
public enum QueryUpdateDecompressionError: Error, Sendable {
    /// Decompression failed for the specified algorithm.
    case decompressionFailed(algorithm: String)
    
    /// BSATN decoding failed after decompression.
    case decodingFailed(underlying: Error)
}

extension QueryUpdateDecompressionError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .decompressionFailed(let algorithm):
            return "Query update decompression failed for algorithm: \(algorithm)"
        case .decodingFailed(let error):
            return "Query update decoding failed: \(error.localizedDescription)"
        }
    }
}

// MARK: - CompressableQueryUpdate Extension

extension CompressableQueryUpdate {
    /// Decompress this query update.
    ///
    /// - Returns: The decompressed `QueryUpdate`.
    /// - Throws: `QueryUpdateDecompressionError` if decompression fails.
    public func decompress() throws -> QueryUpdate {
        try QueryUpdateDecompressor.decompress(self)
    }
    
    /// Whether this update is compressed.
    public var isCompressed: Bool {
        switch self {
        case .uncompressed:
            return false
        case .brotli, .gzip:
            return true
        }
    }
    
    /// The compression type, if compressed.
    public var compressionType: CompressionType? {
        switch self {
        case .uncompressed:
            return nil
        case .brotli:
            return .brotli
        case .gzip:
            return .gzip
        }
    }
}
