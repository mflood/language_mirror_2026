//
//  SlicePlayer.swift
//  LanguageMirror
//
//  Created by Matthew Flood on 6/28/25.
//

import AVFoundation

/// Plays only the requested slice ranges of an audio file, optionally looping them.
/// Keeps track of overall progress so a UI can display “time elapsed / total”.
final class SlicePlayer {

    // MARK: – Public read-only state
    /// Sum of every slice’s length × loops, in seconds.
    private(set) var duration: TimeInterval = 0

    /// Current position in the assembled queue (0 … duration).
    var currentTime: TimeInterval {
        guard
            let queue = queue,
            let currentItem = queue.currentItem,
            let index = items.firstIndex(of: currentItem)
        else { return 0 }

        let elapsedOfFinishedItems = sliceDurations.prefix(index).reduce(0, +)
        return elapsedOfFinishedItems + currentItem.currentTime().seconds
    }

    // MARK: – Private
    private var queue: AVQueuePlayer?
    private var items: [AVPlayerItem] = []
    private var sliceDurations: [TimeInterval] = []   // 1:1 with `items`

    // MARK: – Playback
    /// Assemble a queue containing `slices` repeated `loops` times
    /// and start playback immediately.
    func play(trackURL: URL, slices: [Slice], loops: Int) {
        guard !slices.isEmpty, loops > 0 else { return }

        // Clean slate
        queue?.pause()
        queue = nil
        items.removeAll()
        sliceDurations.removeAll()

        //----------------------------------------
        // Build AVPlayerItems (slice × loop)
        //----------------------------------------
        let timeScale: CMTimeScale = 600   // 1 ms precision

        for _ in 0..<loops {
            for slice in slices {
                let asset = AVURLAsset(url: trackURL)

                let start    = CMTime(seconds: slice.start,
                                      preferredTimescale: timeScale)
                let duration = CMTime(seconds: slice.end - slice.start,
                                      preferredTimescale: timeScale)

                // AVMutableComposition trims the asset to just the slice
                let comp = AVMutableComposition()
                try? comp.insertTimeRange(
                    CMTimeRange(start: start, duration: duration),
                    of: asset,
                    at: .zero
                )

                let item = AVPlayerItem(asset: comp)
                items.append(item)
                sliceDurations.append(duration.seconds)
            }
        }

        //----------------------------------------
        // Final book-keeping & start
        //----------------------------------------
        duration = sliceDurations.reduce(0, +)            // total length
        queue    = AVQueuePlayer(items: items)
        queue?.play()
    }

    /// Pause (can be resumed with another `play` call).
    func pause() { queue?.pause() }
}
