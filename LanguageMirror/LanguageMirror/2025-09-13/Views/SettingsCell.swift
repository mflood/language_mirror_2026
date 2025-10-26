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
        selectionStyle = .none
        
        // Title label
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = .systemFont(ofSize: 17, weight: .regular)
        titleLabel.textColor = .label
        contentView.addSubview(titleLabel)
        
        // Value label (for steppers and other controls that need value display)
        valueLabel.translatesAutoresizingMaskIntoConstraints = false
        valueLabel.font = .systemFont(ofSize: 15, weight: .medium)
        valueLabel.textColor = .secondaryLabel
        valueLabel.textAlignment = .right
        contentView.addSubview(valueLabel)
        
        // Control container
        controlContainerView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(controlContainerView)
        
        NSLayoutConstraint.activate([
            // Title label
            titleLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            titleLabel.trailingAnchor.constraint(equalTo: valueLabel.leadingAnchor, constant: -8),
            
            // Value label (for steppers)
            valueLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            valueLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            valueLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 60),
            
            // Control container
            controlContainerView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            controlContainerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            controlContainerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            controlContainerView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -12),
            controlContainerView.heightAnchor.constraint(greaterThanOrEqualToConstant: 30)
        ])
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
            // No longer needed with flat design
        }
    }
}

