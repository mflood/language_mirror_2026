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

    /// Rounded system font at the given size/weight. Falls back to the plain
    /// system font if the rounded design is unavailable.
    static func rounded(_ size: CGFloat, weight: UIFont.Weight = .regular) -> UIFont {
        let base = UIFont.systemFont(ofSize: size, weight: weight)
        guard let descriptor = base.fontDescriptor.withDesign(.rounded) else { return base }
        return UIFont(descriptor: descriptor, size: size)
    }

    /// Serif system font (New York) — the museum-plate display face used for
    /// titles and section captions. Falls back to the plain system font.
    static func plate(_ size: CGFloat, weight: UIFont.Weight = .regular) -> UIFont {
        let base = UIFont.systemFont(ofSize: size, weight: weight)
        guard let descriptor = base.fontDescriptor.withDesign(.serif) else { return base }
        return UIFont(descriptor: descriptor, size: size)
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
        nav.largeTitleTextAttributes = [.font: plate(34, weight: .bold)]
        nav.titleTextAttributes = [.font: plate(17, weight: .semibold)]
        UINavigationBar.appearance().standardAppearance = nav
        UINavigationBar.appearance().scrollEdgeAppearance = nav
        UINavigationBar.appearance().compactAppearance = nav
        UINavigationBar.appearance().tintColor = tint

        let tab = UITabBarAppearance()
        tab.configureWithDefaultBackground()
        tab.shadowColor = AppColors.goldHairline  // gold rule atop the tab bar
        for item in [tab.stackedLayoutAppearance, tab.inlineLayoutAppearance, tab.compactInlineLayoutAppearance] {
            item.normal.titleTextAttributes = [.font: rounded(10, weight: .medium)]
            item.selected.titleTextAttributes = [.font: rounded(10, weight: .semibold)]
        }
        UITabBar.appearance().standardAppearance = tab
        UITabBar.appearance().scrollEdgeAppearance = tab
        UITabBar.appearance().tintColor = tint
    }
}
