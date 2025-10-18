//
//  DateExtensions.swift
//  LanguageMirror
//
//  Created by Matthew Flood on 6/29/25.
//

import Foundation


extension Date {
    static func from_yyyymmdd(_ isoDate: String) -> Date {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone(abbreviation: "UTC")
        guard let date = formatter.date(from: isoDate) else {
            fatalError("Invalid date format: \(isoDate)")
        }
        return date
    }
}
