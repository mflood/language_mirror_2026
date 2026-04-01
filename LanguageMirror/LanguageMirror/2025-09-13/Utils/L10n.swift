//
//  L10n.swift
//  LanguageMirror
//
//  Convenience wrapper for NSLocalizedString to reduce boilerplate.
//

import Foundation

/// Short alias for NSLocalizedString.
/// Usage: `L10n("tab.library")` or `L10n("alert.delete_title")`
func L10n(_ key: String, comment: String = "") -> String {
    NSLocalizedString(key, comment: comment)
}

/// Format a localized string with arguments.
/// Usage: `L10nf("clip.progress", clipIndex + 1, clipCount)`
func L10nf(_ key: String, _ args: CVarArg..., comment: String = "") -> String {
    String(format: NSLocalizedString(key, comment: comment), arguments: args)
}
