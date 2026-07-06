//
//  ImportOptionCell.swift
//  LanguageMirror
//
//  Created by Matthew Flood on 9/13/25.
//

import UIKit

/// ADHD-friendly import option cell with large icons and clear visual hierarchy
final class ImportOptionCell: UITableViewCell {
    
    // MARK: - Properties
    
    private let cardView = UIView()
    private let iconContainerView = UIView()
    private let goldGradient = CAGradientLayer()
    private let iconImageView = UIImageView()
    private let titleLabel = UILabel()
    private let descriptionLabel = UILabel()
    private let chevronImageView = UIImageView()
    
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
        
        // Icon medallion — engraved gold glyph in a hairline gold ring on
        // the plum field, replacing the old candy-colored circles.
        iconContainerView.translatesAutoresizingMaskIntoConstraints = false
        iconContainerView.layer.cornerRadius = 24
        iconContainerView.layer.cornerCurve = .continuous
        iconContainerView.backgroundColor = AppColors.primaryBackground
        iconContainerView.layer.borderWidth = 1.0 / UIScreen.main.scale
        iconContainerView.layer.borderColor = AppColors.goldHairline.cgColor
        iconContainerView.clipsToBounds = true
        cardView.addSubview(iconContainerView)

        // Coined-metal inner gradient for the featured (gold) medallion:
        // a soft radial light falling from the upper left.
        goldGradient.type = .radial
        goldGradient.colors = [
            UIColor(red: 0.90, green: 0.76, blue: 0.48, alpha: 1).cgColor,
            UIColor(red: 0.78, green: 0.62, blue: 0.34, alpha: 1).cgColor,
            UIColor(red: 0.60, green: 0.45, blue: 0.22, alpha: 1).cgColor,
        ]
        goldGradient.locations = [0, 0.55, 1]
        goldGradient.startPoint = CGPoint(x: 0.35, y: 0.28)
        goldGradient.endPoint = CGPoint(x: 1.25, y: 1.25)
        goldGradient.isHidden = true
        iconContainerView.layer.insertSublayer(goldGradient, at: 0)

        // Icon
        iconImageView.translatesAutoresizingMaskIntoConstraints = false
        iconImageView.contentMode = .scaleAspectFit
        iconImageView.tintColor = AppColors.antiqueGold
        iconContainerView.addSubview(iconImageView)
        
        // Title label
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = .systemFont(ofSize: 17, weight: .semibold)
        titleLabel.textColor = AppColors.primaryText
        titleLabel.numberOfLines = 1
        cardView.addSubview(titleLabel)
        
        // Description label
        descriptionLabel.translatesAutoresizingMaskIntoConstraints = false
        descriptionLabel.font = .systemFont(ofSize: 14, weight: .regular)
        descriptionLabel.textColor = AppColors.secondaryText
        descriptionLabel.numberOfLines = 2
        cardView.addSubview(descriptionLabel)
        
        // Chevron
        chevronImageView.translatesAutoresizingMaskIntoConstraints = false
        chevronImageView.contentMode = .scaleAspectFit
        chevronImageView.tintColor = AppColors.tertiaryText
        chevronImageView.image = UIImage(systemName: "chevron.right")
        cardView.addSubview(chevronImageView)
        
        // Layout
        NSLayoutConstraint.activate([
            // Card view with margins
            cardView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 6),
            cardView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            cardView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            cardView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -6),
            cardView.heightAnchor.constraint(greaterThanOrEqualToConstant: 76),
            
            // Icon container (circular, larger for impact)
            iconContainerView.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 12),
            iconContainerView.centerYAnchor.constraint(equalTo: cardView.centerYAnchor),
            iconContainerView.widthAnchor.constraint(equalToConstant: 48),
            iconContainerView.heightAnchor.constraint(equalToConstant: 48),
            
            // Icon (centered in container — painted charms get most of the medallion)
            iconImageView.centerXAnchor.constraint(equalTo: iconContainerView.centerXAnchor),
            iconImageView.centerYAnchor.constraint(equalTo: iconContainerView.centerYAnchor),
            iconImageView.widthAnchor.constraint(equalToConstant: 38),
            iconImageView.heightAnchor.constraint(equalToConstant: 38),
            
            // Title
            titleLabel.leadingAnchor.constraint(equalTo: iconContainerView.trailingAnchor, constant: 16),
            titleLabel.topAnchor.constraint(equalTo: cardView.topAnchor, constant: 16),
            titleLabel.trailingAnchor.constraint(equalTo: chevronImageView.leadingAnchor, constant: -12),
            
            // Description
            descriptionLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            descriptionLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),
            descriptionLabel.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor),
            descriptionLabel.bottomAnchor.constraint(lessThanOrEqualTo: cardView.bottomAnchor, constant: -16),
            
            // Chevron
            chevronImageView.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -16),
            chevronImageView.centerYAnchor.constraint(equalTo: cardView.centerYAnchor),
            chevronImageView.widthAnchor.constraint(equalToConstant: 12),
            chevronImageView.heightAnchor.constraint(equalToConstant: 12)
        ])
        
        // Apply shadow
        cardView.applyAdaptiveShadow(radius: 8, opacity: 0.1)
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        goldGradient.frame = iconContainerView.bounds
        CATransaction.commit()
    }

    // MARK: - Configuration

    func configure(title: String, description: String, glyph: UIImage?, prominent: Bool = false) {
        titleLabel.text = title
        descriptionLabel.text = description
        iconImageView.image = glyph
        // Medallion grounds are FIXED colors in both appearances: the charms
        // are painted against deep plum, so a dynamic light-mode ground
        // exposes their baked-in shadow edges, and a dynamic dark-mode
        // ground matches the field and swallows them.
        if prominent {
            // Filled-gold medallion — the one "start here" row. Rich fixed
            // gold under a coined-metal radial gradient.
            iconContainerView.backgroundColor = UIColor(red: 0.78, green: 0.62, blue: 0.34, alpha: 1)
            iconContainerView.layer.borderWidth = 0
            goldGradient.isHidden = false
        } else {
            iconContainerView.backgroundColor = UIColor(red: 0.13, green: 0.09, blue: 0.12, alpha: 1)  // deep plum shadowbox
            iconContainerView.layer.borderWidth = 1.0 / UIScreen.main.scale
            iconContainerView.layer.borderColor = AppColors.goldHairline.cgColor
            goldGradient.isHidden = true
        }
    }
    
    // MARK: - Animations
    
    override func setHighlighted(_ highlighted: Bool, animated: Bool) {
        super.setHighlighted(highlighted, animated: animated)
        
        if animated {
            UIView.animate(
                withDuration: 0.3,
                delay: 0,
                usingSpringWithDamping: 0.7,
                initialSpringVelocity: 0.5,
                options: [.allowUserInteraction, .beginFromCurrentState]
            ) {
                self.cardView.transform = highlighted
                    ? CGAffineTransform(scaleX: 0.97, y: 0.97)
                    : .identity
                
                // Subtle glow on press
                if highlighted {
                    self.cardView.layer.shadowOpacity = 0.15
                } else {
                    self.cardView.layer.shadowOpacity = 0.1
                }
            }
            
            // Haptic feedback
            if highlighted {
                let generator = UIImpactFeedbackGenerator(style: .light)
                generator.impactOccurred()
            }
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

