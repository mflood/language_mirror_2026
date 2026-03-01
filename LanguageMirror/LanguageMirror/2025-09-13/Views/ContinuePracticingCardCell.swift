//
//  ContinuePracticingCardCell.swift
//  LanguageMirror
//

import UIKit

final class ContinuePracticingCardCell: UICollectionViewCell {

    // MARK: - Subviews

    private let colorStripe = UIView()
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let timeLabel = UILabel()
    private let progressBar = UIProgressView()

    private static let relativeFormatter: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .abbreviated
        return f
    }()

    // MARK: - Init

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    // MARK: - Setup

    private func setupUI() {
        contentView.backgroundColor = AppColors.cardBackground
        contentView.layer.cornerRadius = 12
        contentView.layer.cornerCurve = .continuous
        contentView.applyAdaptiveShadow(radius: 8, opacity: 0.1)

        // Color stripe (left edge)
        colorStripe.translatesAutoresizingMaskIntoConstraints = false
        colorStripe.layer.cornerRadius = 2
        contentView.addSubview(colorStripe)

        // Title
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = .systemFont(ofSize: 15, weight: .semibold)
        titleLabel.textColor = AppColors.primaryText
        titleLabel.numberOfLines = 2
        contentView.addSubview(titleLabel)

        // Subtitle (practice set name)
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        subtitleLabel.font = .systemFont(ofSize: 13, weight: .regular)
        subtitleLabel.textColor = AppColors.secondaryText
        subtitleLabel.numberOfLines = 1
        contentView.addSubview(subtitleLabel)

        // Time label
        timeLabel.translatesAutoresizingMaskIntoConstraints = false
        timeLabel.font = .systemFont(ofSize: 12, weight: .regular)
        timeLabel.textColor = AppColors.tertiaryText
        contentView.addSubview(timeLabel)

        // Progress bar
        progressBar.translatesAutoresizingMaskIntoConstraints = false
        progressBar.progressTintColor = AppColors.primaryAccent
        progressBar.trackTintColor = AppColors.softSeparator
        progressBar.layer.cornerRadius = 2
        progressBar.clipsToBounds = true
        contentView.addSubview(progressBar)

        NSLayoutConstraint.activate([
            // Color stripe
            colorStripe.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 8),
            colorStripe.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            colorStripe.bottomAnchor.constraint(equalTo: progressBar.topAnchor, constant: -12),
            colorStripe.widthAnchor.constraint(equalToConstant: 4),

            // Title
            titleLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            titleLabel.leadingAnchor.constraint(equalTo: colorStripe.trailingAnchor, constant: 8),
            titleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -10),

            // Subtitle
            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),
            subtitleLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            subtitleLabel.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor),

            // Time
            timeLabel.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: 4),
            timeLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            timeLabel.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor),

            // Progress bar
            progressBar.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 10),
            progressBar.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -10),
            progressBar.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -10),
            progressBar.heightAnchor.constraint(equalToConstant: 4),
        ])
    }

    // MARK: - Configuration

    func configure(
        trackTitle: String,
        practiceSetTitle: String?,
        lastUpdatedAt: Date,
        currentClipIndex: Int,
        totalClips: Int,
        colorIndex: Int
    ) {
        titleLabel.text = trackTitle
        subtitleLabel.text = practiceSetTitle ?? "Practice Set"
        timeLabel.text = Self.relativeFormatter.localizedString(for: lastUpdatedAt, relativeTo: Date())

        let progress: Float = totalClips > 0 ? Float(currentClipIndex) / Float(totalClips) : 0
        progressBar.progress = progress

        colorStripe.backgroundColor = AppColors.packAccent(index: colorIndex)
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
                self.contentView.transform = self.isHighlighted
                    ? CGAffineTransform(scaleX: 0.96, y: 0.96)
                    : .identity
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
            contentView.updateAdaptiveShadowForAppearance()
        }
    }
}
