//
//  AppColors.swift
//  LanguageMirror
//
//  Created by Matthew Flood on 9/13/25.
//

import UIKit

/// ADHD-friendly color system with full dark mode support
enum AppColors {
    
    // MARK: - Backgrounds
    
    /// Primary background - adapts to system
    static let primaryBackground = UIColor.systemBackground
    
    /// Secondary background - adapts to system
    static let secondaryBackground = UIColor.secondarySystemBackground
    
    /// Tertiary background - adapts to system
    static let tertiaryBackground = UIColor.tertiarySystemBackground
    
    /// Card background with soft depth
    static let cardBackground = UIColor { traitCollection in
        traitCollection.userInterfaceStyle == .dark
            ? UIColor(red: 0.15, green: 0.15, blue: 0.17, alpha: 1.0)  // Soft dark blue-gray
            : UIColor(red: 0.98, green: 0.98, blue: 1.0, alpha: 1.0)   // Soft cool white
    }
    
    /// Calm background for main views
    static let calmBackground = UIColor { traitCollection in
        traitCollection.userInterfaceStyle == .dark
            ? UIColor(red: 0.11, green: 0.12, blue: 0.14, alpha: 1.0)  // Deep blue-gray
            : UIColor(red: 0.97, green: 0.98, blue: 0.99, alpha: 1.0)  // Soft cool white
    }
    
    // MARK: - Text Colors
    
    static let primaryText = UIColor.label
    static let secondaryText = UIColor.secondaryLabel
    static let tertiaryText = UIColor.tertiaryLabel
    
    // MARK: - Accent Colors
    
    /// Primary accent color with appropriate brightness
    static let primaryAccent = UIColor { traitCollection in
        traitCollection.userInterfaceStyle == .dark
            ? UIColor(red: 0.4, green: 0.6, blue: 1.0, alpha: 1.0)   // Brighter blue
            : UIColor(red: 0.0, green: 0.48, blue: 1.0, alpha: 1.0)  // Standard blue
    }
    
    /// Gentle accent glow/tint
    static let accentGlow = UIColor { traitCollection in
        traitCollection.userInterfaceStyle == .dark
            ? UIColor.systemBlue.withAlphaComponent(0.25)  // Softer glow
            : UIColor.systemBlue.withAlphaComponent(0.08)  // Subtle tint
    }
    
    // MARK: - Duration Badge Colors (ADHD-friendly color coding)
    
    /// Short duration (0-2 min) - calming green
    static let durationShort = UIColor { traitCollection in
        traitCollection.userInterfaceStyle == .dark
            ? UIColor(red: 0.3, green: 0.8, blue: 0.5, alpha: 1.0)   // Bright green
            : UIColor(red: 0.2, green: 0.7, blue: 0.3, alpha: 1.0)   // Rich green
    }
    
    static let durationShortBackground = UIColor { traitCollection in
        traitCollection.userInterfaceStyle == .dark
            ? UIColor(red: 0.2, green: 0.6, blue: 0.4, alpha: 0.3)   // Muted green bg
            : UIColor(red: 0.7, green: 0.95, blue: 0.8, alpha: 1.0)  // Soft green bg
    }
    
    /// Medium duration (2-5 min) - neutral amber
    static let durationMedium = UIColor { traitCollection in
        traitCollection.userInterfaceStyle == .dark
            ? UIColor(red: 1.0, green: 0.8, blue: 0.4, alpha: 1.0)   // Bright amber
            : UIColor(red: 0.8, green: 0.6, blue: 0.2, alpha: 1.0)   // Rich amber
    }
    
    static let durationMediumBackground = UIColor { traitCollection in
        traitCollection.userInterfaceStyle == .dark
            ? UIColor(red: 0.6, green: 0.5, blue: 0.3, alpha: 0.3)   // Muted amber bg
            : UIColor(red: 1.0, green: 0.95, blue: 0.7, alpha: 1.0)  // Soft yellow bg
    }
    
    /// Long duration (5+ min) - informative blue
    static let durationLong = UIColor { traitCollection in
        traitCollection.userInterfaceStyle == .dark
            ? UIColor(red: 0.4, green: 0.7, blue: 1.0, alpha: 1.0)   // Bright blue
            : UIColor(red: 0.2, green: 0.5, blue: 0.9, alpha: 1.0)   // Rich blue
    }
    
    static let durationLongBackground = UIColor { traitCollection in
        traitCollection.userInterfaceStyle == .dark
            ? UIColor(red: 0.3, green: 0.5, blue: 0.7, alpha: 0.3)   // Muted blue bg
            : UIColor(red: 0.85, green: 0.92, blue: 1.0, alpha: 1.0) // Soft blue bg
    }
    
    // MARK: - Pack Colors (Subtle, varied palette)
    
    private static let packBaseColors: [UIColor] = [
        .systemBlue,
        .systemGreen,
        .systemPurple,
        .systemTeal,
        .systemIndigo,
        .systemPink,
        .systemOrange,
        .systemCyan,
        .systemMint
    ]
    
    /// Get a pack background color by index
    static func packBackground(index: Int) -> UIColor {
        let baseColor = packBaseColors[index % packBaseColors.count]
        return UIColor { traitCollection in
            traitCollection.userInterfaceStyle == .dark
                ? baseColor.withAlphaComponent(0.18)  // More visible in dark
                : baseColor.withAlphaComponent(0.08)  // Very subtle in light
        }
    }
    
    /// Get a pack accent color by index
    static func packAccent(index: Int) -> UIColor {
        return packBaseColors[index % packBaseColors.count]
    }
    
    // MARK: - Separator & Border Colors
    
    static let separator = UIColor.separator
    static let softSeparator = UIColor { traitCollection in
        traitCollection.userInterfaceStyle == .dark
            ? UIColor.white.withAlphaComponent(0.06)
            : UIColor.black.withAlphaComponent(0.04)
    }
    
    // MARK: - Status Colors
    
    static let successColor = UIColor { traitCollection in
        traitCollection.userInterfaceStyle == .dark
            ? UIColor(red: 0.3, green: 0.8, blue: 0.5, alpha: 1.0)
            : UIColor(red: 0.2, green: 0.7, blue: 0.3, alpha: 1.0)
    }
    
    static let warningColor = UIColor { traitCollection in
        traitCollection.userInterfaceStyle == .dark
            ? UIColor(red: 1.0, green: 0.8, blue: 0.3, alpha: 1.0)
            : UIColor(red: 0.9, green: 0.6, blue: 0.0, alpha: 1.0)
    }
    
    static let errorColor = UIColor { traitCollection in
        traitCollection.userInterfaceStyle == .dark
            ? UIColor(red: 1.0, green: 0.4, blue: 0.4, alpha: 1.0)
            : UIColor(red: 0.9, green: 0.2, blue: 0.2, alpha: 1.0)
    }
}

// MARK: - UIView Extension for Easy Shadow/Glow

extension UIView {
    /// Apply appropriate shadow or glow based on current appearance
    func applyAdaptiveShadow(radius: CGFloat = 8, opacity: Float = 0.08) {
        let isDarkMode = traitCollection.userInterfaceStyle == .dark
        
        layer.shadowColor = (isDarkMode ? UIColor.white : UIColor.black).cgColor
        layer.shadowOpacity = isDarkMode ? opacity * 0.5 : opacity
        layer.shadowOffset = isDarkMode ? CGSize(width: 0, height: 0) : CGSize(width: 0, height: 2)
        layer.shadowRadius = radius
        layer.masksToBounds = false
    }
    
    /// Apply neumorphic style (soft, tactile feel)
    func applyNeumorphicStyle(cornerRadius: CGFloat = 12) {
        let isDarkMode = traitCollection.userInterfaceStyle == .dark
        
        backgroundColor = isDarkMode 
            ? UIColor(white: 0.15, alpha: 1.0)
            : UIColor(white: 0.96, alpha: 1.0)
        
        layer.cornerRadius = cornerRadius
        layer.cornerCurve = .continuous  // Apple's squircle shape
        
        // Dual shadows for depth
        applyAdaptiveShadow(radius: 10, opacity: 0.1)
    }
    
    /// Update shadows when appearance changes
    func updateAdaptiveShadowForAppearance() {
        if layer.shadowOpacity > 0 {
            applyAdaptiveShadow(radius: layer.shadowRadius, opacity: layer.shadowOpacity)
        }
    }
}

