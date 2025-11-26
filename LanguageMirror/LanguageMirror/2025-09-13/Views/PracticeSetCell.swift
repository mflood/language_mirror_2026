//
//  PracticeSetCell.swift
//  LanguageMirror
//
//  Created by Cursor on 11/26/25.
//

import UIKit

protocol PracticeSetCellDelegate: AnyObject {
    func practiceSetCellDidTapFavorite(_ cell: PracticeSetCell)
}

/// ADHD-friendly practice set cell with a visible favorite heart button
final class PracticeSetCell: UITableViewCell {
    
    weak var delegate: PracticeSetCellDelegate?
    
    // MARK: - Subviews
    
    private let cardView = UIView()
    private let titleLabel = UILabel()
    private let detailLabel = UILabel()
    private let badgeStackView = UIStackView()
    private let favoriteButton = UIButton(type: .system)
    
    private var isFavorite: Bool = false
    
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
        
        // Card container
        cardView.translatesAutoresizingMaskIntoConstraints = false
        cardView.backgroundColor = AppColors.cardBackground
        cardView.layer.cornerRadius = 12
        cardView.layer.cornerCurve = .continuous
        contentView.addSubview(cardView)
        
        // Title
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = .systemFont(ofSize: 16, weight: .medium)
        titleLabel.textColor = AppColors.primaryText
        titleLabel.numberOfLines = 2
        cardView.addSubview(titleLabel)
        
        // Detail
        detailLabel.translatesAutoresizingMaskIntoConstraints = false
        detailLabel.font = .systemFont(ofSize: 13, weight: .regular)
        detailLabel.textColor = AppColors.secondaryText
        detailLabel.numberOfLines = 2
        cardView.addSubview(detailLabel)
        
        // Badges for quick visual stats
        badgeStackView.translatesAutoresizingMaskIntoConstraints = false
        badgeStackView.axis = .horizontal
        badgeStackView.spacing = 6
        badgeStackView.distribution = .fillProportionally
        cardView.addSubview(badgeStackView)
        
        // Favorite button
        favoriteButton.translatesAutoresizingMaskIntoConstraints = false
        favoriteButton.tintColor = AppColors.secondaryText
        favoriteButton.contentHorizontalAlignment = .center
        favoriteButton.contentVerticalAlignment = .center
        favoriteButton.addTarget(self, action: #selector(favoriteTapped), for: .touchUpInside)
        cardView.addSubview(favoriteButton)
        
        // Layout
        NSLayoutConstraint.activate([
            // Card insets
            cardView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 6),
            cardView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            cardView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            cardView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -6),
            
            // Favorite button (ensure at least 44x44 hit area)
            favoriteButton.centerYAnchor.constraint(equalTo: cardView.centerYAnchor),
            favoriteButton.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -12),
            favoriteButton.widthAnchor.constraint(greaterThanOrEqualToConstant: 44),
            favoriteButton.heightAnchor.constraint(greaterThanOrEqualToConstant: 44),
            
            // Title
            titleLabel.topAnchor.constraint(equalTo: cardView.topAnchor, constant: 12),
            titleLabel.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 16),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: favoriteButton.leadingAnchor, constant: -8),
            
            // Detail
            detailLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 6),
            detailLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            detailLabel.trailingAnchor.constraint(lessThanOrEqualTo: favoriteButton.leadingAnchor, constant: -8),
            
            // Badges
            badgeStackView.topAnchor.constraint(equalTo: detailLabel.bottomAnchor, constant: 6),
            badgeStackView.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            badgeStackView.trailingAnchor.constraint(lessThanOrEqualTo: favoriteButton.leadingAnchor, constant: -8),
            badgeStackView.bottomAnchor.constraint(equalTo: cardView.bottomAnchor, constant: -10)
        ])
        
        cardView.applyAdaptiveShadow(radius: 8, opacity: 0.1)
    }
    
    // MARK: - Configuration
    
    func configure(title: String, clipCount: Int, drillCount: Int, isFavorite: Bool) {
        titleLabel.text = title
        detailLabel.text = "\(clipCount) clips • \(drillCount) drills"
        self.isFavorite = isFavorite
        configureBadges(clipCount: clipCount, drillCount: drillCount)
        updateFavoriteAppearance(animated: false)
    }
    
    private func configureBadges(clipCount: Int, drillCount: Int) {
        // Clear any existing badges
        badgeStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
        
        // Clip count badge
        if clipCount > 0 {
            let clipsTag = TagView()
            clipsTag.configure(text: "\(clipCount) clips")
            badgeStackView.addArrangedSubview(clipsTag)
        }
        
        // Drill count badge
        if drillCount > 0 {
            let drillsTag = TagView()
            drillsTag.configure(text: "\(drillCount) drills")
            badgeStackView.addArrangedSubview(drillsTag)
        }
        
        badgeStackView.isHidden = badgeStackView.arrangedSubviews.isEmpty
    }
    
    // MARK: - Actions
    
    @objc private func favoriteTapped() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
        
        // Optimistically toggle UI state; model is updated by delegate callback.
        isFavorite.toggle()
        updateFavoriteAppearance(animated: true)
        
        delegate?.practiceSetCellDidTapFavorite(self)
    }
    
    private func updateFavoriteAppearance(animated: Bool) {
        let imageName = isFavorite ? "heart.fill" : "heart"
        let tint = isFavorite ? AppColors.errorColor : AppColors.secondaryText
        
        let changes = {
            self.favoriteButton.setImage(UIImage(systemName: imageName), for: .normal)
            self.favoriteButton.tintColor = tint
        }
        
        guard animated, !UIAccessibility.isReduceMotionEnabled else {
            changes()
            return
        }
        
        UIView.animate(withDuration: 0.2,
                       delay: 0,
                       usingSpringWithDamping: 0.7,
                       initialSpringVelocity: 0.5,
                       options: [.allowUserInteraction, .beginFromCurrentState],
                       animations: {
            self.favoriteButton.transform = CGAffineTransform(scaleX: 1.15, y: 1.15)
            changes()
        }, completion: { _ in
            UIView.animate(withDuration: 0.15) {
                self.favoriteButton.transform = .identity
            }
        })
    }
    
    // MARK: - Highlight animation
    
    override func setHighlighted(_ highlighted: Bool, animated: Bool) {
        super.setHighlighted(highlighted, animated: animated)
        
        guard animated else {
            cardView.backgroundColor = AppColors.cardBackground
            cardView.transform = .identity
            return
        }
        
        let animations = {
            self.cardView.transform = highlighted
                ? CGAffineTransform(scaleX: 0.97, y: 0.97)
                : .identity
            self.cardView.backgroundColor = highlighted
                ? AppColors.accentGlow
                : AppColors.cardBackground
        }
        
        if UIAccessibility.isReduceMotionEnabled {
            animations()
        } else {
            UIView.animate(withDuration: 0.2,
                           delay: 0,
                           usingSpringWithDamping: 0.7,
                           initialSpringVelocity: 0.5,
                           options: [.allowUserInteraction, .beginFromCurrentState],
                           animations: animations,
                           completion: nil)
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


