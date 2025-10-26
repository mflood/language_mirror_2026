//
//  SettingsCell.swift
//  LanguageMirror
//
//  Created by Matthew Flood on 9/13/25.
//

import UIKit

/// Clean settings cell with clear visual hierarchy and support for various controls
final class SettingsCell: UITableViewCell {
    
    // MARK: - Properties
    
    private let cardView = UIView()
    private let titleLabel = UILabel()
    private let valueLabel = UILabel()
    private let controlContainerView = UIView()
    
    // MARK: - Init
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Setup
    
    private func setupUI() {
        backgroundColor = .clear
        contentView.backgroundColor = .clear
        selectionStyle = .none
        
        // Card view with soft shadows
        cardView.translatesAutoresizingMaskIntoConstraints = false
        cardView.backgroundColor = AppColors.cardBackground
        cardView.layer.cornerRadius = 12
        cardView.layer.cornerCurve = .continuous
        contentView.addSubview(cardView)
        
        // Title label
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = .systemFont(ofSize: 16, weight: .semibold)
        titleLabel.textColor = AppColors.primaryText
        titleLabel.numberOfLines = 1
        cardView.addSubview(titleLabel)
        
        // Value label (shows current value)
        valueLabel.translatesAutoresizingMaskIntoConstraints = false
        valueLabel.font = .systemFont(ofSize: 13, weight: .medium)
        valueLabel.textColor = AppColors.secondaryText
        valueLabel.numberOfLines = 1
        cardView.addSubview(valueLabel)
        
        // Control container (for stepper, slider, switch, etc.)
        controlContainerView.translatesAutoresizingMaskIntoConstraints = false
        cardView.addSubview(controlContainerView)
        
        // Layout
        NSLayoutConstraint.activate([
            // Card view with margins
            cardView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 6),
            cardView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            cardView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            cardView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -6),
            cardView.heightAnchor.constraint(greaterThanOrEqualToConstant: 60),
            
            // Title
            titleLabel.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 16),
            titleLabel.topAnchor.constraint(equalTo: cardView.topAnchor, constant: 14),
            titleLabel.trailingAnchor.constraint(equalTo: valueLabel.leadingAnchor, constant: -8),
            
            // Value label (for steppers and sliders)
            valueLabel.topAnchor.constraint(equalTo: cardView.topAnchor, constant: 14),
            valueLabel.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -16),
            valueLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 60),
            
            // Control container (below the title/value row)
            controlContainerView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            controlContainerView.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 16),
            controlContainerView.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -16),
            controlContainerView.bottomAnchor.constraint(equalTo: cardView.bottomAnchor, constant: -12),
            controlContainerView.heightAnchor.constraint(greaterThanOrEqualToConstant: 30)
        ])
        
        // Apply shadow
        cardView.applyAdaptiveShadow(radius: 8, opacity: 0.1)
    }
    
    // MARK: - Configuration
    
    func configure(
        title: String,
        value: String?,
        control: UIView? = nil
    ) {
        titleLabel.text = title
        valueLabel.text = value
        valueLabel.isHidden = value == nil
        
        // Remove existing control
        controlContainerView.subviews.forEach { $0.removeFromSuperview() }
        
        // Add new control if provided
        if let control = control {
            control.translatesAutoresizingMaskIntoConstraints = false
            controlContainerView.addSubview(control)
            
            NSLayoutConstraint.activate([
                control.topAnchor.constraint(equalTo: controlContainerView.topAnchor),
                control.leadingAnchor.constraint(equalTo: controlContainerView.leadingAnchor),
                control.trailingAnchor.constraint(equalTo: controlContainerView.trailingAnchor),
                control.bottomAnchor.constraint(equalTo: controlContainerView.bottomAnchor)
            ])
        }
    }
    
    // Convenience method for backward compatibility
    func configure(
        title: String,
        value: String,
        control: UIView? = nil
    ) {
        configure(title: title, value: value as String?, control: control)
    }
    
    // Update just the value text (for animations)
    func updateValue(_ value: String, animated: Bool = true) {
        if animated {
            UIView.transition(
                with: valueLabel,
                duration: 0.2,
                options: .transitionCrossDissolve,
                animations: {
                    self.valueLabel.text = value
                }
            )
        } else {
            valueLabel.text = value
        }
    }
    
    // MARK: - Trait Collection
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        
        if traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
            cardView.updateAdaptiveShadowForAppearance()
        }
    }
}

