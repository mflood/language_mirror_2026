//
//  AudioFileUtilities.swift
//  LanguageMirror
//
//  Created by Matthew Flood on 6/29/25.
//

import UIKit
import AVFoundation
import UniformTypeIdentifiers



/*


private func processDownloadedFile(at localURL: URL, originalURL: URL?) {
    // Do file operations on background queue

        // Validate that the temporary file exists
        guard FileManager.default.fileExists(atPath: localURL.path) else {
            DispatchQueue.main.async {
                self.hideLoading()
                self.showError("Downloaded file not found. Please try downloading again.")
            }
            return
        }
        
        // Get the documents directory and ensure it exists
        guard let documentsPath = self.ensureDocumentsDirectoryExists() else {
            DispatchQueue.main.async {
                self.hideLoading()
                self.showError("Could not access or create Documents directory")
            }
            return
        }
        
        // Create a unique filename to avoid conflicts
        let originalFileName = localURL.lastPathComponent
        let fileExtension = self.getFileExtension(from: localURL, originalURL: originalURL)
        let baseFileName = originalFileName.replacingOccurrences(of: ".\(fileExtension)", with: "")
        let uniqueFileName = "\(baseFileName)_\(Int(Date().timeIntervalSince1970)).\(fileExtension)"
        let destinationURL = documentsPath.appendingPathComponent(uniqueFileName)
        
        print("Moving file from: \(localURL.path)")
        print("Moving file to: \(destinationURL.path)")
        
        do {
            // Check if destination already exists and remove it
            if FileManager.default.fileExists(atPath: destinationURL.path) {
                try FileManager.default.removeItem(at: destinationURL)
            }
            
            // Move the file
            try FileManager.default.moveItem(at: localURL, to: destinationURL)
            
            print("File successfully moved to: \(destinationURL.path)")
            
            // Verify the file was moved successfully
            guard FileManager.default.fileExists(atPath: destinationURL.path) else {
                DispatchQueue.main.async {
                    self.hideLoading()
                    self.showError("File was not saved correctly. Please try again.")
                }
                return
            }
            
            // Move to main queue for UI updates and audio analysis
            DispatchQueue.main.async {
                self.hideLoading()
                self.analyzeAudioFile(at: destinationURL, originalURL: originalURL)
            }
            
        } catch {
            DispatchQueue.main.async {
                self.hideLoading()
                print("Error moving file: \(error)")
                print("Source URL: \(localURL)")
                print("Destination URL: \(destinationURL)")
                self.showError("Failed to save file: \(error.localizedDescription)")
            }
        }
    
    // Show loading immediately on main queue
    DispatchQueue.main.async {
        self.showLoading(message: "Analyzing audio file...")
    }
}

private func analyzeAudioFile(at url: URL, originalURL: URL?) {
    Task {
        do {
            let asset = AVAsset(url: url)
            
            // Use the new async API for iOS 16+
            let duration = try await asset.load(.duration)
            let tracks = try await asset.loadTracks(withMediaType: .audio)
            
            let durationSeconds = CMTimeGetSeconds(duration)
            var format = "Unknown"
            
            // Get format from the first audio track
            if let track = tracks.first {
                let formatDescriptions = try await track.load(.formatDescriptions)
                if let formatDescription = formatDescriptions.first {
                    let audioFormat = CMAudioFormatDescriptionGetStreamBasicDescription(formatDescription)
                    if let audioFormat = audioFormat {
                        let formatID = audioFormat.pointee.mFormatID
                        switch formatID {
                        case kAudioFormatLinearPCM:
                            format = "Linear PCM"
                        case kAudioFormatMPEG4AAC:
                            format = "AAC"
                        case kAudioFormatMPEGLayer3:
                            format = "MP3"
                        case kAudioFormatAppleLossless:
                            format = "Apple Lossless"
                        case kAudioFormatFLAC:
                            format = "FLAC"
                        default:
                            format = String(describing: formatID)
                        }
                    }
                }
            }
            
            // Get file size
            let fileSize = getFileSize(url: url)
            
            // Update UI on main queue
            await MainActor.run {
                self.hideLoading()
                
                // Show file info
                self.showFileInfo(
                    name: originalURL?.lastPathComponent ?? url.lastPathComponent,
                    size: fileSize,
                    duration: durationSeconds,
                    format: format
                )
                
                // Save to recent downloads
                let downloadedAudio = SiivDownloadedAudio(
                    id: UUID().uuidString,
                    name: originalURL?.lastPathComponent ?? url.lastPathComponent,
                    url: self.downloadURL?.absoluteString ?? "",
                    downloadDate: Date(),
                    fileSize: fileSize,
                    duration: durationSeconds
                )
                
                self.recentDownloads.insert(downloadedAudio, at: 0)
                self.updateRecentDownloadsUI()
                
                // Notify delegate
                self.delegate?.downloadFromURLDidFinish(url, name: url.lastPathComponent)
            }
            
        } catch {
            await MainActor.run {
                self.hideLoading()
                self.showError("Failed to analyze audio file: \(error.localizedDescription)")
            }
        }
    }
}

private func getFileSize(url: URL) -> String {
    do {
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        if let fileSize = attributes[.size] as? Int64 {
            return ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file)
        }
    } catch {
        print("Error getting file size: \(error)")
    }
    return "Unknown"
}


*/
