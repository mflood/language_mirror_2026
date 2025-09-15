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
final class AVAssetZeroCrossingSource: ZeroCrossingSource {
    private let asset: AVAsset

    init(url: URL) {
        self.asset = AVAsset(url: url)
    }

    /// Returns nearest zero-crossing time (ms) near `around` by scanning ±windowMs.
    func nearestZeroCrossing(around: Int, windowMs: Int, durationMs: Int) -> Int? {
        guard let track = asset.tracks(withMediaType: .audio).first else { return nil }

        // Clamp search window to asset duration
        let assetSeconds = asset.duration.isValid ? CMTimeGetSeconds(asset.duration) : Double(durationMs) / 1000.0
        let aroundSec = max(0.0, min(Double(around) / 1000.0, assetSeconds))
        let winSec = max(0.001, Double(windowMs) / 1000.0)
        let startSec = max(0.0, aroundSec - winSec)
        let endSec = min(assetSeconds, aroundSec + winSec)
        let range = CMTimeRange(start: CMTime(seconds: startSec, preferredTimescale: 600),
                                end:   CMTime(seconds: endSec,   preferredTimescale: 600))
        guard range.duration.seconds > 0 else { return nil }

        // Reader + output as Float32, interleaved
        guard let reader = try? AVAssetReader(asset: asset) else { return nil }
        let output = AVAssetReaderTrackOutput(track: track, outputSettings: [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVLinearPCMIsFloatKey: true,
            AVLinearPCMBitDepthKey: 32,
            AVLinearPCMIsNonInterleaved: false, // interleaved: 1 buffer; read first channel
            AVLinearPCMIsBigEndianKey: false
        ])
        output.alwaysCopiesSampleData = false
        guard reader.canAdd(output) else { return nil }
        reader.add(output)
        reader.timeRange = range
        guard reader.startReading() else { return nil }

        var sampleRate: Double?
        var channels: Int = 1
        var startSampleIndexBase: Int // absolute sample index at range.start
        // We'll compute this after we know the sample rate.

        // Tracking nearest crossing
        var bestMs: Int?
        var bestDist: Double = .infinity

        // prev sample value to detect sign change
        var prevSample: Float? = nil
        // Absolute sample index (across entire file) for the *current* sample
        var absoluteSampleIndex: Int = 0

        while reader.status == .reading {
            guard let sbuf = output.copyNextSampleBuffer() else { break }

            // Get ASBD from the buffer to determine sampleRate / channels (once)
            if sampleRate == nil {
                if let fmt = CMSampleBufferGetFormatDescription(sbuf),
                   let asbdPtr = CMAudioFormatDescriptionGetStreamBasicDescription(fmt) {
                    let asbd = asbdPtr.pointee
                    sampleRate = asbd.mSampleRate
                    channels = max(1, Int(asbd.mChannelsPerFrame))
                }
                if sampleRate == nil {
                    // Fallback to common rate if unknown
                    sampleRate = 44100.0
                }
                // Compute absolute start sample index for range.start
                startSampleIndexBase = Int(round(startSec * (sampleRate ?? 44100.0)))
                absoluteSampleIndex = startSampleIndexBase
            }

            // Extract raw bytes
            guard let dataBuf = CMSampleBufferGetDataBuffer(sbuf) else { continue }
            let length = CMBlockBufferGetDataLength(dataBuf)
            var data = Data(count: length)
            data.withUnsafeMutableBytes { (dst: UnsafeMutableRawBufferPointer) in
                _ = CMBlockBufferCopyDataBytes(dataBuf, atOffset: 0, dataLength: length, destination: dst.baseAddress!)
            }

            // Interpret as Float32 samples; interleaved if channels > 1.
            let floatCount = length / MemoryLayout<Float>.size
            let frames = channels > 0 ? floatCount / channels : floatCount
            data.withUnsafeBytes { (ptr: UnsafeRawBufferPointer) in
                let fptr = ptr.bindMemory(to: Float.self)
                for frame in 0..<frames {
                    // Use first channel for sign (simple & fast)
                    let s = fptr[frame * channels]

                    if let p = prevSample {
                        // crossing if sign flips across zero
                        if (p <= 0 && s > 0) || (p >= 0 && s < 0) {
                            // crossing at current absoluteSampleIndex
                            let tMs = Int(round((Double(absoluteSampleIndex) / (sampleRate ?? 44100.0)) * 1000.0))
                            let dist = abs(Double(tMs) - Double(around))
                            if dist < bestDist {
                                bestDist = dist
                                bestMs = tMs
                            }
                        }
                    }
                    prevSample = s
                    absoluteSampleIndex += 1
                }
            }

            CMSampleBufferInvalidate(sbuf)
        }

        // If the reader failed (e.g., unsupported codec), bail out gracefully
        if reader.status == .failed || reader.status == .cancelled {
            return nil
        }

        // Clamp result to the search window just in case
        if let found = bestMs {
            let minMs = Int(startSec * 1000.0)
            let maxMs = Int(endSec * 1000.0)
            return max(minMs, min(maxMs, found))
        }
        return nil
    }
}
