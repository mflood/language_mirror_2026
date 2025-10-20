//
//  SettingsCell.swift
//  LanguageMirror
//
//  Created by Matthew Flood on 9/13/25.
//

import UIKit

/// ADHD-friendly settings cell with colorful icons, clear visual hierarchy, and support for various controls
final class SettingsCell: UITableViewCell {
    
    // MARK: - Properties
    
    private let cardView = UIView()
    private let iconContainerView = UIView()
    private let iconImageView = UIImageView()
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
        
        // Icon container (circular background)
        iconContainerView.translatesAutoresizingMaskIntoConstraints = false
        iconContainerView.layer.cornerRadius = 20
        iconContainerView.layer.cornerCurve = .continuous
        cardView.addSubview(iconContainerView)
        
        // Icon
        iconImageView.translatesAutoresizingMaskIntoConstraints = false
        iconImageView.contentMode = .scaleAspectFit
        iconImageView.tintColor = .white
        iconContainerView.addSubview(iconImageView)
        
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
            cardView.heightAnchor.constraint(greaterThanOrEqualToConstant: 72),
            
            // Icon container (circular)
            iconContainerView.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 12),
            iconContainerView.centerYAnchor.constraint(equalTo: cardView.centerYAnchor),
            iconContainerView.widthAnchor.constraint(equalToConstant: 40),
            iconContainerView.heightAnchor.constraint(equalToConstant: 40),
            
            // Icon (centered in container)
            iconImageView.centerXAnchor.constraint(equalTo: iconContainerView.centerXAnchor),
            iconImageView.centerYAnchor.constraint(equalTo: iconContainerView.centerYAnchor),
            iconImageView.widthAnchor.constraint(equalToConstant: 22),
            iconImageView.heightAnchor.constraint(equalToConstant: 22),
            
            // Title
            titleLabel.leadingAnchor.constraint(equalTo: iconContainerView.trailingAnchor, constant: 12),
            titleLabel.topAnchor.constraint(equalTo: cardView.topAnchor, constant: 14),
            
            // Value label
            valueLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            valueLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 3),
            valueLabel.bottomAnchor.constraint(lessThanOrEqualTo: cardView.bottomAnchor, constant: -14),
            
            // Control container (on the right side)
            controlContainerView.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -12),
            controlContainerView.centerYAnchor.constraint(equalTo: cardView.centerYAnchor),
            controlContainerView.leadingAnchor.constraint(greaterThanOrEqualTo: titleLabel.trailingAnchor, constant: 12)
        ])
        
        // Apply shadow
        cardView.applyAdaptiveShadow(radius: 8, opacity: 0.1)
    }
    
    // MARK: - Configuration
    
    func configure(
        title: String,
        value: String,
        iconName: String,
        iconColor: UIColor,
        control: UIView? = nil
    ) {
        titleLabel.text = title
        valueLabel.text = value
        iconImageView.image = UIImage(systemName: iconName)
        iconContainerView.backgroundColor = iconColor
        
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

