//
//  EmptyStateView.swift
//  LanguageMirror
//
//  Created by Matthew Flood on 9/13/25.
//

import UIKit

/// ADHD-friendly empty state with encouraging messaging and visual appeal
final class EmptyStateView: UIView {
    
    // MARK: - Properties
    
    private let containerView = UIView()
    private let iconImageView = UIImageView()
    private let titleLabel = UILabel()
    private let messageLabel = UILabel()
    private let actionButton = UIButton(type: .system)
    
    var onActionTapped: (() -> Void)?
    
    // MARK: - Init
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Setup
    
    private func setupUI() {
        backgroundColor = .clear
        
        // Container with soft background
        containerView.translatesAutoresizingMaskIntoConstraints = false
        containerView.backgroundColor = AppColors.cardBackground
        containerView.layer.cornerRadius = 20
        containerView.layer.cornerCurve = .continuous
        addSubview(containerView)
        
        // Icon
        iconImageView.translatesAutoresizingMaskIntoConstraints = false
        iconImageView.contentMode = .scaleAspectFit
        iconImageView.tintColor = AppColors.primaryAccent
        containerView.addSubview(iconImageView)
        
        // Title
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = .systemFont(ofSize: 24, weight: .bold)
        titleLabel.textColor = AppColors.primaryText
        titleLabel.textAlignment = .center
        titleLabel.numberOfLines = 0
        containerView.addSubview(titleLabel)
        
        // Message
        messageLabel.translatesAutoresizingMaskIntoConstraints = false
        messageLabel.font = .systemFont(ofSize: 16, weight: .regular)
        messageLabel.textColor = AppColors.secondaryText
        messageLabel.textAlignment = .center
        messageLabel.numberOfLines = 0
        containerView.addSubview(messageLabel)
        
        // Action button (optional)
        actionButton.translatesAutoresizingMaskIntoConstraints = false
        actionButton.titleLabel?.font = .systemFont(ofSize: 17, weight: .semibold)
        actionButton.backgroundColor = AppColors.primaryAccent
        actionButton.setTitleColor(.white, for: .normal)
        actionButton.layer.cornerRadius = 12
        actionButton.layer.cornerCurve = .continuous
        actionButton.contentEdgeInsets = UIEdgeInsets(top: 12, left: 24, bottom: 12, right: 24)
        actionButton.addTarget(self, action: #selector(actionButtonTapped), for: .touchUpInside)
        containerView.addSubview(actionButton)
        
        // Layout
        NSLayoutConstraint.activate([
            // Container - centered with padding
            containerView.centerYAnchor.constraint(equalTo: centerYAnchor, constant: -40),
            containerView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 32),
            containerView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -32),
            
            // Icon
            iconImageView.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 40),
            iconImageView.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            iconImageView.widthAnchor.constraint(equalToConstant: 80),
            iconImageView.heightAnchor.constraint(equalToConstant: 80),
            
            // Title
            titleLabel.topAnchor.constraint(equalTo: iconImageView.bottomAnchor, constant: 24),
            titleLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 24),
            titleLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -24),
            
            // Message
            messageLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 12),
            messageLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 24),
            messageLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -24),
            
            // Action button
            actionButton.topAnchor.constraint(equalTo: messageLabel.bottomAnchor, constant: 24),
            actionButton.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            actionButton.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -40)
        ])
        
        // Apply shadow
        containerView.applyAdaptiveShadow(radius: 20, opacity: 0.1)
        
        // Add subtle animation on appear
        animateAppearance()
    }
    
    // MARK: - Configuration
    
    func configure(
        icon: String,
        title: String,
        message: String,
        actionTitle: String? = nil
    ) {
        iconImageView.image = UIImage(systemName: icon)
        titleLabel.text = title
        messageLabel.text = message
        
        if let actionTitle = actionTitle {
            actionButton.setTitle(actionTitle, for: .normal)
            actionButton.isHidden = false
        } else {
            actionButton.isHidden = true
        }
    }
    
    // MARK: - Actions
    
    @objc private func actionButtonTapped() {
        // Animate button press
        UIView.animate(
            withDuration: 0.15,
            animations: {
                self.actionButton.transform = CGAffineTransform(scaleX: 0.95, y: 0.95)
            },
            completion: { _ in
                UIView.animate(withDuration: 0.15) {
                    self.actionButton.transform = .identity
                }
            }
        )
        
        // Haptic feedback
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        
        onActionTapped?()
    }
    
    // MARK: - Animations
    
    private func animateAppearance() {
        // Start invisible and slightly scaled down
        containerView.alpha = 0
        containerView.transform = CGAffineTransform(scaleX: 0.9, y: 0.9)
        
        // Animate in with spring
        UIView.animate(
            withDuration: 0.6,
            delay: 0.1,
            usingSpringWithDamping: 0.7,
            initialSpringVelocity: 0.5,
            options: [.curveEaseOut]
        ) {
            self.containerView.alpha = 1
            self.containerView.transform = .identity
        }
    }
    
    // MARK: - Trait Collection
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        
        if traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
            containerView.updateAdaptiveShadowForAppearance()
        }
    }
}

// MARK: - Convenience Configurations

extension EmptyStateView {
    
    /// Empty library state
    static func emptyLibrary(onAction: @escaping () -> Void) -> EmptyStateView {
        let view = EmptyStateView()
        view.configure(
            icon: "books.vertical",
            title: "Your Library Awaits",
            message: "Start your language learning journey by importing your first audio track or exploring pre-made packs.",
            actionTitle: "Get Started"
        )
        view.onActionTapped = onAction
        return view
    }
    
    /// No search results
    static func noSearchResults() -> EmptyStateView {
        let view = EmptyStateView()
        view.configure(
            icon: "magnifyingglass",
            title: "No Tracks Found",
            message: "Try adjusting your search or browse all tracks by clearing the search.",
            actionTitle: nil
        )
        return view
    }
    
    /// Loading state
    static func loading() -> EmptyStateView {
        let view = EmptyStateView()
        view.configure(
            icon: "hourglass",
            title: "Loading...",
            message: "Preparing your library",
            actionTitle: nil
        )
        return view
    }
}

