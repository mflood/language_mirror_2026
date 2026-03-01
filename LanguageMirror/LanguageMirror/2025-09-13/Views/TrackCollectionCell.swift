//
//  TrackCollectionCell.swift
//  LanguageMirror
//

import UIKit

final class TrackCollectionCell: UICollectionViewCell {

    // MARK: - Subviews

    private let cardView = UIView()
    private let iconImageView = UIImageView()
    private let titleLabel = UILabel()
    private let durationBadge = DurationBadge()
    private let tagStackView = UIStackView()
    private let progressBar = UIProgressView()
    private let disclosureImageView = UIImageView()

    // MARK: - Init

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    // MARK: - Setup

    private func setupUI() {
        contentView.backgroundColor = .clear
        backgroundColor = .clear

        cardView.translatesAutoresizingMaskIntoConstraints = false
        cardView.backgroundColor = AppColors.cardBackground
        cardView.layer.cornerRadius = 12
        cardView.layer.cornerCurve = .continuous
        contentView.addSubview(cardView)

        iconImageView.translatesAutoresizingMaskIntoConstraints = false
        iconImageView.contentMode = .scaleAspectFit
        iconImageView.tintColor = AppColors.primaryAccent
        iconImageView.image = UIImage(systemName: "waveform")
        cardView.addSubview(iconImageView)

        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = .systemFont(ofSize: 16, weight: .medium)
        titleLabel.textColor = AppColors.primaryText
        titleLabel.numberOfLines = 2
        cardView.addSubview(titleLabel)

        durationBadge.translatesAutoresizingMaskIntoConstraints = false
        cardView.addSubview(durationBadge)

        tagStackView.translatesAutoresizingMaskIntoConstraints = false
        tagStackView.axis = .horizontal
        tagStackView.spacing = 6
        tagStackView.distribution = .fillProportionally
        cardView.addSubview(tagStackView)

        progressBar.translatesAutoresizingMaskIntoConstraints = false
        progressBar.progressTintColor = AppColors.primaryAccent
        progressBar.trackTintColor = AppColors.softSeparator
        progressBar.layer.cornerRadius = 2
        progressBar.clipsToBounds = true
        cardView.addSubview(progressBar)

        disclosureImageView.translatesAutoresizingMaskIntoConstraints = false
        disclosureImageView.contentMode = .scaleAspectFit
        disclosureImageView.tintColor = AppColors.tertiaryText
        disclosureImageView.image = UIImage(systemName: "chevron.right")
        cardView.addSubview(disclosureImageView)

        NSLayoutConstraint.activate([
            cardView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 6),
            cardView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            cardView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            cardView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -6),

            iconImageView.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 12),
            iconImageView.topAnchor.constraint(equalTo: cardView.topAnchor, constant: 12),
            iconImageView.widthAnchor.constraint(equalToConstant: 32),
            iconImageView.heightAnchor.constraint(equalToConstant: 32),

            titleLabel.leadingAnchor.constraint(equalTo: iconImageView.trailingAnchor, constant: 12),
            titleLabel.topAnchor.constraint(equalTo: cardView.topAnchor, constant: 12),
            titleLabel.trailingAnchor.constraint(equalTo: durationBadge.leadingAnchor, constant: -8),

            durationBadge.trailingAnchor.constraint(equalTo: disclosureImageView.leadingAnchor, constant: -8),
            durationBadge.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),
            durationBadge.widthAnchor.constraint(greaterThanOrEqualToConstant: 50),

            disclosureImageView.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -12),
            disclosureImageView.centerYAnchor.constraint(equalTo: cardView.centerYAnchor),
            disclosureImageView.widthAnchor.constraint(equalToConstant: 12),
            disclosureImageView.heightAnchor.constraint(equalToConstant: 12),

            tagStackView.leadingAnchor.constraint(equalTo: iconImageView.trailingAnchor, constant: 12),
            tagStackView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            tagStackView.trailingAnchor.constraint(lessThanOrEqualTo: disclosureImageView.leadingAnchor, constant: -8),

            progressBar.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 12),
            progressBar.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -12),
            progressBar.topAnchor.constraint(equalTo: tagStackView.bottomAnchor, constant: 10),
            progressBar.bottomAnchor.constraint(equalTo: cardView.bottomAnchor, constant: -12),
            progressBar.heightAnchor.constraint(equalToConstant: 4),
        ])

        cardView.applyAdaptiveShadow(radius: 8, opacity: 0.1)
    }

    // MARK: - Configuration

    func configure(with track: Track, progress: Float = 0.0) {
        titleLabel.text = track.title

        if let durationMs = track.durationMs {
            durationBadge.configure(durationMs: durationMs)
            durationBadge.isHidden = false
        } else {
            durationBadge.isHidden = true
        }

        configureTags(track.tags)

        progressBar.progress = progress
        progressBar.isHidden = progress == 0.0
    }

    private func configureTags(_ tags: [String]) {
        tagStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }

        let visibleTags = Array(tags.prefix(3))
        for tag in visibleTags {
            let tagView = TagView()
            tagView.configure(text: tag)
            tagStackView.addArrangedSubview(tagView)
        }

        if tags.count > 3 {
            let moreView = TagView()
            moreView.configure(text: "+\(tags.count - 3) more", isMore: true)
            tagStackView.addArrangedSubview(moreView)
        }

        tagStackView.isHidden = tags.isEmpty
    }

    // MARK: - Highlight animation

    func highlightBriefly() {
        guard !UIAccessibility.isReduceMotionEnabled else { return }

        let originalBackground = cardView.backgroundColor
        UIView.animate(withDuration: 0.2, delay: 0, options: [.allowUserInteraction]) {
            self.cardView.backgroundColor = AppColors.successColor.withAlphaComponent(0.2)
        } completion: { _ in
            UIView.animate(withDuration: 0.3) {
                self.cardView.backgroundColor = originalBackground
            }
        }

        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    // MARK: - Press animation

    override var isHighlighted: Bool {
        didSet {
            guard !UIAccessibility.isReduceMotionEnabled else { return }
            UIView.animate(
                withDuration: 0.3,
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
