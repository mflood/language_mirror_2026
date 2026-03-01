//
//  FavoriteCompactCell.swift
//  LanguageMirror
//

import UIKit

final class FavoriteCompactCell: UICollectionViewCell {

    // MARK: - Subviews

    private let cardView = UIView()
    private let trackTitleLabel = UILabel()
    private let practiceSetLabel = UILabel()
    private let heartImageView = UIImageView()
    private let chevronImageView = UIImageView()

    // MARK: - Init

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    // MARK: - Setup

    private func setupUI() {
        contentView.backgroundColor = .clear

        cardView.translatesAutoresizingMaskIntoConstraints = false
        cardView.backgroundColor = AppColors.cardBackground
        cardView.layer.cornerRadius = 12
        cardView.layer.cornerCurve = .continuous
        contentView.addSubview(cardView)

        trackTitleLabel.translatesAutoresizingMaskIntoConstraints = false
        trackTitleLabel.font = .systemFont(ofSize: 15, weight: .medium)
        trackTitleLabel.textColor = AppColors.primaryText
        trackTitleLabel.numberOfLines = 1
        cardView.addSubview(trackTitleLabel)

        practiceSetLabel.translatesAutoresizingMaskIntoConstraints = false
        practiceSetLabel.font = .systemFont(ofSize: 13, weight: .regular)
        practiceSetLabel.textColor = AppColors.secondaryText
        practiceSetLabel.numberOfLines = 1
        cardView.addSubview(practiceSetLabel)

        heartImageView.translatesAutoresizingMaskIntoConstraints = false
        heartImageView.image = UIImage(systemName: "heart.fill")
        heartImageView.tintColor = AppColors.errorColor
        heartImageView.contentMode = .scaleAspectFit
        cardView.addSubview(heartImageView)

        chevronImageView.translatesAutoresizingMaskIntoConstraints = false
        chevronImageView.image = UIImage(systemName: "chevron.right")
        chevronImageView.tintColor = AppColors.tertiaryText
        chevronImageView.contentMode = .scaleAspectFit
        cardView.addSubview(chevronImageView)

        NSLayoutConstraint.activate([
            cardView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 4),
            cardView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            cardView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            cardView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -4),

            chevronImageView.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -12),
            chevronImageView.centerYAnchor.constraint(equalTo: cardView.centerYAnchor),
            chevronImageView.widthAnchor.constraint(equalToConstant: 12),
            chevronImageView.heightAnchor.constraint(equalToConstant: 12),

            heartImageView.trailingAnchor.constraint(equalTo: chevronImageView.leadingAnchor, constant: -10),
            heartImageView.centerYAnchor.constraint(equalTo: cardView.centerYAnchor),
            heartImageView.widthAnchor.constraint(equalToConstant: 18),
            heartImageView.heightAnchor.constraint(equalToConstant: 18),

            trackTitleLabel.topAnchor.constraint(equalTo: cardView.topAnchor, constant: 10),
            trackTitleLabel.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 16),
            trackTitleLabel.trailingAnchor.constraint(lessThanOrEqualTo: heartImageView.leadingAnchor, constant: -8),

            practiceSetLabel.topAnchor.constraint(equalTo: trackTitleLabel.bottomAnchor, constant: 2),
            practiceSetLabel.leadingAnchor.constraint(equalTo: trackTitleLabel.leadingAnchor),
            practiceSetLabel.trailingAnchor.constraint(equalTo: trackTitleLabel.trailingAnchor),
            practiceSetLabel.bottomAnchor.constraint(equalTo: cardView.bottomAnchor, constant: -10),
        ])

        cardView.applyAdaptiveShadow(radius: 6, opacity: 0.08)
    }

    // MARK: - Configuration

    func configure(trackTitle: String, practiceSetTitle: String?) {
        trackTitleLabel.text = trackTitle
        practiceSetLabel.text = practiceSetTitle ?? "Practice Set"
    }

    // MARK: - Press animation

    override var isHighlighted: Bool {
        didSet {
            guard !UIAccessibility.isReduceMotionEnabled else { return }
            UIView.animate(
                withDuration: 0.25,
                delay: 0,
                usingSpringWithDamping: 0.7,
                initialSpringVelocity: 0.5,
                options: [.allowUserInteraction, .beginFromCurrentState]
            ) {
                self.cardView.transform = self.isHighlighted
                    ? CGAffineTransform(scaleX: 0.97, y: 0.97)
                    : .identity
                self.cardView.backgroundColor = self.isHighlighted
                    ? AppColors.accentGlow
                    : AppColors.cardBackground
            }

            if isHighlighted {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
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
