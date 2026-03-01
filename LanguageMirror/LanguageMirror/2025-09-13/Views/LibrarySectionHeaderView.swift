//
//  LibrarySectionHeaderView.swift
//  LanguageMirror
//

import UIKit

final class LibrarySectionHeaderView: UICollectionReusableView {

    static let elementKind = "LibrarySectionHeader"

    enum Mode {
        case sectionTitle(String)
        case packHeader(title: String, count: Int, expanded: Bool, colorIndex: Int)
    }

    // MARK: - Subviews

    // Section title mode
    private let sectionTitleLabel = UILabel()

    // Pack header mode
    private let containerView = UIView()
    private let colorStripeView = UIView()
    private let chevronImageView = UIImageView()
    private let packTitleLabel = UILabel()
    private let countBadge = UILabel()

    var onPackTap: (() -> Void)?

    // MARK: - Init

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    // MARK: - Setup

    private func setupUI() {
        // Section title label (simple mode)
        sectionTitleLabel.translatesAutoresizingMaskIntoConstraints = false
        sectionTitleLabel.font = .systemFont(ofSize: 18, weight: .semibold)
        sectionTitleLabel.textColor = AppColors.primaryText
        addSubview(sectionTitleLabel)

        NSLayoutConstraint.activate([
            sectionTitleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            sectionTitleLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            sectionTitleLabel.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -6),
        ])

        // Pack header container
        containerView.translatesAutoresizingMaskIntoConstraints = false
        containerView.backgroundColor = AppColors.cardBackground
        containerView.layer.cornerRadius = 12
        containerView.layer.cornerCurve = .continuous
        addSubview(containerView)

        colorStripeView.translatesAutoresizingMaskIntoConstraints = false
        colorStripeView.layer.cornerRadius = 2
        containerView.addSubview(colorStripeView)

        chevronImageView.translatesAutoresizingMaskIntoConstraints = false
        chevronImageView.contentMode = .scaleAspectFit
        chevronImageView.tintColor = AppColors.secondaryText
        chevronImageView.image = UIImage(systemName: "chevron.right")
        containerView.addSubview(chevronImageView)

        packTitleLabel.translatesAutoresizingMaskIntoConstraints = false
        packTitleLabel.font = .systemFont(ofSize: 18, weight: .semibold)
        packTitleLabel.textColor = AppColors.primaryText
        containerView.addSubview(packTitleLabel)

        countBadge.translatesAutoresizingMaskIntoConstraints = false
        countBadge.font = .systemFont(ofSize: 14, weight: .medium)
        countBadge.textColor = AppColors.secondaryText
        countBadge.backgroundColor = AppColors.tertiaryBackground
        countBadge.layer.cornerRadius = 10
        countBadge.layer.cornerCurve = .continuous
        countBadge.clipsToBounds = true
        countBadge.textAlignment = .center
        containerView.addSubview(countBadge)

        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: topAnchor, constant: 8),
            containerView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            containerView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            containerView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -4),

            colorStripeView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 12),
            colorStripeView.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            colorStripeView.widthAnchor.constraint(equalToConstant: 4),
            colorStripeView.heightAnchor.constraint(equalToConstant: 32),

            chevronImageView.leadingAnchor.constraint(equalTo: colorStripeView.trailingAnchor, constant: 12),
            chevronImageView.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            chevronImageView.widthAnchor.constraint(equalToConstant: 16),
            chevronImageView.heightAnchor.constraint(equalToConstant: 16),

            packTitleLabel.leadingAnchor.constraint(equalTo: chevronImageView.trailingAnchor, constant: 12),
            packTitleLabel.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),

            countBadge.leadingAnchor.constraint(equalTo: packTitleLabel.trailingAnchor, constant: 8),
            countBadge.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            countBadge.trailingAnchor.constraint(lessThanOrEqualTo: containerView.trailingAnchor, constant: -16),
            countBadge.widthAnchor.constraint(greaterThanOrEqualToConstant: 32),
            countBadge.heightAnchor.constraint(equalToConstant: 24),
        ])

        containerView.applyAdaptiveShadow(radius: 6, opacity: 0.08)

        let tap = UITapGestureRecognizer(target: self, action: #selector(handlePackTap))
        containerView.addGestureRecognizer(tap)
    }

    // MARK: - Configuration

    func configure(mode: Mode) {
        switch mode {
        case .sectionTitle(let title):
            sectionTitleLabel.text = title
            sectionTitleLabel.isHidden = false
            containerView.isHidden = true

        case .packHeader(let title, let count, let expanded, let colorIndex):
            sectionTitleLabel.isHidden = true
            containerView.isHidden = false

            packTitleLabel.text = title
            countBadge.text = "\(count)"
            colorStripeView.backgroundColor = AppColors.packAccent(index: colorIndex)
            containerView.backgroundColor = AppColors.packBackground(index: colorIndex)

            let targetRotation: CGFloat = expanded ? .pi / 2 : 0
            UIView.animate(
                withDuration: 0.3,
                delay: 0,
                usingSpringWithDamping: 0.7,
                initialSpringVelocity: 0.5,
                options: [.beginFromCurrentState]
            ) {
                self.chevronImageView.transform = CGAffineTransform(rotationAngle: targetRotation)
            }
        }
    }

    // MARK: - Actions

    @objc private func handlePackTap() {
        UIView.animate(withDuration: 0.1, animations: {
            self.containerView.transform = CGAffineTransform(scaleX: 0.98, y: 0.98)
        }, completion: { _ in
            UIView.animate(withDuration: 0.1) {
                self.containerView.transform = .identity
            }
        })
        onPackTap?()
    }

    // MARK: - Trait Collection

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
            containerView.updateAdaptiveShadowForAppearance()
        }
    }
}
