//
//  AtmosphereBackdropView.swift
//  LanguageMirror
//
//  The Six Wands signature ground: a misty ink-wash mountain field, drawn
//  at SUBLIMINAL contrast so it reads as atmosphere behind content — not a
//  picture competing with text. This is what the brand mockups
//  (brand/miri/mockups/) promised and the flat plum fill never delivered.
//
//  Same ridge/moon/fog vocabulary as CoverArtView, but a fixed, calm
//  composition and everything kept within ~a few % of the base field
//  luminance so the plum world holds without hurting legibility. Includes
//  the paper grain, so it fully replaces addGrainField() on the screens
//  that use it (Library / Practice / Add).
//

import UIKit

final class AtmosphereBackdropView: UIView {

    init() {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        backgroundColor = .clear
        isUserInteractionEnabled = false
        contentMode = .redraw
        isOpaque = false
        registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (v: AtmosphereBackdropView, _) in
            v.setNeedsDisplay()
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func draw(_ rect: CGRect) {
        guard let ctx = UIGraphicsGetCurrentContext() else { return }
        let dark = traitCollection.userInterfaceStyle == .dark
        let w = rect.width, h = rect.height

        // Ridge ink. Ink-wash mountains read as MIST: in dark mode a plum
        // lifted above the field (ridges catch the moonlight); in light mode
        // a deeper mauve (ridges sit into the fog).
        let ridge = dark
            ? UIColor(red: 0.27, green: 0.21, blue: 0.27, alpha: 1)
            : UIColor(red: 0.58, green: 0.50, blue: 0.58, alpha: 1)

        // A faint moon high in the field.
        let moonR = w * 0.11
        let moonC = CGPoint(x: w * 0.74, y: h * 0.16)
        (dark ? UIColor(white: 0.85, alpha: 0.05) : UIColor(white: 1.0, alpha: 0.30)).setFill()
        ctx.fillEllipse(in: CGRect(x: moonC.x - moonR, y: moonC.y - moonR,
                                   width: moonR * 2, height: moonR * 2))

        // Two ridgelines rising from the lower third — a fixed, calm skyline.
        // Peaks are gentle; the whole field never rises above ~55% height.
        let ridgelines: [(baseFrac: CGFloat, peaks: [(CGFloat, CGFloat)], alpha: CGFloat)] = [
            (0.72, [(0.14, 0.60), (0.40, 0.52), (0.66, 0.63), (0.88, 0.55)], dark ? 0.22 : 0.16),
            (0.84, [(0.24, 0.70), (0.52, 0.62), (0.80, 0.72)],               dark ? 0.30 : 0.22),
        ]
        for line in ridgelines {
            let p = UIBezierPath()
            p.move(to: CGPoint(x: 0, y: h))
            p.addLine(to: CGPoint(x: 0, y: h * line.baseFrac))
            for (fx, fy) in line.peaks {
                p.addLine(to: CGPoint(x: w * fx, y: h * fy))
                p.addLine(to: CGPoint(x: w * (fx + 0.12), y: h * line.baseFrac))
            }
            p.addLine(to: CGPoint(x: w, y: h * line.baseFrac))
            p.addLine(to: CGPoint(x: w, y: h))
            p.close()
            ridge.withAlphaComponent(line.alpha).setFill()
            p.fill()
        }

        // A soft fog band lying across the ridges' feet.
        (dark ? UIColor(white: 0.9, alpha: 0.03) : UIColor(white: 1.0, alpha: 0.10)).setFill()
        ctx.fill(CGRect(x: 0, y: h * 0.74, width: w, height: h * 0.06))

        // Paper grain over the whole field (replaces addGrainField here).
        UIColor(patternImage: GrainTexture.tile).withAlphaComponent(0.035).setFill()
        ctx.fill(rect)
    }
}

extension UIView {
    /// Install the ink-wash atmosphere backdrop above the background color and
    /// below all content (the Six Wands signature ground). Replaces
    /// addGrainField() on the screens that use it — the backdrop draws grain too.
    func addAtmosphereBackdrop() {
        let backdrop = AtmosphereBackdropView()
        insertSubview(backdrop, at: 0)
        NSLayoutConstraint.activate([
            backdrop.topAnchor.constraint(equalTo: topAnchor),
            backdrop.bottomAnchor.constraint(equalTo: bottomAnchor),
            backdrop.leadingAnchor.constraint(equalTo: leadingAnchor),
            backdrop.trailingAnchor.constraint(equalTo: trailingAnchor),
        ])
    }
}
