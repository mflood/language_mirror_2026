//
//  FeaturedCatalogService.swift
//  LanguageMirror
//
//  Loads the Featured Packs catalog. The catalog ships inside the app as
//  `featured_catalog.json` and lists both app-embedded bundles and remote
//  (CloudFront-hosted) bundles. From the user's perspective they're a single
//  cohesive list of packs they can install.
//
//  Lookup order on each call:
//    1. Try the remote URL (short timeout). If success and version is at
//       least the cached version, persist to Caches/ and return it.
//    2. Else try the cached copy in Caches/.
//    3. Else fall back to the embedded JSON in the app bundle.
//
//  This means new packs can be published by uploading a new
//  featured_catalog.json to S3 — no app update required — while still
//  working offline (cache or embedded fallback always succeeds).
//

import Foundation

// MARK: - Data model

struct FeaturedCatalog: Codable {
    let version: Int
    let updatedAt: Date?
    let packs: [FeaturedPack]
}

struct FeaturedPack: Codable, Identifiable, Hashable {
    let id: String
    let title: String
    let subtitle: String?
    let languageCode: String?
    let level: String?
    let trackCount: Int?
    let durationSeconds: Int?
    let author: String?
    let iconSymbol: String?     // SF Symbol name
    let accentColor: String?    // hex like "#E67E5C"
    let source: FeaturedPackSource

    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    static func == (a: FeaturedPack, b: FeaturedPack) -> Bool { a.id == b.id }
}

struct FeaturedPackSource: Codable, Hashable {
    /// "embedded" → bundle ships inside the app, install with no network.
    /// "remote"   → bundle.json at `manifestUrl`, downloaded on install.
    let kind: String
    let bundleId: String?      // for kind == "embedded"
    let manifestUrl: String?   // for kind == "remote"
}

// MARK: - Service

protocol FeaturedCatalogService {
    /// Load the catalog. Reads the bundled JSON for now; future revisions
    /// can race a remote fetch and prefer fresher copies.
    func loadCatalog() async throws -> FeaturedCatalog
}

enum FeaturedCatalogError: Error, LocalizedError {
    case missingBundledCatalog
    case decodeFailed(Error)

    var errorDescription: String? {
        switch self {
        case .missingBundledCatalog:
            return "featured_catalog.json is missing from the app bundle"
        case .decodeFailed(let error):
            return "Failed to decode featured_catalog.json: \(error.localizedDescription)"
        }
    }
}

final class FeaturedCatalogServiceLocal: FeaturedCatalogService {
    private static let resourceName = "featured_catalog"
    private static let remoteURL = URL(string: "https://d1ni0tk3ua6bwo.cloudfront.net/lmaudio/featured_catalog.json")!
    private static let cacheFilename = "featured_catalog.json"
    private static let remoteTimeoutSeconds: TimeInterval = 4
    /// Cache is only a short-lived offline bridge — not a permanent store.
    /// Without a TTL the cache would make the remote catalog effectively
    /// single-use, since any later offline launch would serve stale data forever.
    private static let cacheTTL: TimeInterval = 3600 // 1 hour

    func loadCatalog() async throws -> FeaturedCatalog {
        let decoder = makeDecoder()
        // Test hook: force the embedded copy (skip remote + cache) so UI tests
        // can exercise packs that only exist in this build's embedded catalog,
        // before the remote catalog is published. Opt-in via launch argument.
        if ProcessInfo.processInfo.arguments.contains("-forceEmbeddedCatalog") {
            return try loadEmbeddedCatalog(decoder: decoder)
        }
        // 1. Try remote (with short timeout). On success, write to cache and return.
        if let remote = await fetchRemoteCatalog(decoder: decoder) {
            persistRemoteCache(remote.data)
            return remote.catalog
        }
        // 2. Try cache only if it's fresh (within TTL).
        if let cached = loadCachedCatalog(decoder: decoder) {
            return cached
        }
        // 3. Fall back to the embedded copy that ships with the app.
        return try loadEmbeddedCatalog(decoder: decoder)
    }

    // MARK: - Remote

    private func fetchRemoteCatalog(decoder: JSONDecoder) async -> (catalog: FeaturedCatalog, data: Data)? {
        var request = URLRequest(url: Self.remoteURL)
        request.timeoutInterval = Self.remoteTimeoutSeconds
        request.cachePolicy = .reloadIgnoringLocalCacheData
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
                print("⚠️ [FeaturedCatalog] remote fetch HTTP \(http.statusCode), falling back")
                return nil
            }
            let catalog = try decoder.decode(FeaturedCatalog.self, from: data)
            print("✅ [FeaturedCatalog] loaded remote (version=\(catalog.version), \(catalog.packs.count) packs)")
            return (catalog, data)
        } catch {
            // Offline / timeout / DNS failure / parse error — completely silent
            // failure path; the cache or embedded copy will cover us.
            print("ℹ️ [FeaturedCatalog] remote fetch unavailable: \(error.localizedDescription)")
            return nil
        }
    }

    // MARK: - Cache (Caches directory)

    private static var cacheURL: URL? {
        guard let dir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first else {
            return nil
        }
        return dir.appendingPathComponent(cacheFilename)
    }

    private func persistRemoteCache(_ data: Data) {
        guard let url = Self.cacheURL else { return }
        do {
            try data.write(to: url, options: .atomic)
        } catch {
            print("⚠️ [FeaturedCatalog] failed to write cache: \(error)")
        }
    }

    private func loadCachedCatalog(decoder: JSONDecoder) -> FeaturedCatalog? {
        guard let url = Self.cacheURL,
              FileManager.default.fileExists(atPath: url.path) else { return nil }

        // Expire stale cache so the next launch retries remote
        if let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
           let modified = attrs[.modificationDate] as? Date,
           Date().timeIntervalSince(modified) > Self.cacheTTL {
            print("ℹ️ [FeaturedCatalog] cache expired, skipping")
            try? FileManager.default.removeItem(at: url)
            return nil
        }

        guard let data = try? Data(contentsOf: url) else { return nil }
        do {
            let catalog = try decoder.decode(FeaturedCatalog.self, from: data)
            print("✅ [FeaturedCatalog] loaded cached copy (version=\(catalog.version))")
            return catalog
        } catch {
            print("⚠️ [FeaturedCatalog] cached copy unreadable, removing: \(error)")
            try? FileManager.default.removeItem(at: url)
            return nil
        }
    }

    // MARK: - Embedded fallback

    private func loadEmbeddedCatalog(decoder: JSONDecoder) throws -> FeaturedCatalog {
        guard let url = Bundle.main.url(forResource: Self.resourceName, withExtension: "json") else {
            throw FeaturedCatalogError.missingBundledCatalog
        }
        let data = try Data(contentsOf: url)
        do {
            let catalog = try decoder.decode(FeaturedCatalog.self, from: data)
            print("✅ [FeaturedCatalog] loaded embedded copy (version=\(catalog.version))")
            return catalog
        } catch {
            throw FeaturedCatalogError.decodeFailed(error)
        }
    }

    private func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
