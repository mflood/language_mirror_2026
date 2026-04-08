//
//  AudioSourceResolver.swift
//  LanguageMirror
//
//  Abstraction over "where do this BundleTrack's audio bytes come from".
//  Two implementations exist:
//   - RemoteAudioSourceResolver: downloads from a public URL (CloudFront, etc.)
//   - AppBundleAudioSourceResolver: looks up the file in the app's resources
//
//  This lets ImportBundleManifestDriver share its per-track import loop
//  between remote bundles (QR / URL) and app-embedded bundles.
//

import Foundation

/// Result of resolving a BundleTrack to a local file. The caller is responsible
/// for cleaning up `tempURL` if `isTemporary` is true.
struct ResolvedAudio {
    let url: URL
    let suggestedFilename: String
    let isTemporary: Bool
}

protocol AudioSourceResolver {
    /// Resolve a BundleTrack to a local file URL the import driver can copy from.
    func resolve(track: BundleTrack) async throws -> ResolvedAudio
}

// MARK: - Remote (HTTPS download)

struct RemoteAudioSourceResolver: AudioSourceResolver {
    let urlDownloader: UrlDownloaderProtocol

    func resolve(track: BundleTrack) async throws -> ResolvedAudio {
        guard let urlString = track.url, let url = URL(string: urlString) else {
            throw BundleManifestError.invalidManifestURL("Track '\(track.title)' is missing a valid url")
        }
        guard let scheme = url.scheme?.lowercased(), scheme == "http" || scheme == "https" else {
            throw BundleManifestError.invalidManifestURL("Track '\(track.title)' has unsupported url scheme: \(url.scheme ?? "none")")
        }
        let (tempURL, suggestedFilename) = try await urlDownloader.downloadAudio(from: url)
        return ResolvedAudio(url: tempURL, suggestedFilename: suggestedFilename, isTemporary: true)
    }
}

// MARK: - App bundle (file in Resources)

/// Looks up audio files in the app's main bundle by their (already-prefixed)
/// filename. Xcode 16 Synchronized File System Groups flatten arbitrary
/// nested folders at build time (only `lproj` directories are preserved),
/// so we expect bundle assets to be globally unique by filename — typically
/// achieved by prefixing with the bundle id (see sample_bundle_pipeline/4_embed_in_app.py).
struct AppBundleAudioSourceResolver: AudioSourceResolver {
    func resolve(track: BundleTrack) async throws -> ResolvedAudio {
        // For embedded bundles we expect `filename` to be set (and `url` to be nil).
        let lookupName: String
        if let f = track.filename, !f.isEmpty {
            lookupName = f
        } else if let u = track.url, !u.isEmpty {
            lookupName = (u as NSString).lastPathComponent
        } else {
            throw BundleManifestError.invalidManifestURL("Track '\(track.title)' has no filename or url")
        }

        let baseName = (lookupName as NSString).deletingPathExtension
        var ext = (lookupName as NSString).pathExtension
        if ext.isEmpty { ext = "mp3" }

        guard let url = Bundle.main.url(forResource: baseName, withExtension: ext) else {
            throw BundleManifestError.invalidManifestURL("Embedded audio not found: \(lookupName)")
        }
        return ResolvedAudio(url: url, suggestedFilename: lookupName, isTemporary: false)
    }
}
