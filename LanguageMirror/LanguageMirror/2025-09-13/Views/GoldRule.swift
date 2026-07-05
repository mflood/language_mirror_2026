//
//  GoldRule.swift
//  LanguageMirror
//
//  The thin antique-gold rule line from the Six Wands museum-plate
//  language (see brand/miri/) — used under section captions and as a
//  quiet structural divider. Gold is structure, never decoration-noise:
//  keep these to section boundaries and signature cards.
//

import UIKit

final class GoldRule: UIView {

    init() {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        backgroundColor = AppColors.goldHairline
        heightAnchor.constraint(equalToConstant: 1.0 / UIScreen.main.scale).isActive = true
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}

extension UIView {
    /// Hairline antique-gold plate border — the museum-plate card
    /// treatment. Reserved for hero/resume moments, not list rows.
    /// Call once from setup; the border re-resolves on appearance changes.
    func applyGoldPlateBorder(cornerRadius: CGFloat = 12) {
        layer.cornerRadius = cornerRadius
        layer.cornerCurve = .continuous
        layer.borderWidth = 1.0 / UIScreen.main.scale
        layer.borderColor = AppColors.goldHairline.resolvedColor(with: traitCollection).cgColor
        registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (view: UIView, _) in
            view.layer.borderColor = AppColors.goldHairline
                .resolvedColor(with: view.traitCollection).cgColor
        }
    }
}
