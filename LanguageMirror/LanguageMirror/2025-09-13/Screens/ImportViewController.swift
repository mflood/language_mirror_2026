//
//  ImportViewController.swift
//  LanguageMirror
//
//  Created by Matthew Flood on 9/13/25.
//
// path: Screens/ImportViewController.swift
import UIKit
import PhotosUI
import UniformTypeIdentifiers
import AVFoundation

@MainActor
final class ImportViewController: UITableViewController, UIDocumentPickerDelegate {

    private let importer: ImportService
    private var currentImportTask: Task<Void, Never>?
    private var progressViewController: UIViewController?
    
    init(importService: ImportService) {
        self.importer = importService
        super.init(style: .insetGrouped)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private enum Row: Int, CaseIterable {
        case fromVideo, fromFiles, record, fromURL, fromS3Bundle, installSample
        
        var title: String {
            switch self {
            case .fromVideo: return "Import from Video"
            case .fromFiles: return "Import from Files"
            case .record: return "Record Audio"
            case .fromURL: return "Download from URL"
            case .fromS3Bundle: return "Install S3 Bundle"
            case .installSample: return "Install Free Packs"
            }
        }
        
        var description: String {
            switch self {
            case .fromVideo: return "Extract audio from video files"
            case .fromFiles: return "Browse Files app or use Share button"
            case .record: return "Record new audio with your mic"
            case .fromURL: return "Download mp3, m4a, or wav files"
            case .fromS3Bundle: return "Load bundle from manifest URL"
            case .installSample: return "Pre-made learning packs"
            }
        }
        
        var iconName: String {
            switch self {
            case .fromVideo: return "video.fill"
            case .fromFiles: return "folder.fill"
            case .record: return "mic.fill"
            case .fromURL: return "link"
            case .fromS3Bundle: return "cloud.fill"
            case .installSample: return "gift.fill"
            }
        }
        
        var iconColor: UIColor {
            switch self {
            case .fromVideo: return .systemPurple
            case .fromFiles: return .systemBlue
            case .record: return .systemRed
            case .fromURL: return .systemGreen
            case .fromS3Bundle: return .systemCyan
            case .installSample: return .systemOrange
            }
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = AppColors.primaryBackground
        tableView.backgroundColor = AppColors.primaryBackground
        tableView.register(ImportOptionCell.self, forCellReuseIdentifier: "importCell")
        tableView.separatorStyle = .none
        tableView.contentInset = UIEdgeInsets(top: 8, left: 0, bottom: 8, right: 0)
        
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            image: UIImage(systemName: "questionmark.circle"),
            style: .plain,
            target: self,
            action: #selector(helpTapped)
        )
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        currentImportTask?.cancel()
        currentImportTask = nil
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { 
        Row.allCases.count 
    }
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? { 
        "Choose an Import Method"
    }
    
    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        "Select how you'd like to add audio to your library. All imports are saved locally on your device."
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: "importCell", for: indexPath) as? ImportOptionCell else {
            return UITableViewCell()
        }
        
        let row = Row(rawValue: indexPath.row)!
        cell.configure(
            title: row.title,
            description: row.description,
            iconName: row.iconName,
            iconColor: row.iconColor
        )
        
        return cell
    }
    
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return UITableView.automaticDimension
    }
    
    override func tableView(_ tableView: UITableView, estimatedHeightForRowAt indexPath: IndexPath) -> CGFloat {
        return 88
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        // Haptic feedback
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
        
        switch Row(rawValue: indexPath.row)! {
        case .fromVideo: presentVideoPicker()
        case .fromFiles: presentFilePicker()
        case .record: presentRecorder()
        case .fromURL: promptForURL()
        case .fromS3Bundle: promptForS3Manifest()
        case .installSample: runEmbeddedSample()
        }
    }

    // MARK: - Actions

    private func presentVideoPicker() {
        var cfg = PHPickerConfiguration(photoLibrary: .shared())
        cfg.filter = .videos
        cfg.selectionLimit = 1
        let picker = PHPickerViewController(configuration: cfg)
        picker.delegate = self
        present(picker, animated: true)
    }

    private func presentFilePicker() {
        let types: [UTType] = [.audio]
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: types, asCopy: false)
        picker.allowsMultipleSelection = false
        picker.delegate = self
        present(picker, animated: true)
    }

    private func presentRecorder() {
        
        let vc = AudioRecorderViewController()
        vc.onFinished = { [weak self] url in
            guard let self = self else { return }
            // cancel any in-flight import
            self.currentImportTask?.cancel()
            self.currentImportTask = Task { @MainActor in
                await self.runImport(.recordedFile(url: url))
            }
        }
        navigationController?.pushViewController(vc, animated: true)
    }

    private func promptForURL() {
        let a = UIAlertController(
            title: "Download from URL",
            message: "Enter a direct link to an audio file.",
            preferredStyle: .alert
        )
        a.addTextField { tf in
            tf.placeholder = "https://…/file.mp3"
            tf.keyboardType = .URL
            tf.autocapitalizationType = .none
            tf.text = "https://www.blcup.com/File/Res3/6d99a4e6-ac1a-420d-ac1b-fa0ac889a530.mp3"
        }
        a.addTextField { tf in tf.placeholder = "Optional title" }

        a.addAction(UIAlertAction(title: "Cancel", style: .cancel))

        a.addAction(UIAlertAction(title: "Download", style: .default, handler: { [weak self] _ in
            guard
                let self,
                let s = a.textFields?.first?.text?.trimmingCharacters(in: .whitespacesAndNewlines),
                let u = URL(string: s)
            else { return }

            let title = a.textFields?[1].text
            let suggested = (title?.isEmpty == false) ? title : nil

            // cancel any prior import and start a new async task
            self.currentImportTask?.cancel()
            self.currentImportTask = Task { @MainActor in
                await self.runImport(.remoteURL(url: u, suggestedTitle: suggested))
            }
        }))

        present(a, animated: true)
    }


    private func promptForS3Manifest() {
        let a = UIAlertController(title: "S3 Bundle Manifest", message: "Enter the URL of a JSON manifest.", preferredStyle: .alert)
        a.addTextField { tf in tf.placeholder = "https://…/bundle.json" ; tf.keyboardType = .URL ; tf.autocapitalizationType = .none }
        a.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        a.addAction(UIAlertAction(title: "Install", style: .default, handler: { [weak self] _ in
            guard let s = a.textFields?.first?.text?.trimmingCharacters(in: .whitespacesAndNewlines),
                  let u = URL(string: s) else { return }
            // self?.runImport(.bundleManifest(url: u))
        }))
        present(a, animated: true)
    }

    private func runEmbeddedSample() {
        // Show pack selection screen
        let manifestLoader = SampleImporterFactory.make(useMock: false)
        let packSelectionVC = PackSelectionViewController(manifestLoader: manifestLoader)
        
        packSelectionVC.onPackSelected = { [weak self] packId in
            guard let self = self else { return }
            // Cancel any in-flight import
            self.currentImportTask?.cancel()
            self.currentImportTask = Task {
                await self.runImport(.embeddedPack(packId: packId))
            }
        }
        
        let nav = UINavigationController(rootViewController: packSelectionVC)
        present(nav, animated: true)
    }

    // MARK: - Import runner with beautiful progress UI

    private func runImport(_ src: ImportSource) async {
        // Create and present beautiful progress view
        let progressView = ImportProgressView(frame: .zero)
        progressView.translatesAutoresizingMaskIntoConstraints = false
        progressView.updateState(.processing)
        
        let host = UIViewController()
        host.view.backgroundColor = .clear
        host.view.addSubview(progressView)
        host.modalPresentationStyle = .overFullScreen
        host.modalTransitionStyle = .crossDissolve
        
        NSLayoutConstraint.activate([
            progressView.topAnchor.constraint(equalTo: host.view.topAnchor),
            progressView.leadingAnchor.constraint(equalTo: host.view.leadingAnchor),
            progressView.trailingAnchor.constraint(equalTo: host.view.trailingAnchor),
            progressView.bottomAnchor.constraint(equalTo: host.view.bottomAnchor)
        ])
        
        progressView.onCancel = { [weak self] in
            self?.currentImportTask?.cancel()
            host.dismiss(animated: true)
        }
        
        progressViewController = host
        present(host, animated: true)

        do {
            let tracks = try await importer.performImport(source: src) { progress in
                DispatchQueue.main.async {
                    progressView.updateState(.downloading(progress: progress))
                }
            }
            
            // Show success state
            let count = tracks.count
            let message = count == 1 
                ? "Added 1 track to your library" 
                : "Added \(count) tracks to your library"
            
            progressView.updateState(.success(message: message))
            
            // Notify about new tracks
            if !tracks.isEmpty {
                let trackId = tracks[0].id
                NotificationCenter.default.post(
                    name: .libraryDidAddTrack,
                    object: nil,
                    userInfo: ["trackID": trackId]
                )
            }
            
            // Dismiss after showing success
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                host.dismiss(animated: true)
            }
            
        } catch is CancellationError {
            // User cancelled - already dismissed
        } catch {
            // Show error state with helpful message
            let message = friendlyErrorMessage(for: error)
            progressView.updateState(.error(message: message))
            
            // Let user dismiss manually
            progressView.onCancel = {
                host.dismiss(animated: true)
            }
        }
    }
    
    private func friendlyErrorMessage(for error: Error) -> String {
        let description = error.localizedDescription
        
        // Provide friendlier messages for common errors
        if description.contains("network") || description.contains("Internet") {
            return "Check your internet connection and try again."
        } else if description.contains("not found") || description.contains("404") {
            return "The file couldn't be found. Check the URL and try again."
        } else if description.contains("permission") || description.contains("access") {
            return "Unable to access the file. Check permissions."
        } else if description.contains("format") || description.contains("codec") {
            return "This file format isn't supported. Try mp3, m4a, or wav."
        } else {
            return description.isEmpty ? "Something went wrong. Please try again." : description
        }
    }

    // MARK: - Helpers

    @objc private func helpTapped() {
        let message = """
        📹 Import from Video
        Extract audio from any video file
        
        📁 Import from Files
        • Tap Share button in Voice Memos → LanguageMirror
        • Or browse: Files → On My iPhone → Voice Memos
        
        🎤 Record Audio
        Create new tracks with your microphone
        
        🔗 Download from URL
        Direct links to audio files (mp3, m4a, wav)
        
        ☁️ S3 Bundles
        Load pre-configured track collections
        
        🎁 Free Packs
        Pre-made learning content included with the app
        """
        
        alert("Import Help", message)
    }

    private func alert(_ title: String, _ msg: String) {
        let a = UIAlertController(title: title, message: msg, preferredStyle: .alert)
        a.addAction(UIAlertAction(title: "Got It", style: .default))
        present(a, animated: true)
    }
    
    // MARK: - Trait Collection
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        
        if traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
            view.backgroundColor = AppColors.primaryBackground
            tableView.backgroundColor = AppColors.primaryBackground
        }
    }

    // MARK: - UIDocumentPickerDelegate
    
    func documentPicker(_ controller: UIDocumentPickerViewController,
                        didPickDocumentsAt urls: [URL]) {
        guard let url = urls.first else { return }

        // cancel any in-flight import
        currentImportTask?.cancel()
        currentImportTask = Task { @MainActor in
            // keep the security scope for the entire async import
            let needs = url.startAccessingSecurityScopedResource()
            defer { if needs { url.stopAccessingSecurityScopedResource() } }
            await runImport(.audioFile(url: url))
            
        }
    }

}


extension ImportViewController: PHPickerViewControllerDelegate {
    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        dismiss(animated: true)

        guard
            let item = results.first?.itemProvider,
            item.hasItemConformingToTypeIdentifier(UTType.movie.identifier)
        else { return }

        Task { [weak self] in
            guard let self = self else { return }

            do {
                let safeURL: URL = try await withCheckedThrowingContinuation { continuation in
                    item.loadFileRepresentation(forTypeIdentifier: UTType.movie.identifier) { tempURL, error in
                        if let error = error {
                            continuation.resume(throwing: error)
                            return
                        }

                        guard let tempURL = tempURL else {
                            continuation.resume(throwing: VideoImportError.exportFailed(underlying: nil))
                            return
                        }

                        do {
                            let safeURL = FileManager.default.temporaryDirectory
                                .appendingPathComponent(UUID().uuidString + ".mov")
                            try FileManager.default.copyItem(at: tempURL, to: safeURL)
                            continuation.resume(returning: safeURL)
                        } catch {
                            continuation.resume(throwing: error)
                        }
                    }
                }

                await self.runImport(.videoFile(url: safeURL))
            } catch {
                self.alert("Pick Failed", error.localizedDescription)
            }
        }
    }
    
}



private extension NSItemProvider {
    func loadMovieFileURL() async throws -> URL {
        try await withCheckedThrowingContinuation { cont in
            self.loadFileRepresentation(forTypeIdentifier: UTType.movie.identifier) { url, err in
                if let err = err { cont.resume(throwing: err); return }
                guard let url else {
                    cont.resume(throwing: URLError(.fileDoesNotExist)); return
                }
                cont.resume(returning: url)
            }
        }
    }
}

