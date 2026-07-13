//
//  AppFont.swift
//  LanguageMirror
//
//  Brand type. Display/title text uses the system SERIF design — the
//  "museum plate" voice of the Six Wands universe (see brand/miri/).
//  Rounded survives for small friendly moments; body text stays default
//  for legibility, especially Hangul.
//

import UIKit

enum AppFont {

    // MARK: - Dynamic Type
    //
    // AppFont fonts SCALE with the user's Larger Text setting by default (via
    // UIFontMetrics), so content text grows for low-vision / older learners —
    // essential in an app where reading the sentence you shadow is the point.
    // Chrome that can't grow (nav/tab bars) opts out with `scales: false`.

    /// Map a point size to the nearest text style so scaling is proportional
    /// (large display text grows gently; small body/caption text grows more).
    private static func textStyle(for size: CGFloat) -> UIFont.TextStyle {
        switch size {
        case ..<12: return .caption2
        case ..<14: return .caption1
        case ..<16: return .subheadline
        case ..<20: return .body
        case ..<24: return .title3
        case ..<30: return .title2
        default:    return .title1
        }
    }

    private static func scaled(_ font: UIFont, size: CGFloat) -> UIFont {
        UIFontMetrics(forTextStyle: textStyle(for: size)).scaledFont(for: font)
    }

    /// Rounded system font at the given size/weight. Scales with Dynamic Type
    /// unless `scales: false`. Falls back to plain system if rounded design
    /// is unavailable.
    static func rounded(_ size: CGFloat, weight: UIFont.Weight = .regular, scales: Bool = true) -> UIFont {
        let base = UIFont.systemFont(ofSize: size, weight: weight)
        let designed = base.fontDescriptor.withDesign(.rounded).map { UIFont(descriptor: $0, size: size) } ?? base
        return scales ? scaled(designed, size: size) : designed
    }

    /// Serif system font (New York) — the museum-plate display face used for
    /// titles and section captions. Scales with Dynamic Type unless
    /// `scales: false`.
    static func plate(_ size: CGFloat, weight: UIFont.Weight = .regular, scales: Bool = true) -> UIFont {
        let base = UIFont.systemFont(ofSize: size, weight: weight)
        let designed = base.fontDescriptor.withDesign(.serif).map { UIFont(descriptor: $0, size: size) } ?? base
        return scales ? scaled(designed, size: size) : designed
    }

    /// Scaled plain system font — routes raw content labels (transcript
    /// sentences, glosses, clip titles) through Dynamic Type without the
    /// rounded/serif design.
    static func body(_ size: CGFloat, weight: UIFont.Weight = .regular, scales: Bool = true) -> UIFont {
        let base = UIFont.systemFont(ofSize: size, weight: weight)
        return scales ? scaled(base, size: size) : base
    }

    /// Letter-spaced, uppercased serif caption in antique gold — the
    /// engraved section-header treatment from the character sheet plates.
    static func plateCaption(_ text: String, size: CGFloat = 13) -> NSAttributedString {
        NSAttributedString(string: text.uppercased(), attributes: [
            .font: plate(size, weight: .semibold),
            .kern: size * 0.12,
            .foregroundColor: AppColors.antiqueGold,
        ])
    }

    /// Install global appearance for nav bars and the tab bar so titles and
    /// tab labels pick up the serif plate face and aqua accent everywhere.
    static func installGlobalAppearance() {
        let tint = AppColors.primaryAccent

        let nav = UINavigationBarAppearance()
        nav.configureWithDefaultBackground()
        // Chrome: fixed size (height-constrained bars can't grow safely).
        nav.largeTitleTextAttributes = [.font: plate(34, weight: .bold, scales: false)]
        nav.titleTextAttributes = [.font: plate(17, weight: .semibold, scales: false)]
        UINavigationBar.appearance().standardAppearance = nav
        UINavigationBar.appearance().scrollEdgeAppearance = nav
        UINavigationBar.appearance().compactAppearance = nav
        UINavigationBar.appearance().tintColor = tint

        let tab = UITabBarAppearance()
        tab.configureWithDefaultBackground()
        tab.shadowColor = AppColors.goldHairline  // gold rule atop the tab bar
        for item in [tab.stackedLayoutAppearance, tab.inlineLayoutAppearance, tab.compactInlineLayoutAppearance] {
            item.normal.titleTextAttributes = [.font: rounded(10, weight: .medium, scales: false)]
            item.selected.titleTextAttributes = [.font: rounded(10, weight: .semibold, scales: false)]
        }
        UITabBar.appearance().standardAppearance = tab
        UITabBar.appearance().scrollEdgeAppearance = tab
        UITabBar.appearance().tintColor = tint
    }
}
