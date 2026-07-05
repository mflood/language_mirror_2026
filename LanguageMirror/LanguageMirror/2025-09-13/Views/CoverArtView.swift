//
//  CoverArtView.swift
//  LanguageMirror
//
//  A small square "cover" tile for a track/pack, painted as a Six Wands
//  museum plate: a miniature misty ink-wash landscape (moon, layered
//  mountain ridges, fog) in the plum/lavender palette inside a hairline
//  gold frame. Seeded from the pack id so a pack's tracks share a
//  landscape and different packs differ. If a real cover image is
//  provided later, it takes over.
//

import UIKit

final class CoverArtView: UIView {

    private let imageView = UIImageView()
    private var seedHash: UInt64 = 0x6d697269  // "miri"

    override init(frame: CGRect) {
        super.init(frame: frame)
        layer.cornerRadius = 10
        layer.cornerCurve = .continuous
        clipsToBounds = true
        backgroundColor = .clear
        contentMode = .redraw
        isOpaque = false

        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFill
        imageView.isHidden = true
        addSubview(imageView)

        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: topAnchor),
            imageView.leadingAnchor.constraint(equalTo: leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: trailingAnchor),
            imageView.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    /// Configure the painted cover from a stable seed (e.g. the pack id).
    /// `glyph` is accepted for API compatibility but the landscape plate
    /// no longer draws a symbol motif.
    func configure(seed: String, glyph: String? = nil) {
        imageView.isHidden = true
        var hash: UInt64 = 1469598103934665603
        for byte in seed.utf8 {
            hash = (hash ^ UInt64(byte)) &* 1099511628257
        }
        seedHash = hash
        setNeedsDisplay()
    }

    // MARK: - Painting

    private struct SplitMix64 {
        var state: UInt64
        mutating func next() -> UInt64 {
            state &+= 0x9E3779B97F4A7C15
            var z = state
            z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
            z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
            return z ^ (z >> 31)
        }
        mutating func next01() -> CGFloat { CGFloat(next() % 10_000) / 10_000 }
    }

    override func draw(_ rect: CGRect) {
        guard let ctx = UIGraphicsGetCurrentContext() else { return }
        var rng = SplitMix64(state: seedHash)
        let w = rect.width, h = rect.height

        // Sky: pale lavender fog fading down into plum; hue drifts per seed
        // between aqua-leaning and violet-leaning.
        let hue = 0.72 + rng.next01() * 0.14 - 0.07
        let skyTop = UIColor(hue: hue, saturation: 0.10, brightness: 0.86, alpha: 1)
        let skyBottom = UIColor(hue: hue, saturation: 0.30, brightness: 0.38, alpha: 1)
        let colors = [skyTop.cgColor, skyBottom.cgColor] as CFArray
        if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                     colors: colors, locations: [0, 1]) {
            ctx.drawLinearGradient(gradient,
                                   start: .zero,
                                   end: CGPoint(x: 0, y: h),
                                   options: [])
        }

        // Moon — a quiet pale disc in the upper sky.
        let moonR = w * 0.09
        let moonX = w * (0.22 + rng.next01() * 0.56)
        let moonY = h * (0.14 + rng.next01() * 0.14)
        UIColor(white: 0.97, alpha: 0.85).setFill()
        ctx.fillEllipse(in: CGRect(x: moonX - moonR, y: moonY - moonR,
                                   width: moonR * 2, height: moonR * 2))

        // Three mountain ridges, back to front, deepening plum.
        for i in 0..<3 {
            let fi = CGFloat(i)
            let baseY = h * (0.42 + 0.18 * fi)
            let ridge = UIBezierPath()
            ridge.move(to: CGPoint(x: 0, y: h))
            ridge.addLine(to: CGPoint(x: 0, y: baseY + h * 0.06 * (rng.next01() - 0.5)))
            let peaks = 2 + Int(rng.next() % 2)  // 2–3 peaks per ridge
            var x: CGFloat = 0
            for p in 0..<peaks {
                let nextX = w * (CGFloat(p) + 1) / CGFloat(peaks)
                let peakX = (x + nextX) / 2 + w * 0.10 * (rng.next01() - 0.5)
                let peakY = baseY - h * (0.14 + rng.next01() * 0.16)
                let endY = baseY + h * 0.05 * (rng.next01() - 0.5)
                // Steep karst silhouettes: straight strokes to sharp peaks
                ridge.addLine(to: CGPoint(x: peakX, y: peakY))
                ridge.addLine(to: CGPoint(x: nextX, y: endY))
                x = nextX
            }
            ridge.addLine(to: CGPoint(x: w, y: h))
            ridge.close()
            UIColor(hue: hue,
                    saturation: 0.24 + 0.10 * fi,
                    brightness: 0.60 - 0.14 * fi,
                    alpha: 0.92).setFill()
            ridge.fill()
        }

        // One quiet fog band lying between the ridges.
        UIColor(white: 0.95, alpha: 0.06).setFill()
        ctx.fill(CGRect(x: 0, y: h * 0.60, width: w, height: h * 0.07))

        // Hairline gold frame — the plate.
        let inset: CGFloat = 1.5
        let frame = UIBezierPath(roundedRect: rect.insetBy(dx: inset, dy: inset),
                                 cornerRadius: 8)
        frame.lineWidth = 1
        AppColors.antiqueGold.withAlphaComponent(0.55).setStroke()
        frame.stroke()
    }

    /// Show a real cover image instead of the painted plate.
    func setImage(_ image: UIImage) {
        imageView.image = image
        imageView.isHidden = false
    }
}
