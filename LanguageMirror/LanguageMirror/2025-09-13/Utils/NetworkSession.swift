//
//  NetworkSession.swift
//  LanguageMirror
//
//  Created by Matthew Flood on 1/13/25.
//

import Foundation

/// Custom URLSession with extended timeouts for downloading large files and manifests
/// - Request timeout: 30 seconds (for debugging, will increase to 180s in production)
/// - Resource timeout: 60 seconds (for debugging, will increase to 900s in production)
final class NetworkSession {
    static let shared: URLSession = {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 30.0 // 30 seconds for debugging
        configuration.timeoutIntervalForResource = 60.0 // 60 seconds for debugging
        configuration.waitsForConnectivity = true
        return URLSession(configuration: configuration)
    }()
}

/// Delegate class to track download progress and log when bytes start arriving
private final class DownloadProgressDelegate: NSObject, URLSessionDownloadDelegate {
    private let logPrefix: String
    private let startTime: Date
    private var firstBytesReceived = false
    private var connectionEstablished = false
    
    init(logPrefix: String) {
        self.logPrefix = logPrefix
        self.startTime = Date()
        super.init()
    }
    
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        let elapsed = Date().timeIntervalSince(startTime)
        
        // Log when first bytes arrive
        if !firstBytesReceived {
            firstBytesReceived = true
            print("\(logPrefix) First bytes received after \(String(format: "%.3f", elapsed))s")
            print("\(logPrefix) Received \(bytesWritten) bytes, total so far: \(totalBytesWritten) bytes")
            if totalBytesExpectedToWrite > 0 {
                print("\(logPrefix) Expected total size: \(totalBytesExpectedToWrite) bytes")
            } else {
                print("\(logPrefix) Total size unknown (streaming)")
            }
        }
        
        // Log progress updates periodically
        if totalBytesExpectedToWrite > 0 {
            let progress = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
            // Log every 10% or if it's a small file, every chunk
            if totalBytesWritten % max(totalBytesExpectedToWrite / 10, 1024) < Int64(bytesWritten) || totalBytesWritten < 10240 {
                print("\(logPrefix) Progress: \(totalBytesWritten) / \(totalBytesExpectedToWrite) bytes (\(String(format: "%.1f", progress * 100))%)")
            }
        } else {
            // For streaming downloads, log every 10KB
            if totalBytesWritten % 10240 < bytesWritten {
                print("\(logPrefix) Progress: \(totalBytesWritten) bytes received")
            }
        }
    }
    
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        let elapsed = Date().timeIntervalSince(startTime)
        print("\(logPrefix) Download finished after \(String(format: "%.3f", elapsed))s")
        
        // Get file size if possible
        if let attributes = try? FileManager.default.attributesOfItem(atPath: location.path),
           let fileSize = attributes[.size] as? Int64 {
            print("\(logPrefix) Final file size: \(fileSize) bytes")
        }
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        let elapsed = Date().timeIntervalSince(startTime)
        if let error = error {
            print("\(logPrefix) Download task completed with error after \(String(format: "%.3f", elapsed))s: \(error)")
        } else {
            print("\(logPrefix) Download task completed successfully after \(String(format: "%.3f", elapsed))s")
        }
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didReceive response: URLResponse, completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        let elapsed = Date().timeIntervalSince(startTime)
        if !connectionEstablished {
            connectionEstablished = true
            print("\(logPrefix) Connection established after \(String(format: "%.3f", elapsed))s")
            
            if let httpResponse = response as? HTTPURLResponse {
                print("\(logPrefix) HTTP status: \(httpResponse.statusCode)")
                if let contentLength = httpResponse.value(forHTTPHeaderField: "Content-Length"),
                   let length = Int64(contentLength) {
                    print("\(logPrefix) Content-Length header: \(length) bytes")
                }
            }
        }
        completionHandler(.allow)
    }
}

extension URLSession {
    /// Download a file with detailed progress logging
    /// - Parameters:
    ///   - url: The URL to download from
    ///   - logPrefix: Prefix for log messages (e.g., "[BundleManifestDriver]")
    /// - Returns: A tuple of (temporary file URL, response)
    func downloadWithProgress(from url: URL, logPrefix: String) async throws -> (URL, URLResponse) {
        print("\(logPrefix) Starting download from: \(url.absoluteString)")
        let startTime = Date()
        
        let delegate = DownloadProgressDelegate(logPrefix: logPrefix)
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 30.0
        configuration.timeoutIntervalForResource = 60.0
        configuration.waitsForConnectivity = true
        
        // Create a session with the delegate
        let session = URLSession(configuration: configuration, delegate: delegate, delegateQueue: nil)
        
        // Use continuation to bridge delegate-based API to async/await
        // Keep session reference alive by storing it in the continuation closure
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<(URL, URLResponse), Error>) in
            let task = session.downloadTask(with: url) { tempURL, response, error in
                // Finish tasks and invalidate session to release delegate and avoid memory leaks
                // This allows any pending delegate callbacks to complete before invalidating
                session.finishTasksAndInvalidate()
                
                if let error = error {
                    let elapsed = Date().timeIntervalSince(startTime)
                    print("\(logPrefix) Download failed after \(String(format: "%.3f", elapsed))s: \(error)")
                    continuation.resume(throwing: error)
                    return
                }
                
                guard let tempURL = tempURL, let response = response else {
                    let elapsed = Date().timeIntervalSince(startTime)
                    print("\(logPrefix) Download completed but tempURL or response is nil after \(String(format: "%.3f", elapsed))s")
                    continuation.resume(throwing: URLError(.badServerResponse))
                    return
                }
                
                let elapsed = Date().timeIntervalSince(startTime)
                print("\(logPrefix) Download completed successfully after \(String(format: "%.3f", elapsed))s")
                continuation.resume(returning: (tempURL, response))
            }
            
            task.resume()
        }
    }
}
