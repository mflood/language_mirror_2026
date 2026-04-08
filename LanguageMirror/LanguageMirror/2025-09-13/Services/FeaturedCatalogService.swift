//
//  FeaturedCatalogService.swift
//  LanguageMirror
//
//  Loads the Featured Packs catalog. The catalog ships inside the app as
//  `featured_catalog.json` and lists both app-embedded bundles and remote
//  (CloudFront-hosted) bundles. From the user's perspective they're a single
//  cohesive list of packs they can install.
//
//  Future: an updated copy of the catalog can be fetched from a known URL
//  (e.g. https://cdn/featured_catalog.json) so we can publish new packs
//  without shipping a new app version. For now we only load the local copy.
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

    func loadCatalog() async throws -> FeaturedCatalog {
        guard let url = Bundle.main.url(forResource: Self.resourceName, withExtension: "json") else {
            throw FeaturedCatalogError.missingBundledCatalog
        }
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        do {
            return try decoder.decode(FeaturedCatalog.self, from: data)
        } catch {
            throw FeaturedCatalogError.decodeFailed(error)
        }
    }
}
