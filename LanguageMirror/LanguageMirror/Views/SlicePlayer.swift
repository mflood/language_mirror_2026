//
//  SlicePlayer.swift
//  LanguageMirror
//
//  Created by Matthew Flood on 6/28/25.
//

import AVFoundation


// MARK: - SlicePlayer (AVQueue wrapper)
final class SlicePlayer {
    private var queue: AVQueuePlayer?
    func play(trackURL:URL, slices:[Slice], loops:Int){ guard !slices.isEmpty else{return}; let items=(0..<loops).flatMap{ _ in slices }.map{ slice->AVPlayerItem in
        let asset=AVURLAsset(url:trackURL); let timeRange=CMTimeRange(start:CMTime(seconds:slice.start,preferredTimescale:600), duration:CMTime(seconds:slice.end-slice.start,preferredTimescale:600)); asset.resourceLoader.preloadsEligibleContentKeys=false; let comp=AVMutableComposition(); try? comp.insertTimeRange(timeRange, of:asset, at:.zero); return AVPlayerItem(asset:comp) }
        queue=AVQueuePlayer(items:items); queue?.play() }
    func pause(){ queue?.pause() }
}


