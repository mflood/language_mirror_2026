//
//  ScrollingWaveformView.swift
//  LanguageMirror
//
//  Created by Matthew Flood on 3/1/26.
//

import UIKit

final class ScrollingWaveformView: UIView {

    enum Mode { case recording, review }

    // MARK: - Public API

    var mode: Mode = .recording
    var onSeek: ((CGFloat) -> Void)?
    var onScrub: ((CGFloat) -> Void)?

    // MARK: - Constants

    private let barWidth: CGFloat = 3
    private let barGap: CGFloat = 1.5
    private var barStride: CGFloat { barWidth + barGap }
    private let minBarHeight: CGFloat = 2
    private let playheadWidth: CGFloat = 2

    // MARK: - Data

    private var samples: [Float] = []
    private var resampledBars: [Float] = []
    private var visibleBarCount: Int = 0

    // MARK: - Layers

    private let backgroundBarsLayer = CAShapeLayer()
    private let activeBarsLayer = CAShapeLayer()
    private let activeMaskLayer = CALayer()
    private let playheadLayer = CAShapeLayer()

    // MARK: - Gesture Recognizers

    private lazy var tapRecognizer = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
    private lazy var panRecognizer = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))

    // MARK: - Init

    override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }

    private func commonInit() {
        clipsToBounds = true
        layer.cornerRadius = 12
        layer.cornerCurve = .continuous
        backgroundColor = AppColors.cardBackground
        applyAdaptiveShadow(radius: 8, opacity: 0.1)

        // Background bars (dim, review only)
        backgroundBarsLayer.fillColor = AppColors.primaryAccent.withAlphaComponent(0.3).cgColor
        backgroundBarsLayer.isHidden = true
        layer.addSublayer(backgroundBarsLayer)

        // Active bars (full opacity)
        activeBarsLayer.fillColor = AppColors.primaryAccent.cgColor
        layer.addSublayer(activeBarsLayer)

        // Mask for active bars in review mode (clips to playhead position)
        activeMaskLayer.backgroundColor = UIColor.white.cgColor
        // Not applied until review mode

        // Playhead
        playheadLayer.fillColor = AppColors.primaryAccent.withAlphaComponent(0.8).cgColor
        playheadLayer.isHidden = true
        layer.addSublayer(playheadLayer)

        // Gestures (disabled until review)
        tapRecognizer.isEnabled = false
        panRecognizer.isEnabled = false
        addGestureRecognizer(tapRecognizer)
        addGestureRecognizer(panRecognizer)

        isAccessibilityElement = true
        accessibilityLabel = "Audio waveform"
        accessibilityTraits = .updatesFrequently
    }

    // MARK: - Layout

    override func layoutSubviews() {
        super.layoutSubviews()
        let newCount = max(1, Int(floor(bounds.width / barStride)))
        if newCount != visibleBarCount {
            visibleBarCount = newCount
            if mode == .review {
                resampleForReview()
                rebuildReviewPaths()
                setPlaybackProgress(lastProgress)
            } else {
                rebuildRecordingPath()
            }
        }
        updatePlayheadFrame()
    }

    // MARK: - Recording Mode

    func appendSample(_ amplitude: Float) {
        guard mode == .recording else { return }
        samples.append(max(0, min(1, amplitude)))
        rebuildRecordingPath()
    }

    private func rebuildRecordingPath() {
        guard visibleBarCount > 0 else { return }
        let start = max(0, samples.count - visibleBarCount)
        let window = Array(samples[start...])
        let path = buildMirroredBarPath(from: window, rightAligned: true)
        activeBarsLayer.path = path.cgPath

        // Pin playhead at right edge of last bar
        let barCount = min(window.count, visibleBarCount)
        let playheadX = CGFloat(barCount) * barStride - barGap
        updatePlayheadPosition(x: playheadX)
        playheadLayer.isHidden = barCount == 0
    }

    // MARK: - Review Mode

    func switchToReviewMode() {
        mode = .review
        resampleForReview()
        rebuildReviewPaths()
        setPlaybackProgress(0)

        backgroundBarsLayer.isHidden = false
        playheadLayer.isHidden = false
        tapRecognizer.isEnabled = true
        panRecognizer.isEnabled = true

        // Apply mask to active bars
        activeBarsLayer.mask = activeMaskLayer

        accessibilityTraits = [.adjustable, .allowsDirectInteraction]
        accessibilityHint = "Tap or drag to seek"
    }

    private func resampleForReview() {
        guard visibleBarCount > 0, !samples.isEmpty else {
            resampledBars = []
            return
        }
        if samples.count <= visibleBarCount {
            resampledBars = samples
            // Pad to fill width
            while resampledBars.count < visibleBarCount {
                resampledBars.append(0)
            }
            return
        }
        // Max-of-bucket resampling
        let bucketSize = Double(samples.count) / Double(visibleBarCount)
        resampledBars = (0..<visibleBarCount).map { i in
            let lo = Int(Double(i) * bucketSize)
            let hi = min(Int(Double(i + 1) * bucketSize), samples.count)
            guard lo < hi else { return 0 }
            return samples[lo..<hi].max() ?? 0
        }
    }

    private func rebuildReviewPaths() {
        let fullPath = buildMirroredBarPath(from: resampledBars, rightAligned: false)
        backgroundBarsLayer.path = fullPath.cgPath
        activeBarsLayer.path = fullPath.cgPath
    }

    private var lastProgress: CGFloat = 0

    func setPlaybackProgress(_ progress: CGFloat) {
        guard mode == .review else { return }
        lastProgress = max(0, min(1, progress))
        let maskWidth = bounds.width * lastProgress
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        activeMaskLayer.frame = CGRect(x: 0, y: 0, width: maskWidth, height: bounds.height)
        CATransaction.commit()

        let playheadX = maskWidth
        updatePlayheadPosition(x: playheadX)
    }

    // MARK: - Reset

    func reset() {
        samples.removeAll()
        resampledBars.removeAll()
        lastProgress = 0
        mode = .recording

        backgroundBarsLayer.path = nil
        backgroundBarsLayer.isHidden = true
        activeBarsLayer.path = nil
        activeBarsLayer.mask = nil
        playheadLayer.isHidden = true

        tapRecognizer.isEnabled = false
        panRecognizer.isEnabled = false

        accessibilityTraits = .updatesFrequently
        accessibilityHint = nil
    }

    // MARK: - Appearance

    func updateColors() {
        let accentCG = AppColors.primaryAccent.cgColor
        activeBarsLayer.fillColor = accentCG
        backgroundBarsLayer.fillColor = AppColors.primaryAccent.withAlphaComponent(0.3).cgColor
        playheadLayer.fillColor = AppColors.primaryAccent.withAlphaComponent(0.8).cgColor
        backgroundColor = AppColors.cardBackground
        applyAdaptiveShadow(radius: 8, opacity: 0.1)
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
            updateColors()
        }
    }

    // MARK: - Path Building

    private func buildMirroredBarPath(from values: [Float], rightAligned: Bool) -> UIBezierPath {
        let path = UIBezierPath()
        let midY = bounds.height / 2
        let maxBarHeight = bounds.height - 4  // 2pt padding top+bottom
        let cornerRadius = barWidth / 2

        let offsetX: CGFloat
        if rightAligned {
            // Align bars to the right edge
            let totalBarsWidth = CGFloat(values.count) * barStride
            offsetX = max(0, bounds.width - totalBarsWidth)
        } else {
            offsetX = 0
        }

        for (i, value) in values.enumerated() {
            let amplitude = CGFloat(value)
            let halfHeight = max(minBarHeight / 2, amplitude * maxBarHeight / 2)
            let x = offsetX + CGFloat(i) * barStride
            let rect = CGRect(x: x, y: midY - halfHeight, width: barWidth, height: halfHeight * 2)
            path.append(UIBezierPath(roundedRect: rect, cornerRadius: cornerRadius))
        }
        return path
    }

    // MARK: - Playhead

    private func updatePlayheadPosition(x: CGFloat) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        let clampedX = max(0, min(x, bounds.width - playheadWidth))
        playheadLayer.frame = CGRect(x: clampedX, y: 2, width: playheadWidth, height: bounds.height - 4)
        playheadLayer.cornerRadius = playheadWidth / 2
        CATransaction.commit()
    }

    private func updatePlayheadFrame() {
        // Re-derive from last known position
        if mode == .review {
            setPlaybackProgress(lastProgress)
        }
    }

    // MARK: - Gestures

    @objc private func handleTap(_ gesture: UITapGestureRecognizer) {
        guard mode == .review else { return }
        let x = gesture.location(in: self).x
        let progress = max(0, min(1, x / bounds.width))
        onSeek?(progress)
    }

    @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
        guard mode == .review else { return }
        let x = gesture.location(in: self).x
        let progress = max(0, min(1, x / bounds.width))
        onScrub?(progress)
    }
}
