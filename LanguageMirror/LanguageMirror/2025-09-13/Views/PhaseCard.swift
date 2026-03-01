//
//  PhaseCard.swift
//  LanguageMirror
//
//  Created by Matthew Flood on 3/1/26.
//

import UIKit

final class PhaseCard: UIView {

    enum Phase {
        case start, ramp, end
    }

    var onSpeedChanged: ((Float) -> Void)?
    var onRepeatsChanged: ((Int) -> Void)?

    private let phase: Phase
    private let stripe = UIView()
    private let titleLabel = UILabel()
    private let contentStack = UIStackView()

    private var speedSlider: UISlider?
    private var speedValueLabel: UILabel?
    private var repeatsSlider: UISlider?
    private var repeatsValueLabel: UILabel?

    init(phase: Phase) {
        self.phase = phase
        super.init(frame: .zero)
        setupUI()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    // MARK: - Setup

    private func setupUI() {
        backgroundColor = AppColors.cardBackground
        layer.cornerRadius = 12
        layer.cornerCurve = .continuous
        applyAdaptiveShadow(radius: 6, opacity: 0.06)

        // Color stripe
        stripe.translatesAutoresizingMaskIntoConstraints = false
        stripe.backgroundColor = phaseColor
        stripe.layer.cornerRadius = 2
        addSubview(stripe)

        // Title
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = .systemFont(ofSize: 15, weight: .semibold)
        titleLabel.textColor = AppColors.primaryText
        titleLabel.text = phaseTitle
        addSubview(titleLabel)

        // Content stack
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        contentStack.axis = .vertical
        contentStack.spacing = 12
        addSubview(contentStack)

        NSLayoutConstraint.activate([
            stripe.leadingAnchor.constraint(equalTo: leadingAnchor),
            stripe.topAnchor.constraint(equalTo: topAnchor),
            stripe.bottomAnchor.constraint(equalTo: bottomAnchor),
            stripe.widthAnchor.constraint(equalToConstant: 4),

            titleLabel.topAnchor.constraint(equalTo: topAnchor, constant: 12),
            titleLabel.leadingAnchor.constraint(equalTo: stripe.trailingAnchor, constant: 12),
            titleLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),

            contentStack.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 10),
            contentStack.leadingAnchor.constraint(equalTo: stripe.trailingAnchor, constant: 12),
            contentStack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            contentStack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -12),
        ])

        // Add controls based on phase
        switch phase {
        case .start:
            addSpeedRow(min: 0.3, max: 1.0)
            addRepeatsRow()
        case .ramp:
            addRepeatsRow()
        case .end:
            addSpeedRow(min: 0.5, max: 3.0)
            addRepeatsRow()
        }
    }

    // MARK: - Rows

    private func addSpeedRow(min: Float, max: Float) {
        let row = UIView()
        row.translatesAutoresizingMaskIntoConstraints = false

        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = "Speed"
        label.font = .systemFont(ofSize: 13, weight: .medium)
        label.textColor = AppColors.secondaryText
        row.addSubview(label)

        let valueLabel = UILabel()
        valueLabel.translatesAutoresizingMaskIntoConstraints = false
        valueLabel.font = .monospacedSystemFont(ofSize: 13, weight: .semibold)
        valueLabel.textColor = phaseColor
        valueLabel.textAlignment = .right
        row.addSubview(valueLabel)
        self.speedValueLabel = valueLabel

        let slider = UISlider()
        slider.translatesAutoresizingMaskIntoConstraints = false
        slider.minimumValue = min
        slider.maximumValue = max
        slider.minimumTrackTintColor = phaseColor
        slider.addTarget(self, action: #selector(speedSliderChanged(_:)), for: .valueChanged)
        row.addSubview(slider)
        self.speedSlider = slider

        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: row.topAnchor),
            label.leadingAnchor.constraint(equalTo: row.leadingAnchor),

            valueLabel.topAnchor.constraint(equalTo: row.topAnchor),
            valueLabel.trailingAnchor.constraint(equalTo: row.trailingAnchor),
            valueLabel.leadingAnchor.constraint(greaterThanOrEqualTo: label.trailingAnchor, constant: 8),

            slider.topAnchor.constraint(equalTo: label.bottomAnchor, constant: 4),
            slider.leadingAnchor.constraint(equalTo: row.leadingAnchor),
            slider.trailingAnchor.constraint(equalTo: row.trailingAnchor),
            slider.bottomAnchor.constraint(equalTo: row.bottomAnchor),
        ])

        contentStack.addArrangedSubview(row)
    }

    private func addRepeatsRow() {
        let row = UIView()
        row.translatesAutoresizingMaskIntoConstraints = false

        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = phase == .ramp ? "Ramp Steps" : "Repeats"
        label.font = .systemFont(ofSize: 13, weight: .medium)
        label.textColor = AppColors.secondaryText
        row.addSubview(label)

        let valueLabel = UILabel()
        valueLabel.translatesAutoresizingMaskIntoConstraints = false
        valueLabel.font = .monospacedSystemFont(ofSize: 13, weight: .semibold)
        valueLabel.textColor = phaseColor
        valueLabel.textAlignment = .right
        row.addSubview(valueLabel)
        self.repeatsValueLabel = valueLabel

        let slider = UISlider()
        slider.translatesAutoresizingMaskIntoConstraints = false
        slider.minimumValue = 1
        slider.maximumValue = 100
        slider.minimumTrackTintColor = phaseColor
        slider.addTarget(self, action: #selector(repeatsSliderChanged(_:)), for: .valueChanged)
        row.addSubview(slider)
        self.repeatsSlider = slider

        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: row.topAnchor),
            label.leadingAnchor.constraint(equalTo: row.leadingAnchor),

            valueLabel.topAnchor.constraint(equalTo: row.topAnchor),
            valueLabel.trailingAnchor.constraint(equalTo: row.trailingAnchor),
            valueLabel.leadingAnchor.constraint(greaterThanOrEqualTo: label.trailingAnchor, constant: 8),

            slider.topAnchor.constraint(equalTo: label.bottomAnchor, constant: 4),
            slider.leadingAnchor.constraint(equalTo: row.leadingAnchor),
            slider.trailingAnchor.constraint(equalTo: row.trailingAnchor),
            slider.bottomAnchor.constraint(equalTo: row.bottomAnchor),
        ])

        contentStack.addArrangedSubview(row)
    }

    // MARK: - Configuration

    func configure(speed: Float?, repeats: Int) {
        if let speed = speed {
            speedSlider?.value = speed
            speedValueLabel?.text = String(format: "%.1fx", speed)
        }
        repeatsSlider?.value = Float(repeats)
        repeatsValueLabel?.text = "\(repeats)x"
    }

    // MARK: - Actions

    @objc private func speedSliderChanged(_ slider: UISlider) {
        let stepped = Float(round(slider.value * 10) / 10)
        slider.value = stepped
        speedValueLabel?.text = String(format: "%.1fx", stepped)
        onSpeedChanged?(stepped)
    }

    @objc private func repeatsSliderChanged(_ slider: UISlider) {
        let value = Int(slider.value)
        repeatsValueLabel?.text = "\(value)x"
        onRepeatsChanged?(value)
    }

    // MARK: - Helpers

    private var phaseColor: UIColor {
        switch phase {
        case .start: return AppColors.durationShort
        case .ramp:  return AppColors.durationMedium
        case .end:   return AppColors.durationLong
        }
    }

    private var phaseTitle: String {
        switch phase {
        case .start: return "Start Phase"
        case .ramp:  return "Ramp Phase"
        case .end:   return "End Phase"
        }
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
            applyAdaptiveShadow(radius: 6, opacity: 0.06)
        }
    }
}
