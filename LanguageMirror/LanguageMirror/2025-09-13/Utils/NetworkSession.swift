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
