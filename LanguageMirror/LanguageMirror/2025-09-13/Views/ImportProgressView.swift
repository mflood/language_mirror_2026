//
//  ImportProgressView.swift
//  LanguageMirror
//
//  Created by Matthew Flood on 9/13/25.
//

import UIKit

/// Beautiful import progress view with states, animations, and celebrations
final class ImportProgressView: UIView {
    
    // MARK: - State
    
    enum State {
        case downloading(progress: Float)
        case processing
        case success(message: String)
        case error(message: String)
    }
    
    // MARK: - Properties
    
    private let containerView = UIView()
    private let iconContainerView = UIView()
    private let iconImageView = UIImageView()
    private let titleLabel = UILabel()
    private let messageLabel = UILabel()
    private let progressView = UIProgressView()
    private let spinner = UIActivityIndicatorView(style: .large)
    private let cancelButton = UIButton(type: .system)
    
    var onCancel: (() -> Void)?
    
    private var currentState: State = .processing
    
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
        backgroundColor = AppColors.primaryBackground.withAlphaComponent(0.95)
        
        // Container card
        containerView.translatesAutoresizingMaskIntoConstraints = false
        containerView.backgroundColor = AppColors.cardBackground
        containerView.layer.cornerRadius = 20
        containerView.layer.cornerCurve = .continuous
        addSubview(containerView)
        
        // Icon container (circular background)
        iconContainerView.translatesAutoresizingMaskIntoConstraints = false
        iconContainerView.layer.cornerRadius = 40
        iconContainerView.layer.cornerCurve = .continuous
        iconContainerView.backgroundColor = AppColors.primaryAccent.withAlphaComponent(0.2)
        containerView.addSubview(iconContainerView)
        
        // Icon
        iconImageView.translatesAutoresizingMaskIntoConstraints = false
        iconImageView.contentMode = .scaleAspectFit
        iconImageView.tintColor = AppColors.primaryAccent
        iconContainerView.addSubview(iconImageView)
        
        // Title
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = .systemFont(ofSize: 22, weight: .bold)
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
        
        // Progress view
        progressView.translatesAutoresizingMaskIntoConstraints = false
        progressView.progressTintColor = AppColors.primaryAccent
        progressView.trackTintColor = AppColors.softSeparator
        progressView.layer.cornerRadius = 3
        progressView.clipsToBounds = true
        containerView.addSubview(progressView)
        
        // Spinner
        spinner.translatesAutoresizingMaskIntoConstraints = false
        spinner.color = AppColors.primaryAccent
        containerView.addSubview(spinner)
        
        // Cancel button
        cancelButton.translatesAutoresizingMaskIntoConstraints = false
        cancelButton.setTitle("Cancel", for: .normal)
        cancelButton.titleLabel?.font = .systemFont(ofSize: 17, weight: .semibold)
        cancelButton.setTitleColor(AppColors.secondaryText, for: .normal)
        cancelButton.addTarget(self, action: #selector(cancelTapped), for: .touchUpInside)
        containerView.addSubview(cancelButton)
        
        // Layout
        NSLayoutConstraint.activate([
            // Container - centered
            containerView.centerXAnchor.constraint(equalTo: centerXAnchor),
            containerView.centerYAnchor.constraint(equalTo: centerYAnchor),
            containerView.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: 40),
            containerView.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -40),
            containerView.widthAnchor.constraint(lessThanOrEqualToConstant: 320),
            
            // Icon container
            iconContainerView.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 32),
            iconContainerView.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            iconContainerView.widthAnchor.constraint(equalToConstant: 80),
            iconContainerView.heightAnchor.constraint(equalToConstant: 80),
            
            // Icon
            iconImageView.centerXAnchor.constraint(equalTo: iconContainerView.centerXAnchor),
            iconImageView.centerYAnchor.constraint(equalTo: iconContainerView.centerYAnchor),
            iconImageView.widthAnchor.constraint(equalToConstant: 44),
            iconImageView.heightAnchor.constraint(equalToConstant: 44),
            
            // Title
            titleLabel.topAnchor.constraint(equalTo: iconContainerView.bottomAnchor, constant: 24),
            titleLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 24),
            titleLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -24),
            
            // Message
            messageLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            messageLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 24),
            messageLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -24),
            
            // Progress view
            progressView.topAnchor.constraint(equalTo: messageLabel.bottomAnchor, constant: 24),
            progressView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 24),
            progressView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -24),
            progressView.heightAnchor.constraint(equalToConstant: 6),
            
            // Spinner (same position as progress)
            spinner.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            spinner.topAnchor.constraint(equalTo: messageLabel.bottomAnchor, constant: 20),
            
            // Cancel button
            cancelButton.topAnchor.constraint(equalTo: progressView.bottomAnchor, constant: 20),
            cancelButton.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            cancelButton.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -24)
        ])
        
        // Apply shadow
        containerView.applyAdaptiveShadow(radius: 24, opacity: 0.15)
        
        // Initial animation
        animateAppearance()
    }
    
    // MARK: - State Updates
    
    func updateState(_ newState: State) {
        currentState = newState
        
        UIView.animate(withDuration: 0.3) {
            self.applyStateUI()
        }
        
        // Haptic feedback on state changes
        let generator = UINotificationFeedbackGenerator()
        switch newState {
        case .success:
            generator.notificationOccurred(.success)
            animateSuccess()
        case .error:
            generator.notificationOccurred(.error)
        case .downloading, .processing:
            let impact = UIImpactFeedbackGenerator(style: .light)
            impact.impactOccurred()
        }
    }
    
    private func applyStateUI() {
        switch currentState {
        case .downloading(let progress):
            titleLabel.text = "Downloading"
            messageLabel.text = "Getting your audio file..."
            iconImageView.image = UIImage(systemName: "arrow.down.circle.fill")
            iconContainerView.backgroundColor = AppColors.primaryAccent.withAlphaComponent(0.2)
            iconImageView.tintColor = AppColors.primaryAccent
            
            progressView.isHidden = false
            progressView.progress = progress
            spinner.isHidden = true
            spinner.stopAnimating()
            cancelButton.isHidden = false
            
        case .processing:
            titleLabel.text = "Processing"
            messageLabel.text = "Preparing your track..."
            iconImageView.image = UIImage(systemName: "waveform")
            iconContainerView.backgroundColor = AppColors.primaryAccent.withAlphaComponent(0.2)
            iconImageView.tintColor = AppColors.primaryAccent
            
            progressView.isHidden = true
            spinner.isHidden = false
            spinner.startAnimating()
            cancelButton.isHidden = false
            startPulseAnimation()
            
        case .success(let message):
            titleLabel.text = "Success!"
            messageLabel.text = message
            iconImageView.image = UIImage(systemName: "checkmark.circle.fill")
            iconContainerView.backgroundColor = AppColors.successColor.withAlphaComponent(0.2)
            iconImageView.tintColor = AppColors.successColor
            
            progressView.isHidden = true
            spinner.isHidden = true
            spinner.stopAnimating()
            cancelButton.isHidden = true
            
        case .error(let message):
            titleLabel.text = "Unable to Import"
            messageLabel.text = message
            iconImageView.image = UIImage(systemName: "exclamationmark.circle.fill")
            iconContainerView.backgroundColor = AppColors.errorColor.withAlphaComponent(0.15)
            iconImageView.tintColor = AppColors.errorColor
            
            progressView.isHidden = true
            spinner.isHidden = true
            spinner.stopAnimating()
            cancelButton.setTitle("Dismiss", for: .normal)
            cancelButton.isHidden = false
        }
    }
    
    // MARK: - Animations
    
    private func animateAppearance() {
        containerView.alpha = 0
        containerView.transform = CGAffineTransform(scaleX: 0.8, y: 0.8)
        
        UIView.animate(
            withDuration: 0.5,
            delay: 0,
            usingSpringWithDamping: 0.7,
            initialSpringVelocity: 0.5,
            options: [.curveEaseOut]
        ) {
            self.containerView.alpha = 1
            self.containerView.transform = .identity
        }
    }
    
    private func animateSuccess() {
        // Celebrate with scale animation
        UIView.animateKeyframes(
            withDuration: 0.6,
            delay: 0,
            options: []
        ) {
            UIView.addKeyframe(withRelativeStartTime: 0, relativeDuration: 0.3) {
                self.iconContainerView.transform = CGAffineTransform(scaleX: 1.2, y: 1.2)
            }
            UIView.addKeyframe(withRelativeStartTime: 0.3, relativeDuration: 0.3) {
                self.iconContainerView.transform = .identity
            }
        }
    }
    
    private func startPulseAnimation() {
        UIView.animate(
            withDuration: 1.0,
            delay: 0,
            options: [.repeat, .autoreverse, .curveEaseInOut]
        ) {
            self.iconImageView.alpha = 0.5
        }
    }
    
    // MARK: - Actions
    
    @objc private func cancelTapped() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        
        onCancel?()
    }
    
    // MARK: - Trait Collection
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        
        if traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
            containerView.updateAdaptiveShadowForAppearance()
        }
    }
}

