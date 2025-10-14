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

extension UUID {
    static let namespaceDNS = UUID(uuidString: "6ba7b810-9dad-11d1-80b4-00c04fd430c8")!
    static let namespaceFromVideo = UUID(uuidString: "7A13F348-6A30-564F-B3D4-4FEE030A1A18")!
    static let namespaceFromMemo = UUID(uuidString: "C0674F2C-FDBF-516B-BA29-593F3A20516D")!
    static let namespaceFromRecording = UUID(uuidString: "721FC41D-3F41-5A3C-AE53-6DABDE5E84EC")!
    static let namespaceDownloadedFile = UUID(uuidString: "1999F2D9-E717-59D7-B29C-A133AF2778C6")!
}

/*
func createInternalUUIDs() {
    // Utility function to generate and print internal UUIDs
    let dnsNamespace = UUID(uuidString: "6ba7b810-9dad-11d1-80b4-00c04fd430c8")! // DNS namespace
    let namespaceFromVideo = uuid5(namespace: UUID.namespaceDNS, name: norm("Audio from Video"))
    let namespaceFromMemo = uuid5(namespace: UUID.namespaceDNS, name: norm("Imported Local Audio"))
    let namespaceFromRecording = uuid5(namespace: UUID.namespaceDNS, name: norm("Recorded Audio"))
    let namespaceDownloadedFile = uuid5(namespace: UUID.namespaceDNS, name: norm("Downloaded Audio"))
        
    print("dnsNamespace: \(dnsNamespace)")
    print("namespaceFromVideo: \(namespaceFromVideo)")
    print("namespaceFromMemo: \(namespaceFromMemo)")
    print("namespaceFromRecording: \(namespaceFromRecording)")
    print("namespaceDownloadedFile: \(namespaceDownloadedFile)")

}
*/
