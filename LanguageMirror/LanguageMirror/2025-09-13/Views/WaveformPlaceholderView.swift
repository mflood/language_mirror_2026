//
//  WaveformPlaceholderView.swift
//  LanguageMirror
//
//  Created by Matthew Flood on 9/15/25.
//

// path: Views/WaveformPlaceholderView.swift
import UIKit

/// A lightweight, synthetic waveform placeholder with draggable start/end handles.
/// Selection is reported in milliseconds via `onSelectionChanged`.
final class WaveformPlaceholderView: UIView {

    // Public configuration
    var durationMs: Int = 60_000 { didSet { setNeedsLayout(); setNeedsDisplay() } }
    var startMs: Int = 1_000 { didSet { clampSelection(); syncUI() } }
    var endMs: Int = 4_000 { didSet { clampSelection(); syncUI() } }
    var minSpanMs: Int = 150
    var onSelectionChanged: ((Int, Int) -> Void)?

    // Subviews
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

        // Accessibility hints
        leftHandle.accessibilityLabel = "Segment start"
        rightHandle.accessibilityLabel = "Segment end"
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layoutSubviews() {
        super.layoutSubviews()
        let rulerH: CGFloat = 18
        topRuler.frame = CGRect(x: 0, y: 0, width: bounds.width, height: rulerH)
        topRuler.durationMs = durationMs

        // Handles are 24pt wide hit areas with a 2pt center bar
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

        // Background gradient-ish bands
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
            let j = sin(t * .pi * 37) * jitter // little detail
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
    }

    // MARK: - Helpers

    private func syncUI() {
        setNeedsLayout()
    }

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
        // choose tick every 1s (coarse) with half ticks
        let pixelsPerSec = rect.width / CGFloat(totalSec)
        let major: Double = 1
        let minor: Double = 0.5

        // baseline
        ctx.move(to: CGPoint(x: 0, y: h-1)); ctx.addLine(to: CGPoint(x: rect.width, y: h-1)); ctx.strokePath()

        // ticks
        var t: Double = 0
        while t <= totalSec + 0.0001 {
            let x = CGFloat(t / totalSec) * rect.width
            let isMajor = (abs((t/major).rounded() - (t/major)) < 0.001)
            let length: CGFloat = isMajor ? h-2 : h-8
            ctx.move(to: CGPoint(x: x, y: h-1))
            ctx.addLine(to: CGPoint(x: x, y: h-length))
            ctx.strokePath()

            if isMajor {
                let label = String(format: "%.0fs", t)
                let attrs: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 10, weight: .regular),
                    .foregroundColor: UIColor.secondaryLabel
                ]
                let size = (label as NSString).size(withAttributes: attrs)
                (label as NSString).draw(at: CGPoint(x: x+2, y: h-size.height-2), withAttributes: attrs)
            }
            t += minor
        }
    }
}
