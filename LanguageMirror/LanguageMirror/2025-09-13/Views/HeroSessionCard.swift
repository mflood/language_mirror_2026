//
//  HeroSessionCard.swift
//  LanguageMirror
//

import UIKit

final class HeroSessionCard: UIView {

    // MARK: - Callback

    var onTap: (() -> Void)?

    // MARK: - Subviews

    private let colorStripe = UIView()
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let timeLabel = UILabel()
    private let progressBar = UIProgressView()
    private let playIcon = UIImageView()

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
        backgroundColor = AppColors.cardBackground
        applyGoldPlateBorder(cornerRadius: 16)
        applyAdaptiveShadow(radius: 12, opacity: 0.12)

        // Tap gesture
        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap))
        addGestureRecognizer(tap)

        // Color stripe (left edge)
        colorStripe.translatesAutoresizingMaskIntoConstraints = false
        colorStripe.backgroundColor = AppColors.primaryAccent
        colorStripe.layer.cornerRadius = 2
        addSubview(colorStripe)

        // Title
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = .systemFont(ofSize: 20, weight: .semibold)
        titleLabel.textColor = AppColors.primaryText
        titleLabel.numberOfLines = 2
        addSubview(titleLabel)

        // Subtitle (practice set name)
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        subtitleLabel.font = .systemFont(ofSize: 15, weight: .regular)
        subtitleLabel.textColor = AppColors.secondaryText
        subtitleLabel.numberOfLines = 1
        addSubview(subtitleLabel)

        // Time label
        timeLabel.translatesAutoresizingMaskIntoConstraints = false
        timeLabel.font = .systemFont(ofSize: 13, weight: .regular)
        timeLabel.textColor = AppColors.tertiaryText
        addSubview(timeLabel)

        // Play icon
        playIcon.translatesAutoresizingMaskIntoConstraints = false
        let config = UIImage.SymbolConfiguration(pointSize: 36, weight: .medium)
        playIcon.image = UIImage(systemName: "play.circle.fill", withConfiguration: config)
        playIcon.tintColor = AppColors.primaryAccent
        playIcon.contentMode = .scaleAspectFit
        addSubview(playIcon)

        // Progress bar
        progressBar.translatesAutoresizingMaskIntoConstraints = false
        progressBar.progressTintColor = AppColors.primaryAccent
        progressBar.trackTintColor = AppColors.softSeparator
        progressBar.layer.cornerRadius = 2
        progressBar.clipsToBounds = true
        addSubview(progressBar)

        NSLayoutConstraint.activate([
            // Color stripe
            colorStripe.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
            colorStripe.topAnchor.constraint(equalTo: topAnchor, constant: 16),
            colorStripe.bottomAnchor.constraint(equalTo: progressBar.topAnchor, constant: -16),
            colorStripe.widthAnchor.constraint(equalToConstant: 4),

            // Play icon (right side)
            playIcon.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            playIcon.centerYAnchor.constraint(equalTo: centerYAnchor, constant: -8),
            playIcon.widthAnchor.constraint(equalToConstant: 44),
            playIcon.heightAnchor.constraint(equalToConstant: 44),

            // Title
            titleLabel.topAnchor.constraint(equalTo: topAnchor, constant: 16),
            titleLabel.leadingAnchor.constraint(equalTo: colorStripe.trailingAnchor, constant: 10),
            titleLabel.trailingAnchor.constraint(equalTo: playIcon.leadingAnchor, constant: -12),

            // Subtitle
            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),
            subtitleLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            subtitleLabel.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor),

            // Time
            timeLabel.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: 4),
            timeLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            timeLabel.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor),

            // Progress bar
            progressBar.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            progressBar.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            progressBar.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -12),
            progressBar.heightAnchor.constraint(equalToConstant: 4),
            progressBar.topAnchor.constraint(greaterThanOrEqualTo: timeLabel.bottomAnchor, constant: 12),
        ])
    }

    // MARK: - Configuration

    func configure(
        trackTitle: String,
        practiceSetTitle: String?,
        lastUpdatedAt: Date,
        currentClipIndex: Int,
        totalClips: Int
    ) {
        titleLabel.text = trackTitle
        subtitleLabel.text = practiceSetTitle ?? L10n("practice_home.practice_set")
        timeLabel.text = Self.relativeFormatter.localizedString(for: lastUpdatedAt, relativeTo: Date())

        let progress: Float = totalClips > 0 ? Float(currentClipIndex) / Float(totalClips) : 0
        progressBar.progress = progress
    }

    // MARK: - Tap Handling

    @objc private func handleTap() {
        onTap?()
    }

    // MARK: - Press Animation

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesBegan(touches, with: event)
        guard !UIAccessibility.isReduceMotionEnabled else { return }
        UIView.animate(
            withDuration: 0.25,
            delay: 0,
            usingSpringWithDamping: 0.7,
            initialSpringVelocity: 0.5,
            options: [.allowUserInteraction, .beginFromCurrentState]
        ) {
            self.transform = CGAffineTransform(scaleX: 0.97, y: 0.97)
        }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesEnded(touches, with: event)
        UIView.animate(
            withDuration: 0.25,
            delay: 0,
            usingSpringWithDamping: 0.7,
            initialSpringVelocity: 0.5,
            options: [.allowUserInteraction, .beginFromCurrentState]
        ) {
            self.transform = .identity
        }
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesCancelled(touches, with: event)
        UIView.animate(
            withDuration: 0.25,
            delay: 0,
            usingSpringWithDamping: 0.7,
            initialSpringVelocity: 0.5,
            options: [.allowUserInteraction, .beginFromCurrentState]
        ) {
            self.transform = .identity
        }
    }

    // MARK: - Trait Collection

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
            updateAdaptiveShadowForAppearance()
        }
    }
}
