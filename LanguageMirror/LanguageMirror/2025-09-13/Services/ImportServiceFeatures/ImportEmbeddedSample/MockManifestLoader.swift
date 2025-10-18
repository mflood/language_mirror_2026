//
//  MockManifestLoader.swift
//  LanguageMirror
//
//  Created by Matthew Flood on 9/20/25.
//

// Features/ImportingSample/MockManifestLoader.swift
import Foundation

final class MockManifestLoader: EmbeddedBundleManifestLoader {

    enum ErrorMode: Sendable {
        case none
        case immediate(Error)
        case afterDelay(Error)
    }

    private let totalDuration: TimeInterval
    private let step: TimeInterval
    private let errorMode: ErrorMode

    init(totalDuration: TimeInterval = 0,
                step: TimeInterval = 0.2,
                errorMode: ErrorMode = .none) {
        self.totalDuration = max(0, totalDuration)
        self.step = max(0.01, step)
        self.errorMode = errorMode
    }

    func loadAvailablePacks() async throws -> [EmbeddedPackMetadata] {
        switch errorMode {
        case .immediate(let e): throw e
        case .none, .afterDelay: break
        }
        
        if totalDuration > 0 {
            var elapsed: TimeInterval = 0
            while elapsed < totalDuration {
                try Task.checkCancellation()
                let chunk = min(step, totalDuration - elapsed)
                try await Task.sleep(nanoseconds: UInt64(chunk * 1_000_000_000))
                elapsed += chunk
            }
        }
        
        if case .afterDelay(let e) = errorMode { throw e }
        
        // Return mock pack metadata
        return [
            EmbeddedPackMetadata(
                id: "mock-pack-1",
                title: "Mock Pack 1",
                description: "A test pack",
                filename: "mock_pack_1.json",
                trackCount: 5,
                languageCode: "ko"
            )
        ]
    }
    
    func loadPack(packId: String) async throws -> EmbeddedBundlePack {
        switch errorMode {
        case .immediate(let e): throw e
        case .none, .afterDelay: break
        }
        
        if totalDuration > 0 {
            var elapsed: TimeInterval = 0
            while elapsed < totalDuration {
                try Task.checkCancellation()
                let chunk = min(step, totalDuration - elapsed)
                try await Task.sleep(nanoseconds: UInt64(chunk * 1_000_000_000))
                elapsed += chunk
            }
        }
        
        if case .afterDelay(let e) = errorMode { throw e }
        
        // Return mock pack
        return EmbeddedBundlePack(
            id: packId,
            title: "Mock Pack",
            author: "Mock Author",
            filename: nil,
            audioSubdirectory: nil,
            tracks: []
        )
    }
    
    public func loadEmbeddedSample() async throws -> EmbeddedBundleManifest {
        switch errorMode {
        case .immediate(let e): throw e
        case .none, .afterDelay: break
        }

        let embeddedBundleManfiest = EmbeddedBundleManifest(
            title: "Sample Audio",
            packs: []
        )
        
        if totalDuration > 0 {
            var elapsed: TimeInterval = 0
            while elapsed < totalDuration {
                try Task.checkCancellation()
                let chunk = min(step, totalDuration - elapsed)
                try await Task.sleep(nanoseconds: UInt64(chunk * 1_000_000_000))
                elapsed += chunk
            }
        }

        if case .afterDelay(let e) = errorMode { throw e }

        return embeddedBundleManfiest
    }
}
