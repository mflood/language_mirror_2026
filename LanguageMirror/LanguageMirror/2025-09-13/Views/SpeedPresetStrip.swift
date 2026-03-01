//
//  SpeedPresetStrip.swift
//  LanguageMirror
//
//  Created by Matthew Flood on 3/1/26.
//

import UIKit

protocol SpeedPresetStripDelegate: AnyObject {
    func speedPresetStrip(_ strip: SpeedPresetStrip, didSelectSpeed speed: Float)
}

final class SpeedPresetStrip: UIView {

    weak var delegate: SpeedPresetStripDelegate?

    private let scrollView = UIScrollView()
    private let stackView = UIStackView()
    private var buttons: [UIButton] = []
    private var speeds: [Float] = []
    private var selectedSpeed: Float = 1.0
    private let feedbackGenerator = UISelectionFeedbackGenerator()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func setupUI() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.alwaysBounceHorizontal = true
        addSubview(scrollView)

        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.axis = .horizontal
        stackView.spacing = 8
        stackView.alignment = .center
        scrollView.addSubview(stackView)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor),

            stackView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            stackView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor, constant: 16),
            stackView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor, constant: -16),
            stackView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            stackView.heightAnchor.constraint(equalTo: scrollView.frameLayoutGuide.heightAnchor),
        ])
    }

    func configure(speeds: [Float], selected: Float) {
        self.speeds = speeds
        self.selectedSpeed = selected
        rebuildButtons()
    }

    func updateSelection(_ speed: Float) {
        selectedSpeed = speed
        applySelectionStyle()
    }

    private func rebuildButtons() {
        stackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
        buttons.removeAll()

        for speed in speeds {
            let btn = makePill(speed: speed)
            stackView.addArrangedSubview(btn)
            buttons.append(btn)
        }
        applySelectionStyle()
    }

    private func makePill(speed: Float) -> UIButton {
        let btn = UIButton(type: .system)
        let title = speed == Float(Int(speed)) ? String(format: "%.0fx", speed) : String(format: "%.1fx", speed)
        btn.setTitle(title, for: .normal)
        btn.titleLabel?.font = .systemFont(ofSize: 14, weight: .semibold)
        btn.layer.cornerRadius = 16
        btn.clipsToBounds = true
        btn.contentEdgeInsets = UIEdgeInsets(top: 6, left: 12, bottom: 6, right: 12)
        btn.heightAnchor.constraint(equalToConstant: 32).isActive = true
        btn.tag = Int(speed * 100) // encode speed as tag
        btn.addTarget(self, action: #selector(pillTapped(_:)), for: .touchUpInside)
        return btn
    }

    private func applySelectionStyle() {
        for (i, btn) in buttons.enumerated() {
            let isSelected = speeds[i] == selectedSpeed
            btn.backgroundColor = isSelected ? AppColors.primaryAccent : AppColors.tertiaryBackground
            btn.setTitleColor(isSelected ? .white : AppColors.primaryText, for: .normal)
        }
    }

    @objc private func pillTapped(_ sender: UIButton) {
        let speed = Float(sender.tag) / 100.0
        selectedSpeed = speed
        applySelectionStyle()
        feedbackGenerator.selectionChanged()
        delegate?.speedPresetStrip(self, didSelectSpeed: speed)
    }
}
