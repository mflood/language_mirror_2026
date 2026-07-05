//
//  AppFont.swift
//  LanguageMirror
//
//  Brand type. The app uses the system font with the ROUNDED design for
//  display/title text — it reads friendlier and more distinctive than the
//  default system face (which felt like a template), without shipping a
//  custom font. Body text stays default for legibility, especially Hangul.
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

    /// Install global appearance for nav bars and the tab bar so titles and
    /// tab labels pick up the rounded brand face and aqua accent everywhere.
    static func installGlobalAppearance() {
        let tint = AppColors.primaryAccent

        let nav = UINavigationBarAppearance()
        nav.configureWithDefaultBackground()
        nav.largeTitleTextAttributes = [.font: rounded(34, weight: .bold)]
        nav.titleTextAttributes = [.font: rounded(17, weight: .semibold)]
        UINavigationBar.appearance().standardAppearance = nav
        UINavigationBar.appearance().scrollEdgeAppearance = nav
        UINavigationBar.appearance().compactAppearance = nav
        UINavigationBar.appearance().tintColor = tint

        let tab = UITabBarAppearance()
        tab.configureWithDefaultBackground()
        for item in [tab.stackedLayoutAppearance, tab.inlineLayoutAppearance, tab.compactInlineLayoutAppearance] {
            item.normal.titleTextAttributes = [.font: rounded(10, weight: .medium)]
            item.selected.titleTextAttributes = [.font: rounded(10, weight: .semibold)]
        }
        UITabBar.appearance().standardAppearance = tab
        UITabBar.appearance().scrollEdgeAppearance = tab
        UITabBar.appearance().tintColor = tint
    }
}
