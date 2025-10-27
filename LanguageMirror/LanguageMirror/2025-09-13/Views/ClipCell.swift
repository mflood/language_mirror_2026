//
//  ClipCell.swift
//  LanguageMirror
//
//  Created by Matthew Flood on 10/20/25.
//

import UIKit

/// ADHD-friendly clip cell with visual state indicators, progress tracking, and animations
final class ClipCell: UITableViewCell {
    
    // MARK: - Properties
    
    private let cardView = UIView()
    private let indexCircle = UIView()
    private let indexLabel = UILabel()
    private let indexIconView = UIImageView()
    private let titleLabel = UILabel()
    private let timeRangeLabel = UILabel()
    private let loopProgressLabel = UILabel()
    private let speedLabel = UILabel()
    private let progressBar = UIProgressView()
    private let checkmarkImageView = UIImageView()
    private let infinityBadge = UILabel()
    
    private var pulseAnimation: CABasicAnimation?
    private var isCurrentClip = false
    
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
        
        // Index circle (left side)
        indexCircle.translatesAutoresizingMaskIntoConstraints = false
        indexCircle.backgroundColor = AppColors.primaryAccent.withAlphaComponent(0.15)
        indexCircle.layer.cornerRadius = 20
        cardView.addSubview(indexCircle)
        
        indexLabel.translatesAutoresizingMaskIntoConstraints = false
        indexLabel.font = .systemFont(ofSize: 16, weight: .semibold)
        indexLabel.textColor = AppColors.primaryAccent
        indexLabel.textAlignment = .center
        indexCircle.addSubview(indexLabel)
        
        indexIconView.translatesAutoresizingMaskIntoConstraints = false
        indexIconView.contentMode = .scaleAspectFit
        indexIconView.tintColor = AppColors.primaryAccent
        indexIconView.alpha = 0  // Hidden by default
        indexCircle.addSubview(indexIconView)
        
        // Title label
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = .systemFont(ofSize: 16, weight: .medium)
        titleLabel.textColor = AppColors.primaryText
        titleLabel.numberOfLines = 1
        cardView.addSubview(titleLabel)
        
        // Time range label
        timeRangeLabel.translatesAutoresizingMaskIntoConstraints = false
        timeRangeLabel.font = .monospacedSystemFont(ofSize: 13, weight: .regular)
        timeRangeLabel.textColor = AppColors.secondaryText
        cardView.addSubview(timeRangeLabel)
        
        // Loop progress label (e.g., "5/20")
        loopProgressLabel.translatesAutoresizingMaskIntoConstraints = false
        loopProgressLabel.font = .monospacedSystemFont(ofSize: 14, weight: .medium)
        loopProgressLabel.textColor = AppColors.primaryText
        cardView.addSubview(loopProgressLabel)
        
        // Speed label (e.g., "0.8x")
        speedLabel.translatesAutoresizingMaskIntoConstraints = false
        speedLabel.font = .monospacedSystemFont(ofSize: 13, weight: .regular)
        speedLabel.textColor = AppColors.secondaryText
        cardView.addSubview(speedLabel)
        
        // Progress bar
        progressBar.translatesAutoresizingMaskIntoConstraints = false
        progressBar.progressTintColor = AppColors.primaryAccent
        progressBar.trackTintColor = AppColors.softSeparator
        progressBar.layer.cornerRadius = 2
        progressBar.clipsToBounds = true
        cardView.addSubview(progressBar)
        
        // Checkmark (for completed clips)
        checkmarkImageView.translatesAutoresizingMaskIntoConstraints = false
        checkmarkImageView.contentMode = .scaleAspectFit
        checkmarkImageView.tintColor = AppColors.durationShort
        checkmarkImageView.image = UIImage(systemName: "checkmark.circle.fill")
        checkmarkImageView.alpha = 0
        cardView.addSubview(checkmarkImageView)
        
        // Infinity badge (for forever mode)
        infinityBadge.translatesAutoresizingMaskIntoConstraints = false
        infinityBadge.text = "∞"
        infinityBadge.font = .systemFont(ofSize: 16, weight: .bold)
        infinityBadge.textColor = AppColors.primaryAccent
        infinityBadge.alpha = 0
        cardView.addSubview(infinityBadge)
        
        // Apply shadows/glow
        applyShadow()
        
        // Layout
        NSLayoutConstraint.activate([
            // Card view with margins
            cardView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 4),
            cardView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            cardView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            cardView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -4),
            cardView.heightAnchor.constraint(greaterThanOrEqualToConstant: 72),
            
            // Index circle
            indexCircle.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 12),
            indexCircle.centerYAnchor.constraint(equalTo: cardView.centerYAnchor),
            indexCircle.widthAnchor.constraint(equalToConstant: 40),
            indexCircle.heightAnchor.constraint(equalToConstant: 40),
            
            indexLabel.centerXAnchor.constraint(equalTo: indexCircle.centerXAnchor),
            indexLabel.centerYAnchor.constraint(equalTo: indexCircle.centerYAnchor),
            
            indexIconView.centerXAnchor.constraint(equalTo: indexCircle.centerXAnchor),
            indexIconView.centerYAnchor.constraint(equalTo: indexCircle.centerYAnchor),
            indexIconView.widthAnchor.constraint(equalToConstant: 24),
            indexIconView.heightAnchor.constraint(equalToConstant: 24),
            
            // Title
            titleLabel.leadingAnchor.constraint(equalTo: indexCircle.trailingAnchor, constant: 12),
            titleLabel.topAnchor.constraint(equalTo: cardView.topAnchor, constant: 12),
            titleLabel.trailingAnchor.constraint(equalTo: loopProgressLabel.leadingAnchor, constant: -8),
            
            // Time range
            timeRangeLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            timeRangeLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 2),
            
            // Loop progress (right side, top)
            loopProgressLabel.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -12),
            loopProgressLabel.topAnchor.constraint(equalTo: cardView.topAnchor, constant: 12),
            loopProgressLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 50),
            
            // Speed (right side, below loop progress)
            speedLabel.trailingAnchor.constraint(equalTo: loopProgressLabel.trailingAnchor),
            speedLabel.topAnchor.constraint(equalTo: loopProgressLabel.bottomAnchor, constant: 2),
            
            // Progress bar
            progressBar.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            progressBar.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -60),
            progressBar.bottomAnchor.constraint(equalTo: cardView.bottomAnchor, constant: -12),
            progressBar.heightAnchor.constraint(equalToConstant: 4),
            
            // Checkmark
            checkmarkImageView.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -12),
            checkmarkImageView.bottomAnchor.constraint(equalTo: cardView.bottomAnchor, constant: -12),
            checkmarkImageView.widthAnchor.constraint(equalToConstant: 20),
            checkmarkImageView.heightAnchor.constraint(equalToConstant: 20),
            
            // Infinity badge
            infinityBadge.leadingAnchor.constraint(equalTo: indexCircle.trailingAnchor, constant: -8),
            infinityBadge.topAnchor.constraint(equalTo: indexCircle.topAnchor, constant: -4),
        ])
    }
    
    private func applyShadow() {
        if traitCollection.userInterfaceStyle == .dark {
            cardView.layer.shadowColor = UIColor.white.cgColor
            cardView.layer.shadowOpacity = 0.05
            cardView.layer.shadowOffset = CGSize(width: 0, height: 1)
            cardView.layer.shadowRadius = 3
        } else {
            cardView.layer.shadowColor = UIColor.black.cgColor
            cardView.layer.shadowOpacity = 0.08
            cardView.layer.shadowOffset = CGSize(width: 0, height: 2)
            cardView.layer.shadowRadius = 6
        }
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
            applyShadow()
        }
    }
    
    // MARK: - Configuration
    
    func configure(
        index: Int,
        clip: Clip,
        currentLoops: Int,
        totalLoops: Int,
        currentSpeed: Float,
        isCurrent: Bool,
        isCompleted: Bool,
        showForeverBadge: Bool
    ) {
        // Index - show number for drills, icon for skip/noise
        let isDrill = clip.kind == .drill
        
        if isDrill {
            indexLabel.text = "\(index + 1)"
            indexLabel.alpha = 1.0
            indexIconView.alpha = 0
        } else {
            indexLabel.alpha = 0
            indexIconView.alpha = 0.5
            
            // Set icon based on kind
            let iconName: String
            switch clip.kind {
            case .skip: iconName = "forward.fill"
            case .noise: iconName = "speaker.slash.fill"
            case .drill: iconName = "checkmark.circle.fill"  // Won't be used
            }
            indexIconView.image = UIImage(systemName: iconName)
        }
        
        // Title
        titleLabel.text = clip.title ?? "Clip \(index + 1)"
        
        // Time range
        let startTime = formatTime(ms: clip.startMs)
        let endTime = formatTime(ms: clip.endMs)
        timeRangeLabel.text = "\(startTime) - \(endTime)"
        
        // Loop progress - hide completely
        loopProgressLabel.text = ""
        
        // Speed
        speedLabel.text = String(format: "%.2fx", currentSpeed)
        
        // Progress bar
        let progress = totalLoops > 0 ? Float(currentLoops) / Float(totalLoops) : 0
        progressBar.progress = progress
        
        // Update progress bar color based on completion
        if progress < 0.33 {
            progressBar.progressTintColor = AppColors.durationShort
        } else if progress < 0.67 {
            progressBar.progressTintColor = AppColors.durationMedium
        } else {
            progressBar.progressTintColor = AppColors.durationLong
        }
        
        // Visual state for clip kind
        if isDrill {
            titleLabel.alpha = 1.0
            timeRangeLabel.alpha = 1.0
            indexCircle.alpha = 1.0
            titleLabel.attributedText = nil
            titleLabel.text = clip.title ?? "Clip \(index + 1)"
        } else {
            // Skip/Noise clips - grayed out with strikethrough
            titleLabel.alpha = 0.5
            timeRangeLabel.alpha = 0.5
            indexCircle.alpha = 0.5
            
            let text = clip.title ?? "Clip \(index + 1)"
            let attributes: [NSAttributedString.Key: Any] = [
                .strikethroughStyle: NSUnderlineStyle.single.rawValue,
                .strikethroughColor: AppColors.tertiaryText
            ]
            titleLabel.attributedText = NSAttributedString(string: text, attributes: attributes)
        }
        
        // Current clip state
        self.isCurrentClip = isCurrent
        if isCurrent {
            cardView.layer.borderWidth = 2
            cardView.layer.borderColor = AppColors.primaryAccent.cgColor
            applyShadow()
            startPulseAnimation()
        } else {
            cardView.layer.borderWidth = 0
            stopPulseAnimation()
        }
        
        // Completed state
        checkmarkImageView.alpha = isCompleted ? 1.0 : 0
        
        // Forever badge
        infinityBadge.alpha = showForeverBadge ? 1.0 : 0
    }
    
    private func formatTime(ms: Int) -> String {
        let totalSeconds = ms / 1000
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    // MARK: - Animations
    
    private func startPulseAnimation() {
        guard !UIAccessibility.isReduceMotionEnabled else { return }
        stopPulseAnimation()
        
        let pulse = CABasicAnimation(keyPath: "transform.scale")
        pulse.fromValue = 1.0
        pulse.toValue = 1.02
        pulse.duration = 1.0
        pulse.autoreverses = true
        pulse.repeatCount = .infinity
        pulse.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        
        cardView.layer.add(pulse, forKey: "pulse")
        pulseAnimation = pulse
    }
    
    private func stopPulseAnimation() {
        cardView.layer.removeAnimation(forKey: "pulse")
        pulseAnimation = nil
    }
    
    // MARK: - Touch Feedback
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesBegan(touches, with: event)
        animateTap(isPressed: true)
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesEnded(touches, with: event)
        animateTap(isPressed: false)
    }
    
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesCancelled(touches, with: event)
        animateTap(isPressed: false)
    }
    
    private func animateTap(isPressed: Bool) {
        guard !UIAccessibility.isReduceMotionEnabled else { return }
        
        let scale: CGFloat = isPressed ? 0.97 : 1.0
        let alpha: CGFloat = isPressed ? 0.8 : 1.0
        
        UIView.animate(
            withDuration: 0.15,
            delay: 0,
            options: [.allowUserInteraction, .beginFromCurrentState],
            animations: {
                self.cardView.transform = CGAffineTransform(scaleX: scale, y: scale)
                self.cardView.alpha = alpha
            }
        )
    }
    
    // MARK: - Reuse
    
    override func prepareForReuse() {
        super.prepareForReuse()
        stopPulseAnimation()
        cardView.layer.borderWidth = 0
        cardView.transform = .identity
        cardView.alpha = 1.0
        checkmarkImageView.alpha = 0
        infinityBadge.alpha = 0
        indexLabel.alpha = 1.0
        indexIconView.alpha = 0
        isCurrentClip = false
    }
}

