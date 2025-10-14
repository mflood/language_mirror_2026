//
//  UrlDownloaderFactory.swift
//  LanguageMirror
//
//  Created by Matthew Flood on 9/20/25.
//

import Foundation

public enum UrlDownloaderFactory {
    public static func make(useMock: Bool = false) -> UrlDownloaderProtocol {
        #if DEBUG
        if useMock {
            return MockUrlDownloader(totalDuration: 2.0, step: 0.1, errorMode: .none)
        }
        #endif
        return IOS18UrlDownloader()
    }
}
