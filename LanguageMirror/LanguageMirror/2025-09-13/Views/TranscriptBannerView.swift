//
//  TranscriptBannerView.swift
//  LanguageMirror
//
//  A compact banner that shows the transcript text for the currently
//  playing practice clip. Tap to view a larger, scrollable version.
//

import UIKit

final class TranscriptBannerView: UIView {

    private let textLabel = UILabel()
    private let iconView = UIImageView()
    private let chevronView = UIImageView()
    private let stackView = UIStackView()
    private var collapsedHeightConstraint: NSLayoutConstraint?

    /// Called when the user taps the banner. Useful for showing a fuller view.
    var onTap: (() -> Void)?

    private static let fontSizeKey = "transcript.fontSize"
    private static let defaultBannerFontSize: CGFloat = 15
    private static let bannerSizeOffset: CGFloat = -4 // banner is slightly smaller than detail

    private var bannerFontSize: CGFloat {
        let stored = UserDefaults.standard.double(forKey: Self.fontSizeKey)
        let detail: CGFloat = stored > 0 ? CGFloat(stored) : 19
        return max(11, detail + Self.bannerSizeOffset)
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applyFontSize),
            name: .transcriptFontSizeDidChange,
            object: nil
        )
    }

    deinit { NotificationCenter.default.removeObserver(self) }

    @objc private func applyFontSize() {
        textLabel.font = .systemFont(ofSize: bannerFontSize, weight: .regular)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func setupUI() {
        translatesAutoresizingMaskIntoConstraints = false
        backgroundColor = UIColor { trait in
            // Warm, slightly red-tinted background to distinguish from clip cells
            trait.userInterfaceStyle == .dark
                ? UIColor(red: 0.32, green: 0.18, blue: 0.18, alpha: 1.0)
                : UIColor(red: 1.00, green: 0.94, blue: 0.92, alpha: 1.0)
        }
        layer.cornerRadius = 10
        layer.cornerCurve = .continuous
        layer.borderWidth = 1
        layer.borderColor = UIColor { trait in
            trait.userInterfaceStyle == .dark
                ? UIColor(red: 0.55, green: 0.30, blue: 0.30, alpha: 0.6)
                : UIColor(red: 0.90, green: 0.55, blue: 0.50, alpha: 0.45)
        }.cgColor
        clipsToBounds = true

        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.image = UIImage(systemName: "text.quote")
        iconView.tintColor = AppColors.primaryAccent
        iconView.contentMode = .scaleAspectFit
        iconView.setContentHuggingPriority(.required, for: .horizontal)

        textLabel.translatesAutoresizingMaskIntoConstraints = false
        textLabel.font = .systemFont(ofSize: bannerFontSize, weight: .regular)
        textLabel.textColor = AppColors.primaryText
        textLabel.numberOfLines = 2
        textLabel.lineBreakMode = .byTruncatingTail

        chevronView.translatesAutoresizingMaskIntoConstraints = false
        chevronView.image = UIImage(systemName: "chevron.up")
        chevronView.tintColor = AppColors.tertiaryText
        chevronView.contentMode = .scaleAspectFit
        chevronView.setContentHuggingPriority(.required, for: .horizontal)

        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.axis = .horizontal
        stackView.alignment = .center
        stackView.spacing = 10
        stackView.isUserInteractionEnabled = false
        stackView.addArrangedSubview(iconView)
        stackView.addArrangedSubview(textLabel)
        stackView.addArrangedSubview(chevronView)
        addSubview(stackView)

        NSLayoutConstraint.activate([
            iconView.widthAnchor.constraint(equalToConstant: 18),
            iconView.heightAnchor.constraint(equalToConstant: 18),
            chevronView.widthAnchor.constraint(equalToConstant: 14),
            chevronView.heightAnchor.constraint(equalToConstant: 14),

            stackView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            stackView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            stackView.topAnchor.constraint(equalTo: topAnchor, constant: 10),
            stackView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -10),
        ])

        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap))
        addGestureRecognizer(tap)

        // Collapsed-to-zero height constraint, activated when banner is empty.
        collapsedHeightConstraint = heightAnchor.constraint(equalToConstant: 0)
        collapsedHeightConstraint?.priority = .required
        collapsedHeightConstraint?.isActive = true

        applyAdaptiveShadow(radius: 6, opacity: 0.08)
    }

    /// Set the transcript text to display. Pass nil/empty to hide and
    /// collapse the view's height so neighboring views can take its space.
    func update(text: String?) {
        let trimmed = text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if trimmed.isEmpty {
            textLabel.text = nil
            isHidden = true
            collapsedHeightConstraint?.isActive = true
        } else {
            textLabel.text = trimmed
            isHidden = false
            collapsedHeightConstraint?.isActive = false
        }
        invalidateIntrinsicContentSize()
        superview?.setNeedsLayout()
    }

    @objc private func handleTap() {
        let generator = UISelectionFeedbackGenerator()
        generator.selectionChanged()
        onTap?()
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
            updateAdaptiveShadowForAppearance()
            layer.borderColor = UIColor { trait in
                trait.userInterfaceStyle == .dark
                    ? UIColor(red: 0.55, green: 0.30, blue: 0.30, alpha: 0.6)
                    : UIColor(red: 0.90, green: 0.55, blue: 0.50, alpha: 0.45)
            }.resolvedColor(with: traitCollection).cgColor
        }
    }
}
