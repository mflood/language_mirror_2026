//
//  SelectionLevelAnalyzer.swift
//  LanguageMirror
//
//  Created by Matthew Flood on 9/15/25.
//

// path: Utils/SelectionLevelAnalyzer.swift
import Foundation
import AVFoundation

struct SelectionLevelResult {
    let rms: Double   // 0.0 ... 1.0
    let peak: Double  // 0.0 ... 1.0
}

final class SelectionLevelAnalyzer {
    private let asset: AVAsset
    init(url: URL) { self.asset = AVAsset(url: url) }

    /// Synchronously analyze RMS & peak of [startMs, endMs) using Float32 PCM (first channel).
    func analyze(startMs: Int, endMs: Int) -> SelectionLevelResult? {
        guard endMs > startMs,
              let track = asset.tracks(withMediaType: .audio).first else { return nil }

        let start = Double(startMs) / 1000.0
        let end   = Double(endMs)   / 1000.0
        let range = CMTimeRange(start: CMTime(seconds: start, preferredTimescale: 600),
                                end:   CMTime(seconds: end,   preferredTimescale: 600))

        guard let reader = try? AVAssetReader(asset: asset) else { return nil }
        let out = AVAssetReaderTrackOutput(track: track, outputSettings: [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVLinearPCMIsFloatKey: true,
            AVLinearPCMBitDepthKey: 32,
            AVLinearPCMIsNonInterleaved: false,
            AVLinearPCMIsBigEndianKey: false
        ])
        out.alwaysCopiesSampleData = false
        guard reader.canAdd(out) else { return nil }
        reader.add(out)
        reader.timeRange = range
        guard reader.startReading() else { return nil }

        var peak: Float = 0
        var sumSquares: Double = 0
        var count: Int = 0
        var channels = 1

        while reader.status == .reading {
            guard let sbuf = out.copyNextSampleBuffer(),
                  let dataBuf = CMSampleBufferGetDataBuffer(sbuf) else { break }

            if let fmt = CMSampleBufferGetFormatDescription(sbuf),
               let asbd = CMAudioFormatDescriptionGetStreamBasicDescription(fmt)?.pointee {
                channels = max(1, Int(asbd.mChannelsPerFrame))
            }

            let length = CMBlockBufferGetDataLength(dataBuf)
            var data = Data(count: length)
            data.withUnsafeMutableBytes { dst in
                _ = CMBlockBufferCopyDataBytes(dataBuf, atOffset: 0, dataLength: length, destination: dst.baseAddress!)
            }

            let floatCount = length / MemoryLayout<Float>.size
            let frames = channels > 0 ? floatCount / channels : floatCount

            data.withUnsafeBytes { (ptr: UnsafeRawBufferPointer) in
                let f = ptr.bindMemory(to: Float.self)
                for frame in 0..<frames {
                    let s = f[frame * channels] // first channel
                    let a = fabsf(s)
                    if a > peak { peak = a }
                    sumSquares += Double(s) * Double(s)
                    count += 1
                }
            }
            CMSampleBufferInvalidate(sbuf)
        }

        if reader.status == .failed || reader.status == .cancelled { return nil }
        guard count > 0 else { return SelectionLevelResult(rms: 0, peak: 0) }
        let rms = sqrt(sumSquares / Double(count))
        // clamp to [0,1]
        return SelectionLevelResult(rms: min(1.0, rms), peak: min(1.0, Double(peak)))
    }
}

extension Double {
    /// Convert linear [0..1] to dBFS (0 = full scale). Returns negative dB; -inf clamped to -80.
    var dbFS: Double {
        let v = max(self, 1e-6)
        return max(-80.0, 20.0 * log10(v))
    }
}
