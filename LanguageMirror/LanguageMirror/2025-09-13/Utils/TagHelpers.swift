//
//  TagHelpers.swift
//  LanguageMirror
//
//  Created by Matthew Flood on 10/18/25.
//

import Foundation

func normalizeTag(_ tag: String) -> String {
    return tag
        .lowercased()
        .trimmingCharacters(in: .whitespacesAndNewlines)
        .replacingOccurrences(of: " ", with: "-")
        .replacingOccurrences(of: "_", with: "-")
}

func autoTagsForTrack(sourceType: AudioSourceType, languageCode: String?, fileExtension: String?) -> [String] {
    var tags: [String] = []
    
    // Source type tag
    switch sourceType {
    case .videoExtract:
        tags.append("video-extract")
    case .voiceMemo:
        tags.append("voice-memo")
    case .localRecording:
        tags.append("recording")
    case .youtube:
        tags.append("youtube")
    case .tts:
        tags.append("tts")
    case .textbook:
        tags.append("imported")
    }
    
    // Language tag
    if let lang = languageCode {
        // Extract language from code like "ko-KR" -> "korean", "en-US" -> "english"
        let langPrefix = lang.prefix(2).lowercased()
        switch langPrefix {
        case "ko": tags.append("korean")
        case "en": tags.append("english")
        case "zh": tags.append("chinese")
        case "ja": tags.append("japanese")
        case "es": tags.append("spanish")
        case "fr": tags.append("french")
        case "de": tags.append("german")
        case "it": tags.append("italian")
        default: tags.append(langPrefix)
        }
    }
    
    // File format tag
    if let ext = fileExtension?.lowercased() {
        tags.append(ext)
    }
    
    return tags.map { normalizeTag($0) }
}

