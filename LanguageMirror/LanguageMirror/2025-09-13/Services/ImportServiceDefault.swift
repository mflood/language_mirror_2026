//
//  ImportServiceDefault.swift
//  LanguageMirror
//
//  Created by Matthew Flood on 9/16/25.
//

// path: Services/ImportServiceDefault.swift
import Foundation
import AVFoundation

protocol ImportService: AnyObject {
    /// Import a source. Returns created/updated Track ids.
    func `import`(source: ImportSource, completion: @escaping (Result<[Track], Error>) -> Void)
}

final class ImportServiceDefault: ImportService {
    private let fm = FileManager.default
    private let library: LibraryService
    private let segments: SegmentService

    init(library: LibraryService, segments: SegmentService) {
        self.library = library
        self.segments = segments
    }

    func `import`(source: ImportSource, completion: @escaping (Result<[Track], Error>) -> Void) {
        switch source {
        case .audioFile(let url):
            importAudio(at: url, title: url.deletingPathExtension().lastPathComponent, completion: completion)

        case .videoFile(let url):
            exportAudioFromVideo(url: url) { [weak self] result in
                switch result {
                case .failure(let e): completion(.failure(e))
                case .success(let audioURL):
                    self?.importAudio(at: audioURL, title: url.deletingPathExtension().lastPathComponent, completion: completion)
                }
            }

        case .recordedFile(let url):
            importAudio(at: url, title: "Recording \(Date().formatted())", completion: completion)

        case .remoteURL(let url, let title):
            download(url: url) { [weak self] result in
                switch result {
                case .failure(let e): completion(.failure(e))
                case .success(let tmp):
                    self?.importAudio(at: tmp, title: title ?? url.lastPathComponent, completion: completion)
                }
            }

        case .bundleManifest(let url):
            loadManifest(url: url) { [weak self] res in
                switch res {
                case .failure(let e): completion(.failure(e))
                case .success(let manifest):
                    self?.importManifest(manifest, baseURL: url.deletingLastPathComponent(), completion: completion)
                }
            }

        case .embeddedSample:
            do {
                let tracks = try installEmbeddedSample()
                completion(.success(tracks))
            } catch {
                completion(.failure(error))
            }
        }
    }

    // MARK: - Core audio import

    private func importAudio(at sourceURL: URL, title: String, completion: @escaping (Result<[Track], Error>) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                // Determine extension and make a new track id
                let id = UUID().uuidString
                let ext = sourceURL.pathExtension.isEmpty ? "m4a" : sourceURL.pathExtension
                let filename = "audio.\(ext)"
                guard let lib = self.library as? LibraryServiceJSON else { throw LibraryError.writeFailed }
                let folder = lib.trackFolder(for: id)
                try self.fm.createDirectory(at: folder, withIntermediateDirectories: true)
                let dest = folder.appendingPathComponent(filename)

                // Copy (or move if security-scope permits); here copy
                if self.fm.fileExists(atPath: dest.path) { try self.fm.removeItem(at: dest) }
                try self.fm.copyItem(at: sourceURL, to: dest)

                // Probe duration
                let asset = AVAsset(url: dest)
                let dur = CMTimeGetSeconds(asset.duration)
                let durationMs = Int((dur.isFinite ? dur : 0) * 1000.0)

                var track = Track(id: id, title: title, filename: filename, durationMs: durationMs)
                try self.library.addTrack(track)

                DispatchQueue.main.async { completion(.success([track])) }
            } catch {
                DispatchQueue.main.async { completion(.failure(error)) }
            }
        }
    }

    // MARK: - Download

    private func download(url: URL, completion: @escaping (Result<URL, Error>) -> Void) {
        let task = URLSession.shared.downloadTask(with: url) { tmp, resp, err in
            if let err = err { completion(.failure(err)); return }
            guard let tmp = tmp else { completion(.failure(LibraryError.writeFailed)); return }
            completion(.success(tmp))
        }
        task.resume()
    }

    // MARK: - Video → Audio

    private func exportAudioFromVideo(url: URL, completion: @escaping (Result<URL, Error>) -> Void) {
        let asset = AVAsset(url: url)
        guard let exporter = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetAppleM4A) else {
            completion(.failure(LibraryError.writeFailed)); return
        }
        let outURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString + ".m4a")
        exporter.outputURL = outURL
        exporter.outputFileType = .m4a
        exporter.exportAsynchronously {
            switch exporter.status {
            case .completed: completion(.success(outURL))
            case .failed, .cancelled: completion(.failure(exporter.error ?? LibraryError.writeFailed))
            default: break
            }
        }
    }

    // MARK: - Bundles

    private func loadManifest(url: URL, completion: @escaping (Result<BundleManifest, Error>) -> Void) {
        URLSession.shared.dataTask(with: url) { data, _, err in
            if let err = err { completion(.failure(err)); return }
            guard let data else { completion(.failure(LibraryError.writeFailed)); return }
            do {
                let mf = try JSONDecoder().decode(BundleManifest.self, from: data)
                completion(.success(mf))
            } catch { completion(.failure(error)) }
        }.resume()
    }

    private func importManifest(_ m: BundleManifest, baseURL: URL, completion: @escaping (Result<[Track], Error>) -> Void) {
        // Simple serial import; can parallelize later
        var results: [Track] = []
        let group = DispatchGroup()
        var lastError: Error?

        for item in m.tracks {
            group.enter()
            let id = item.id ?? UUID().uuidString
            let title = item.title

            let finish: (Result<URL, Error>) -> Void = { res in
                switch res {
                case .failure(let e): lastError = e; group.leave()
                case .success(let audioURL):
                    self.importAudio(at: audioURL, title: title) { r in
                        switch r {
                        case .failure(let e): lastError = e
                        case .success(let tks):
                            if let t = tks.first {
                                // update known id if manifest provided one
                                if item.id != nil && t.id != id {
                                    var fixed = t; fixed = Track(id: id, title: t.title, filename: t.filename, durationMs: t.durationMs)
                                    try? self.library.updateTrack(fixed)
                                }
                                if let seg = item.segments {
                                    _ = try? self.segments.replaceMap(seg, for: item.id ?? t.id)
                                }
                                results.append(try! self.library.loadTrack(id: item.id ?? t.id))
                            }
                        }
                        group.leave()
                    }
                }
            }

            if let s = item.url, let u = URL(string: s, relativeTo: baseURL) {
                download(url: u, completion: finish)
            } else {
                group.leave()
            }
        }

        group.notify(queue: .main) {
            if let err = lastError, results.isEmpty { completion(.failure(err)) }
            else { completion(.success(results)) }
        }
    }

    // MARK: - Embedded sample

    private func installEmbeddedSample() throws -> [Track] {
        var out: [Track] = []
        // Expecting a file sample.mp3 and a manifest `sample_bundle.json` in main bundle
        guard let audio = Bundle.main.url(forResource: "sample", withExtension: "mp3") else {
            throw LibraryError.notFound
        }
        let id = UUID().uuidString
        guard let lib = library as? LibraryServiceJSON else { throw LibraryError.writeFailed }
        let folder = lib.trackFolder(for: id)
        try fm.createDirectory(at: folder, withIntermediateDirectories: true)
        let dest = folder.appendingPathComponent("sample.mp3")
        if fm.fileExists(atPath: dest.path) { try fm.removeItem(at: dest) }
        try fm.copyItem(at: audio, to: dest)

        let asset = AVAsset(url: dest)
        let dur = CMTimeGetSeconds(asset.duration)
        let ms = Int((dur.isFinite ? dur : 0) * 1000.0)

        let track = Track(id: id, title: "Sample Track", filename: "sample.mp3", durationMs: ms)
        try library.addTrack(track)
        out.append(track)

        // Optional: if you ship `sample_bundle.json` with segments for this file, load and apply:
        if let murl = Bundle.main.url(forResource: "sample_bundle", withExtension: "json"),
           let data = try? Data(contentsOf: murl),
           let mf = try? JSONDecoder().decode(BundleManifest.self, from: data),
           let seg = mf.tracks.first?.segments {
            _ = try? segments.replaceMap(seg, for: track.id)
        }
        return out
    }
}
