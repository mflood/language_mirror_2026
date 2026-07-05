//
//  CoverArtView.swift
//  LanguageMirror
//
//  A small square "cover" tile for a track/pack. Until packs ship real
//  cover images, this draws a distinctive branded gradient seeded from the
//  pack id (so a pack's tracks share a look and different packs differ),
//  with a soft waveform motif on top. If a real cover image is provided
//  later, it takes over.
//

import UIKit

final class CoverArtView: UIView {

    private let gradientLayer = CAGradientLayer()
    private let imageView = UIImageView()
    private let glyphView = UIImageView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        layer.cornerRadius = 10
        layer.cornerCurve = .continuous
        clipsToBounds = true
        backgroundColor = .clear

        gradientLayer.startPoint = CGPoint(x: 0, y: 0)
        gradientLayer.endPoint = CGPoint(x: 1, y: 1)
        layer.addSublayer(gradientLayer)

        glyphView.translatesAutoresizingMaskIntoConstraints = false
        glyphView.contentMode = .scaleAspectFit
        glyphView.tintColor = UIColor.white.withAlphaComponent(0.9)
        glyphView.image = UIImage(systemName: "waveform")
        glyphView.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 20, weight: .semibold)
        addSubview(glyphView)

        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFill
        imageView.isHidden = true
        addSubview(imageView)

        NSLayoutConstraint.activate([
            glyphView.centerXAnchor.constraint(equalTo: centerXAnchor),
            glyphView.centerYAnchor.constraint(equalTo: centerYAnchor),
            imageView.topAnchor.constraint(equalTo: topAnchor),
            imageView.leadingAnchor.constraint(equalTo: leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: trailingAnchor),
            imageView.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layoutSubviews() {
        super.layoutSubviews()
        gradientLayer.frame = bounds
    }

    /// Configure the generated cover from a stable seed (e.g. the pack id).
    /// `glyph` overrides the default waveform motif.
    func configure(seed: String, glyph: String? = nil) {
        imageView.isHidden = true
        glyphView.isHidden = false
        if let glyph { glyphView.image = UIImage(systemName: glyph) }

        let (top, bottom) = Self.gradientColors(for: seed)
        gradientLayer.colors = [top.cgColor, bottom.cgColor]
    }

    /// Deterministic two-stop gradient derived from the seed. Hues are pulled
    /// toward the brand's cool aqua/lavender range so covers feel on-brand
    /// while still varying pack to pack.
    private static func gradientColors(for seed: String) -> (UIColor, UIColor) {
        var hash: UInt64 = 1469598103934665603
        for byte in seed.utf8 {
            hash = (hash ^ UInt64(byte)) &* 1099511628257
        }
        // Base hue in the aqua→violet arc (0.45–0.75 of the wheel).
        let hue = 0.45 + (Double(hash % 300) / 1000.0)
        let hue2 = hue + 0.06
        let top = UIColor(hue: CGFloat(hue.truncatingRemainder(dividingBy: 1)),
                          saturation: 0.55, brightness: 0.85, alpha: 1)
        let bottom = UIColor(hue: CGFloat(hue2.truncatingRemainder(dividingBy: 1)),
                             saturation: 0.62, brightness: 0.70, alpha: 1)
        return (top, bottom)
    }
}
