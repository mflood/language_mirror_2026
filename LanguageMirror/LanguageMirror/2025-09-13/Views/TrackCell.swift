//
//  TrackCell.swift
//  LanguageMirror
//
//  Created by Matthew Flood on 9/13/25.
//

import UIKit

/// ADHD-friendly track cell with visual richness, color coding, and smooth animations
final class TrackCell: UITableViewCell {
    
    // MARK: - Properties
    
    private let cardView = UIView()
    private let iconImageView = UIImageView()
    private let titleLabel = UILabel()
    private let durationBadge = DurationBadge()
    private let tagStackView = UIStackView()
    private let progressBar = UIProgressView()
    private let disclosureImageView = UIImageView()
    
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
        
        // Icon (audio wave symbol)
        iconImageView.translatesAutoresizingMaskIntoConstraints = false
        iconImageView.contentMode = .scaleAspectFit
        iconImageView.tintColor = AppColors.primaryAccent
        iconImageView.image = UIImage(systemName: "waveform")
        cardView.addSubview(iconImageView)
        
        // Title label
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = .systemFont(ofSize: 16, weight: .medium)
        titleLabel.textColor = AppColors.primaryText
        titleLabel.numberOfLines = 2
        cardView.addSubview(titleLabel)
        
        // Duration badge
        durationBadge.translatesAutoresizingMaskIntoConstraints = false
        cardView.addSubview(durationBadge)
        
        // Tag stack
        tagStackView.translatesAutoresizingMaskIntoConstraints = false
        tagStackView.axis = .horizontal
        tagStackView.spacing = 6
        tagStackView.distribution = .fillProportionally
        cardView.addSubview(tagStackView)
        
        // Progress bar (subtle at bottom)
        progressBar.translatesAutoresizingMaskIntoConstraints = false
        progressBar.progressTintColor = AppColors.primaryAccent
        progressBar.trackTintColor = AppColors.softSeparator
        progressBar.layer.cornerRadius = 2
        progressBar.clipsToBounds = true
        cardView.addSubview(progressBar)
        
        // Disclosure indicator
        disclosureImageView.translatesAutoresizingMaskIntoConstraints = false
        disclosureImageView.contentMode = .scaleAspectFit
        disclosureImageView.tintColor = AppColors.tertiaryText
        disclosureImageView.image = UIImage(systemName: "chevron.right")
        cardView.addSubview(disclosureImageView)
        
        // Layout
        NSLayoutConstraint.activate([
            // Card view with margins
            cardView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 6),
            cardView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            cardView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            cardView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -6),
            
            // Icon
            iconImageView.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 12),
            iconImageView.topAnchor.constraint(equalTo: cardView.topAnchor, constant: 12),
            iconImageView.widthAnchor.constraint(equalToConstant: 32),
            iconImageView.heightAnchor.constraint(equalToConstant: 32),
            
            // Title
            titleLabel.leadingAnchor.constraint(equalTo: iconImageView.trailingAnchor, constant: 12),
            titleLabel.topAnchor.constraint(equalTo: cardView.topAnchor, constant: 12),
            titleLabel.trailingAnchor.constraint(equalTo: durationBadge.leadingAnchor, constant: -8),
            
            // Duration badge
            durationBadge.trailingAnchor.constraint(equalTo: disclosureImageView.leadingAnchor, constant: -8),
            durationBadge.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),
            durationBadge.widthAnchor.constraint(greaterThanOrEqualToConstant: 50),
            
            // Disclosure
            disclosureImageView.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -12),
            disclosureImageView.centerYAnchor.constraint(equalTo: cardView.centerYAnchor),
            disclosureImageView.widthAnchor.constraint(equalToConstant: 12),
            disclosureImageView.heightAnchor.constraint(equalToConstant: 12),
            
            // Tag stack
            tagStackView.leadingAnchor.constraint(equalTo: iconImageView.trailingAnchor, constant: 12),
            tagStackView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            tagStackView.trailingAnchor.constraint(lessThanOrEqualTo: disclosureImageView.leadingAnchor, constant: -8),
            
            // Progress bar
            progressBar.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 12),
            progressBar.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -12),
            progressBar.topAnchor.constraint(equalTo: tagStackView.bottomAnchor, constant: 10),
            progressBar.bottomAnchor.constraint(equalTo: cardView.bottomAnchor, constant: -12),
            progressBar.heightAnchor.constraint(equalToConstant: 4)
        ])
        
        // Apply shadow
        cardView.applyAdaptiveShadow(radius: 8, opacity: 0.1)
    }
    
    // MARK: - Configuration
    
    func configure(with track: Track, progress: Float = 0.0) {
        titleLabel.text = track.title
        
        // Configure duration badge
        if let durationMs = track.durationMs {
            durationBadge.configure(durationMs: durationMs)
            durationBadge.isHidden = false
        } else {
            durationBadge.isHidden = true
        }
        
        // Configure tags (show up to 3)
        configureTags(track.tags)
        
        // Configure progress
        progressBar.progress = progress
        progressBar.isHidden = progress == 0.0
    }
    
    private func configureTags(_ tags: [String]) {
        // Clear existing tags
        tagStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
        
        let visibleTags = Array(tags.prefix(3))
        
        for tag in visibleTags {
            let tagView = TagView()
            tagView.configure(text: tag)
            tagStackView.addArrangedSubview(tagView)
        }
        
        // Add "+N more" if there are more tags
        if tags.count > 3 {
            let moreView = TagView()
            moreView.configure(text: "+\(tags.count - 3) more", isMore: true)
            tagStackView.addArrangedSubview(moreView)
        }
        
        tagStackView.isHidden = tags.isEmpty
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
                self.cardView.backgroundColor = highlighted
                    ? AppColors.accentGlow
                    : AppColors.cardBackground
            }
            
            // Haptic feedback
            if highlighted {
                let generator = UIImpactFeedbackGenerator(style: .light)
                generator.impactOccurred()
            }
        }
    }
    
    // MARK: - Highlight Animation
    
    /// Brief highlight animation to draw attention to the cell
    func highlightBriefly() {
        guard !UIAccessibility.isReduceMotionEnabled else { return }
        
        // Store original background color
        let originalBackground = cardView.backgroundColor
        
        // Brief highlight with success color
        UIView.animate(withDuration: 0.2, delay: 0, options: [.allowUserInteraction]) {
            self.cardView.backgroundColor = AppColors.successColor.withAlphaComponent(0.2)
        } completion: { _ in
            UIView.animate(withDuration: 0.3) {
                self.cardView.backgroundColor = originalBackground
            }
        }
        
        // Haptic feedback
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }
    
    // MARK: - Trait Collection
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        
        if traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
            cardView.updateAdaptiveShadowForAppearance()
        }
    }
}

// MARK: - Duration Badge

final class DurationBadge: UIView {
    
    private let label = UILabel()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        layer.cornerRadius = 8
        layer.cornerCurve = .continuous
        
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .monospacedDigitSystemFont(ofSize: 13, weight: .medium)
        label.textAlignment = .center
        addSubview(label)
        
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            label.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            label.topAnchor.constraint(equalTo: topAnchor, constant: 4),
            label.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -4)
        ])
    }
    
    func configure(durationMs: Int) {
        let totalSeconds = durationMs / 1000
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        label.text = String(format: "%d:%02d", minutes, seconds)
        
        // Color code by duration (ADHD-friendly visual system)
        if totalSeconds < 120 { // < 2 min (short)
            backgroundColor = AppColors.durationShortBackground
            label.textColor = AppColors.durationShort
        } else if totalSeconds < 300 { // 2-5 min (medium)
            backgroundColor = AppColors.durationMediumBackground
            label.textColor = AppColors.durationMedium
        } else { // 5+ min (long)
            backgroundColor = AppColors.durationLongBackground
            label.textColor = AppColors.durationLong
        }
    }
}

// MARK: - Tag View

final class TagView: UIView {
    
    private let label = UILabel()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        backgroundColor = AppColors.tertiaryBackground
        layer.cornerRadius = 6
        layer.cornerCurve = .continuous
        
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .systemFont(ofSize: 11, weight: .medium)
        label.textColor = AppColors.secondaryText
        addSubview(label)
        
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 6),
            label.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -6),
            label.topAnchor.constraint(equalTo: topAnchor, constant: 3),
            label.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -3)
        ])
    }
    
    func configure(text: String, isMore: Bool = false) {
        label.text = text
        if isMore {
            label.textColor = AppColors.tertiaryText
        }
    }
}

