//
//  UuidTools.swift
//  LanguageMirror
//
//  Created by Matthew Flood on 10/12/25.
//

import Foundation
import CryptoKit

func norm(_ s: String) -> String {
    s.trimmingCharacters(in: .whitespacesAndNewlines)
     .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
}

// ---- v5 UUID (SHA-1) ----
func uuid5(namespace: UUID, name: String) -> UUID {
    let nsData = withUnsafeBytes(of: namespace.uuid) { Data($0) }
    let nameData = Data(name.utf8)
    let digest = Insecure.SHA1.hash(data: nsData + nameData)
    var bytes = Array(digest.prefix(16))
    bytes[6] = (bytes[6] & 0x0F) | 0x50   // version 5
    bytes[8] = (bytes[8] & 0x3F) | 0x80   // RFC 4122 variant
    var tup: uuid_t = (0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0)
    withUnsafeMutableBytes(of: &tup) { dst in
        bytes.withUnsafeBytes { src in dst.copyBytes(from: src) }
    }
    return UUID(uuid: tup)
}

