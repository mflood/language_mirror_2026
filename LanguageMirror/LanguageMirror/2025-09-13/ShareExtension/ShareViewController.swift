//
//  ShareViewController.swift
//  LanguageMirrorShare
//
//  Created by Matthew Flood on 10/19/25.
//

import UIKit
import Social
import UniformTypeIdentifiers
import MobileCoreServices

class ShareViewController: UIViewController {
    
    // MARK: - UI Components
    
    private let iconImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.tintColor = .systemBlue
        if let image = UIImage(systemName: "waveform.circle.fill") {
            imageView.image = image
        }
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()
    
    private let statusLabel: UILabel = {
        let label = UILabel()
        label.textAlignment = .center
        label.font = .systemFont(ofSize: 17, weight: .medium)
        label.textColor = .label
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let activityIndicator: UIActivityIndicatorView = {
        let indicator = UIActivityIndicatorView(style: .medium)
        indicator.hidesWhenStopped = true
        indicator.translatesAutoresizingMaskIntoConstraints = false
        return indicator
    }()
    
    private let containerView: UIView = {
        let view = UIView()
        view.backgroundColor = .systemBackground
        view.layer.cornerRadius = 16
        view.layer.shadowColor = UIColor.black.cgColor
        view.layer.shadowOpacity = 0.1
        view.layer.shadowOffset = CGSize(width: 0, height: 4)
        view.layer.shadowRadius = 12
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        processSharedContent()
    }
    
    // MARK: - UI Setup
    
    private func setupUI() {
        view.backgroundColor = UIColor.black.withAlphaComponent(0.4)
        
        view.addSubview(containerView)
        containerView.addSubview(iconImageView)
        containerView.addSubview(statusLabel)
        containerView.addSubview(activityIndicator)
        
        NSLayoutConstraint.activate([
            // Container
            containerView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            containerView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            containerView.widthAnchor.constraint(equalToConstant: 280),
            containerView.heightAnchor.constraint(equalToConstant: 220),
            
            // Icon
            iconImageView.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 32),
            iconImageView.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            iconImageView.widthAnchor.constraint(equalToConstant: 64),
            iconImageView.heightAnchor.constraint(equalToConstant: 64),
            
            // Status Label
            statusLabel.topAnchor.constraint(equalTo: iconImageView.bottomAnchor, constant: 24),
            statusLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 20),
            statusLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -20),
            
            // Activity Indicator
            activityIndicator.topAnchor.constraint(equalTo: statusLabel.bottomAnchor, constant: 16),
            activityIndicator.centerXAnchor.constraint(equalTo: containerView.centerXAnchor)
        ])
        
        statusLabel.text = "Preparing audio..."
        activityIndicator.startAnimating()
    }
    
    // MARK: - Content Processing
    
    private func processSharedContent() {
        guard let extensionItem = extensionContext?.inputItems.first as? NSExtensionItem,
              let itemProvider = extensionItem.attachments?.first else {
            showError("No audio file found")
            return
        }
        
        // Try to load as audio file
        if itemProvider.hasItemConformingToTypeIdentifier(UTType.audio.identifier) {
            loadAudioFile(from: itemProvider)
        } else if itemProvider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
            loadFileURL(from: itemProvider)
        } else {
            showError("File type not supported")
        }
    }
    
    private func loadAudioFile(from itemProvider: NSItemProvider) {
        itemProvider.loadFileRepresentation(forTypeIdentifier: UTType.audio.identifier) { [weak self] url, error in
            DispatchQueue.main.async {
                if let error = error {
                    self?.showError("Failed to access file: \(error.localizedDescription)")
                    return
                }
                
                guard let url = url else {
                    self?.showError("Invalid file URL")
                    return
                }
                
                self?.handleAudioFile(at: url)
            }
        }
    }
    
    private func loadFileURL(from itemProvider: NSItemProvider) {
        itemProvider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { [weak self] (item, error) in
            DispatchQueue.main.async {
                if let error = error {
                    self?.showError("Failed to access file: \(error.localizedDescription)")
                    return
                }
                
                guard let url = item as? URL else {
                    self?.showError("Invalid file URL")
                    return
                }
                
                self?.handleAudioFile(at: url)
            }
        }
    }
    
    private func handleAudioFile(at url: URL) {
        do {
            // Debug logging
            print("[ShareExtension] Attempting to import file: \(url.path)")
            print("[ShareExtension] File exists: \(FileManager.default.fileExists(atPath: url.path))")
            
            // Queue the file for import
            let sourceName = url.lastPathComponent
            _ = try SharedImportManager.enqueuePendingImport(sourceURL: url, sourceName: sourceName)
            
            // Show success
            showSuccess()
        } catch SharedImportError.appGroupNotConfigured {
            showError("App Group not configured. Please rebuild the app.")
        } catch SharedImportError.invalidFileURL {
            showError("File not accessible. Try a different file.")
        } catch SharedImportError.copyFailed {
            showError("Failed to copy file. Check permissions.")
        } catch {
            showError("Error: \(error.localizedDescription)")
        }
    }
    
    // MARK: - UI Feedback
    
    private func showSuccess() {
        activityIndicator.stopAnimating()
        iconImageView.image = UIImage(systemName: "checkmark.circle.fill")
        iconImageView.tintColor = .systemGreen
        statusLabel.text = "Added to LanguageMirror"
        
        // Add haptic feedback
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        
        // Auto-dismiss after a short delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
        }
    }
    
    private func showError(_ message: String) {
        activityIndicator.stopAnimating()
        iconImageView.image = UIImage(systemName: "exclamationmark.triangle.fill")
        iconImageView.tintColor = .systemRed
        statusLabel.text = message
        
        // Add haptic feedback
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.error)
        
        // Auto-dismiss after showing error
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            self?.extensionContext?.cancelRequest(withError: NSError(domain: "com.sixwands.languagemirror.share", code: -1, userInfo: [NSLocalizedDescriptionKey: message]))
        }
    }
}

