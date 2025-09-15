//
//  WaveformPlaceholderView.swift
//  LanguageMirror
//
//  Created by Matthew Flood on 9/15/25.
//
// path: Views/WaveformPlaceholderView.swift
// REPLACE the whole file with this updated version (adds snap + zero-crossing + minor refactors).
import UIKit

/// A lightweight, synthetic waveform placeholder with draggable start/end handles.
/// - Reports selection in ms via `onSelectionChanged`.
/// - Optional zero-crossing snapping (using a synthetic source for now).
final class WaveformPlaceholderView: UIView {

    // MARK: Public configuration
    var durationMs: Int = 60_000 { didSet { setNeedsLayout(); setNeedsDisplay() } }
    var startMs: Int = 1_000 { didSet { clampSelection(); syncUI() } }
    var endMs: Int = 4_000   { didSet { clampSelection(); syncUI() } }
    var minSpanMs: Int = 150

    /// Snap handles to nearest zero-crossing when gesture ends.
    var snapEnabled: Bool = true
    /// How far to search around the handle (in ms) for a zero crossing.
    var zeroCrossWindowMs: Int = 40

    /// Source that can return a zero crossing near a given time (ms).
    var zeroCrossingSource: ZeroCrossingSource?

    var onSelectionChanged: ((Int, Int) -> Void)?

    // MARK: Subviews
    private let leftHandle = HandleView()
    private let rightHandle = HandleView()
    private let selectionOverlay = UIView()
    private let topRuler = TimeRuler()

    // Gestures
    private lazy var leftPan = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
    private lazy var rightPan = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))

    override init(frame: CGRect) {
        super.init(frame: frame)
        isOpaque = true
        backgroundColor = .secondarySystemBackground

        addSubview(topRuler)
        addSubview(selectionOverlay)
        addSubview(leftHandle)
        addSubview(rightHandle)

        selectionOverlay.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.2)

        leftHandle.addGestureRecognizer(leftPan)
        rightHandle.addGestureRecognizer(rightPan)
        leftHandle.isUserInteractionEnabled = true
        rightHandle.isUserInteractionEnabled = true
        leftHandle.accessibilityLabel = "Segment start"
        rightHandle.accessibilityLabel = "Segment end"

        // default zero-crossing source matches our synthetic draw function
        zeroCrossingSource = SyntheticZeroCrossingSource(cycles: 6, jitter: 0.15)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layoutSubviews() {
        super.layoutSubviews()
        let rulerH: CGFloat = 18
        topRuler.frame = CGRect(x: 0, y: 0, width: bounds.width, height: rulerH)
        topRuler.durationMs = durationMs

        let handleW: CGFloat = 24
        let handleH: CGFloat = bounds.height - rulerH
        leftHandle.frame = CGRect(x: xFor(ms: startMs) - handleW/2, y: rulerH, width: handleW, height: handleH)
        rightHandle.frame = CGRect(x: xFor(ms: endMs)   - handleW/2, y: rulerH, width: handleW, height: handleH)

        let selX = min(leftHandle.frame.midX, rightHandle.frame.midX)
        let selW = abs(rightHandle.frame.midX - leftHandle.frame.midX)
        selectionOverlay.frame = CGRect(x: selX, y: rulerH, width: selW, height: handleH)

        setNeedsDisplay()
    }

    override func draw(_ rect: CGRect) {
        super.draw(rect)
        let ctx = UIGraphicsGetCurrentContext()!
        let rulerH: CGFloat = topRuler.bounds.height
        let h = rect.height - rulerH

        // Background bands
        ctx.saveGState()
        let bg = UIBezierPath(rect: CGRect(x: 0, y: rulerH, width: rect.width, height: h))
        UIColor.systemBackground.setFill()
        bg.fill()
        UIColor.tertiarySystemFill.setFill()
        UIBezierPath(rect: CGRect(x: 0, y: rulerH + h*0.5, width: rect.width, height: h*0.5)).fill()
        ctx.restoreGState()

        // Synthetic waveform path (sine-ish)
        let path = UIBezierPath()
        let midY = rulerH + h/2
        let amp = h * 0.35
        let cycles: CGFloat = 6
        let jitter: CGFloat = 0.15
        let step: CGFloat = 2
        var x: CGFloat = 0
        while x <= rect.width {
            let t = x / rect.width
            let base = sin(t * .pi * 2 * cycles)
            let j = sin(t * .pi * 37) * jitter
            let y = midY - (base + j) * amp
            if x == 0 { path.move(to: CGPoint(x: x, y: y)) } else { path.addLine(to: CGPoint(x: x, y: y)) }
            x += step
        }
        UIColor.systemGray.setStroke()
        path.lineWidth = 1
        path.stroke()
    }

    // MARK: - Public
    func setSelection(start: Int, end: Int) {
        startMs = start
        endMs = end
        syncUI()
    }

    // MARK: - Gestures
    @objc private func handlePan(_ gr: UIPanGestureRecognizer) {
        let translation = gr.translation(in: self)
        gr.setTranslation(.zero, in: self)
        guard durationMs > 0 else { return }

        if gr.view === leftHandle {
            let newX = leftHandle.center.x + translation.x
            leftHandle.center.x = clamp(newX, min: 0, max: bounds.width)
            startMs = msFor(x: leftHandle.center.x)
            if endMs - startMs < minSpanMs { startMs = endMs - minSpanMs }
        } else if gr.view === rightHandle {
            let newX = rightHandle.center.x + translation.x
            rightHandle.center.x = clamp(newX, min: 0, max: bounds.width)
            endMs = msFor(x: rightHandle.center.x)
            if endMs - startMs < minSpanMs { endMs = startMs + minSpanMs }
        }

        syncUI()
        onSelectionChanged?(startMs, endMs)

        if gr.state == .ended, snapEnabled {
            // Snap whichever handle moved last
            if gr.view === leftHandle {
                if let snapped = zeroCrossingSource?.nearestZeroCrossing(around: startMs, windowMs: zeroCrossWindowMs, durationMs: durationMs) {
                    startMs = min(snapped, endMs - minSpanMs)
                }
            } else if gr.view === rightHandle {
                if let snapped = zeroCrossingSource?.nearestZeroCrossing(around: endMs, windowMs: zeroCrossWindowMs, durationMs: durationMs) {
                    endMs = max(snapped, startMs + minSpanMs)
                }
            }
            syncUI()
            onSelectionChanged?(startMs, endMs)
        }
    }

    // MARK: - Helpers
    private func syncUI() { setNeedsLayout() }

    private func clampSelection() {
        if startMs < 0 { startMs = 0 }
        if endMs > durationMs { endMs = durationMs }
        if endMs - startMs < minSpanMs { endMs = min(durationMs, startMs + minSpanMs) }
    }

    private func xFor(ms: Int) -> CGFloat {
        guard durationMs > 0 else { return 0 }
        return CGFloat(Double(ms) / Double(durationMs)) * bounds.width
    }

    private func msFor(x: CGFloat) -> Int {
        guard bounds.width > 0 else { return 0 }
        let t = max(0, min(1, Double(x / bounds.width)))
        return Int(round(t * Double(durationMs)))
    }

    private func clamp(_ v: CGFloat, min: CGFloat, max: CGFloat) -> CGFloat {
        return Swift.max(min, Swift.min(max, v))
    }
}

// MARK: - Handle view (hit area + center rule)
private final class HandleView: UIView {
    private let bar = UIView()
    override init(frame: CGRect) {
        super.init(frame: frame)
        isOpaque = false
        bar.backgroundColor = .systemBlue
        bar.translatesAutoresizingMaskIntoConstraints = false
        addSubview(bar)
        NSLayoutConstraint.activate([
            bar.centerXAnchor.constraint(equalTo: centerXAnchor),
            bar.topAnchor.constraint(equalTo: topAnchor),
            bar.bottomAnchor.constraint(equalTo: bottomAnchor),
            bar.widthAnchor.constraint(equalToConstant: 2)
        ])
        backgroundColor = UIColor.systemBlue.withAlphaComponent(0.08)
        layer.cornerRadius = 6
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}

// MARK: - Time ruler
private final class TimeRuler: UIView {
    var durationMs: Int = 60_000 { didSet { setNeedsDisplay() } }
    override func draw(_ rect: CGRect) {
        let ctx = UIGraphicsGetCurrentContext()!
        let h = rect.height
        UIColor.secondaryLabel.setStroke()
        ctx.setLineWidth(1)

        let totalSec = max(1, Double(durationMs) / 1000.0)
        let pixelsPerSec = rect.width / CGFloat(totalSec)
        let majorEvery: Double = pickMajorTick(pixelsPerSec: pixelsPerSec)
        let minorEvery = majorEvery / 2

        // baseline
        ctx.move(to: CGPoint(x: 0, y: h-1)); ctx.addLine(to: CGPoint(x: rect.width, y: h-1)); ctx.strokePath()

        func drawTick(at t: Double, major: Bool) {
            let x = CGFloat(t / totalSec) * rect.width
            let length: CGFloat = major ? h-2 : h-8
            ctx.move(to: CGPoint(x: x, y: h-1))
            ctx.addLine(to: CGPoint(x: x, y: h-length))
            ctx.strokePath()
            if major {
                let label: String = t < 60 ? String(format: "%.0fs", t) : String(format: "%.0f:%02.0f", floor(t/60), t.truncatingRemainder(dividingBy: 60))
                let attrs: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 10, weight: .regular),
                    .foregroundColor: UIColor.secondaryLabel
                ]
                let size = (label as NSString).size(withAttributes: attrs)
                (label as NSString).draw(at: CGPoint(x: x+2, y: h-size.height-2), withAttributes: attrs)
            }
        }

        // ticks
        var t: Double = 0
        while t <= totalSec + 0.0001 {
            drawTick(at: t, major: true)
            if minorEvery > 0 {
                let mid = t + minorEvery
                if mid < totalSec { drawTick(at: mid, major: false) }
            }
            t += majorEvery
        }
    }

    private func pickMajorTick(pixelsPerSec: CGFloat) -> Double {
        // Aim for ~70–120px between major ticks
        if pixelsPerSec >= 200 { return 0.5 }
        if pixelsPerSec >= 120 { return 1.0 }
        if pixelsPerSec >= 70  { return 2.0 }
        if pixelsPerSec >= 40  { return 5.0 }
        if pixelsPerSec >= 20  { return 10.0 }
        return 15.0
    }
}

// MARK: - Zero-crossing source (pluggable)

protocol ZeroCrossingSource {

    /// Nearest (direction-agnostic) crossing within ±windowMs.
    func nearestZeroCrossing(around: Int, windowMs: Int, durationMs: Int) -> Int?

    /// First crossing strictly AFTER `after` within [+0, maxWindowMs].
    func nextZeroCrossing(after: Int, maxWindowMs: Int, durationMs: Int) -> Int?

    /// Last crossing strictly BEFORE `before` within [-maxWindowMs, +0].
    func previousZeroCrossing(before: Int, maxWindowMs: Int, durationMs: Int) -> Int?

}

/// Synthetic source derived from the same math used in draw(_:) so snapping "looks right"
/// until we replace with a true audio-driven source.
/// Synthetic source derived from the placeholder waveform until we swap to true audio.
final class SyntheticZeroCrossingSource: ZeroCrossingSource {
    private let cycles: CGFloat
    private let jitter: CGFloat

    init(cycles: CGFloat, jitter: CGFloat) {
        self.cycles = cycles; self.jitter = jitter
    }

    func nearestZeroCrossing(around: Int, windowMs: Int, durationMs: Int) -> Int? {
        let a = previousZeroCrossing(before: around, maxWindowMs: windowMs, durationMs: durationMs)
        let b = nextZeroCrossing(after: around, maxWindowMs: windowMs, durationMs: durationMs)
        switch (a,b) {
        case (nil, nil): return nil
        case let (x?, nil): return x
        case let (nil, y?): return y
        case let (x?, y?):
            return abs(x - around) <= abs(y - around) ? x : y
        }
    }

    func nextZeroCrossing(after: Int, maxWindowMs: Int, durationMs: Int) -> Int? {
        guard durationMs > 0 else { return nil }
        let end = min(durationMs, after + maxWindowMs)
        var prev = sample(ms: after, durationMs: durationMs)
        for ms in (after+1)...end {
            let v = sample(ms: ms, durationMs: durationMs)
            if (prev <= 0 && v > 0) || (prev >= 0 && v < 0) { return ms }
            prev = v
        }
        return nil
    }

    func previousZeroCrossing(before: Int, maxWindowMs: Int, durationMs: Int) -> Int? {
        guard durationMs > 0 else { return nil }
        let start = max(0, before - maxWindowMs)
        var prev = sample(ms: start, durationMs: durationMs)
        var lastCross: Int?
        for ms in (start+1)...before {
            let v = sample(ms: ms, durationMs: durationMs)
            if (prev <= 0 && v > 0) || (prev >= 0 && v < 0) { lastCross = ms }
            prev = v
        }
        return lastCross
    }

    private func sample(ms: Int, durationMs: Int) -> CGFloat {
        let t = CGFloat(ms) / CGFloat(durationMs)
        let base = sin(t * .pi * 2 * cycles)
        let j = sin(t * .pi * 37) * jitter
        return base + j
    }
}
