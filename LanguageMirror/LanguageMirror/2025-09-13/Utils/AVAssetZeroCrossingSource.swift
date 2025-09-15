//
//  AVAssetZeroCrossingSource.swift
//  LanguageMirror
//
//  Created by Matthew Flood on 9/15/25.
//

// path: Utils/AVAssetZeroCrossingSource.swift
import Foundation
import AVFoundation
import CoreMedia

/// Zero-crossing finder that reads a small window (±windowMs) around `around` via AVAssetReader.
/// Decodes Float32 linear PCM (interleaved). For stereo, uses the first channel.
// path: Utils/AVAssetZeroCrossingSource.swift
// ⬇️ Replace the class with a version that supports directional queries.

final class AVAssetZeroCrossingSource: ZeroCrossingSource {
    private let asset: AVAsset
    init(url: URL) { self.asset = AVAsset(url: url) }

    func nearestZeroCrossing(around: Int, windowMs: Int, durationMs: Int) -> Int? {
        let prev = previousZeroCrossing(before: around, maxWindowMs: windowMs, durationMs: durationMs)
        let next = nextZeroCrossing(after: around, maxWindowMs: windowMs, durationMs: durationMs)
        switch (prev, next) {
        case (nil, nil): return nil
        case let (x?, nil): return x
        case let (nil, y?): return y
        case let (x?, y?):
            return abs(x - around) <= abs(y - around) ? x : y
        }
    }

    func nextZeroCrossing(after: Int, maxWindowMs: Int, durationMs: Int) -> Int? {
        return scanDirectional(startMs: after, endMs: min(durationMs, after + maxWindowMs), wantFirstAfter: true)
    }

    func previousZeroCrossing(before: Int, maxWindowMs: Int, durationMs: Int) -> Int? {
        return scanDirectional(startMs: max(0, before - maxWindowMs), endMs: before, wantFirstAfter: false)
    }

    // MARK: - Core scanner
    private func scanDirectional(startMs: Int, endMs: Int, wantFirstAfter: Bool) -> Int? {
        guard endMs > startMs,
              let track = asset.tracks(withMediaType: .audio).first else { return nil }

        let startSec = Double(startMs) / 1000.0
        let endSec = Double(endMs) / 1000.0
        let range = CMTimeRange(start: CMTime(seconds: startSec, preferredTimescale: 600),
                                end:   CMTime(seconds: endSec,   preferredTimescale: 600))
        guard range.duration.seconds > 0 else { return nil }

        guard let reader = try? AVAssetReader(asset: asset) else { return nil }
        let output = AVAssetReaderTrackOutput(track: track, outputSettings: [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVLinearPCMIsFloatKey: true,
            AVLinearPCMBitDepthKey: 32,
            AVLinearPCMIsNonInterleaved: false,
            AVLinearPCMIsBigEndianKey: false
        ])
        output.alwaysCopiesSampleData = false
        guard reader.canAdd(output) else { return nil }
        reader.add(output)
        reader.timeRange = range
        guard reader.startReading() else { return nil }

        var sr = 44100.0
        var ch = 1
        var absIndex = Int(round(startSec * sr))
        var prevSample: Float? = nil
        var found: Int? = nil
        var lastBefore: Int? = nil

        while reader.status == .reading {
            guard let sbuf = output.copyNextSampleBuffer(),
                  let dataBuf = CMSampleBufferGetDataBuffer(sbuf) else { break }

            if let fmt = CMSampleBufferGetFormatDescription(sbuf),
               let asbd = CMAudioFormatDescriptionGetStreamBasicDescription(fmt)?.pointee {
                sr = asbd.mSampleRate
                ch = max(1, Int(asbd.mChannelsPerFrame))
            }

            let length = CMBlockBufferGetDataLength(dataBuf)
            var data = Data(count: length)
            data.withUnsafeMutableBytes { dst in
                _ = CMBlockBufferCopyDataBytes(dataBuf, atOffset: 0, dataLength: length, destination: dst.baseAddress!)
            }

            let floatCount = length / MemoryLayout<Float>.size
            let frames = ch > 0 ? floatCount / ch : floatCount

            data.withUnsafeBytes { (ptr: UnsafeRawBufferPointer) in
                let f = ptr.bindMemory(to: Float.self)
                for frame in 0..<frames {
                    let s = f[frame * ch]
                    if let p = prevSample {
                        let crossed = (p <= 0 && s > 0) || (p >= 0 && s < 0)
                        if crossed {
                            let tMs = Int(round((Double(absIndex) / sr) * 1000.0))
                            if wantFirstAfter {
                                // first crossing in [startMs, endMs]
                                if found == nil { found = tMs }
                            } else {
                                // keep the last crossing <= endMs
                                lastBefore = tMs
                            }
                        }
                    }
                    prevSample = s
                    absIndex += 1
                }
            }

            CMSampleBufferInvalidate(sbuf)
        }

        if reader.status == .failed || reader.status == .cancelled { return nil }
        return wantFirstAfter ? found : lastBefore
    }
}
