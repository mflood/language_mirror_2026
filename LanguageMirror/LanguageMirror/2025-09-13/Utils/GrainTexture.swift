//
//  GrainTexture.swift
//  LanguageMirror
//
//  The matte paper grain of the Six Wands museum-plate language (see
//  brand/miri/): an almost-subliminal noise field laid over the plum
//  background, UNDER the content, so screens read as hand-tinted paper
//  rather than flat digital color. Deterministic (seeded) so the paper
//  is the same on every launch.
//

import UIKit

enum GrainTexture {

    /// A 128pt tiling noise image. Sparse gray speckles at varying
    /// brightness — reads as paper tooth on both plum-dusk and
    /// morning-fog fields.
    static let tile: UIImage = {
        let side = 128
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: side, height: side))
        return renderer.image { ctx in
            var state: UInt64 = 0x5157414E4453  // seeded — same paper every launch
            func next() -> UInt64 {
                state &+= 0x9E3779B97F4A7C15
                var z = state
                z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
                z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
                return z ^ (z >> 31)
            }
            // ~12% of pixels get a speckle.
            for y in 0..<side {
                for x in 0..<side {
                    let r = next()
                    guard r % 100 < 12 else { continue }
                    let white = CGFloat((r >> 8) % 100) / 100.0        // 0…1 gray
                    let alpha = 0.5 + CGFloat((r >> 16) % 50) / 100.0  // 0.5…1
                    ctx.cgContext.setFillColor(UIColor(white: white, alpha: alpha).cgColor)
                    ctx.cgContext.fill(CGRect(x: x, y: y, width: 1, height: 1))
                }
            }
        }
    }()
}

extension UIView {
    /// Insert the grain field just above this view's background color and
    /// below all content. Call once from viewDidLoad after the background
    /// color is set.
    func addGrainField(alpha: CGFloat = 0.035) {
        let grain = UIView()
        grain.translatesAutoresizingMaskIntoConstraints = false
        grain.backgroundColor = UIColor(patternImage: GrainTexture.tile)
        grain.alpha = alpha
        grain.isUserInteractionEnabled = false
        insertSubview(grain, at: 0)
        NSLayoutConstraint.activate([
            grain.topAnchor.constraint(equalTo: topAnchor),
            grain.bottomAnchor.constraint(equalTo: bottomAnchor),
            grain.leadingAnchor.constraint(equalTo: leadingAnchor),
            grain.trailingAnchor.constraint(equalTo: trailingAnchor),
        ])
    }
}
