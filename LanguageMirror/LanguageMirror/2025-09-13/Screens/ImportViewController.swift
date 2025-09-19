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

final class ImportViewController: UITableViewController, UIDocumentPickerDelegate {

    private let importer: ImportService

    init(importService: ImportService) {
        self.importer = importService
        super.init(style: .insetGrouped)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private enum Row: Int, CaseIterable {
        case fromVideo, fromFiles, record, fromURL, fromS3Bundle, installSample
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Help", style: .plain, target: self, action: #selector(helpTapped))
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { Row.allCases.count }
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? { "Sources" }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        var cfg = cell.defaultContentConfiguration()
        switch Row(rawValue: indexPath.row)! {
        case .fromVideo:
            cfg.text = "Import audio from Video"
            cfg.secondaryText = "Pick a video and extract audio (m4a)"
        case .fromFiles:
            cfg.text = "Import from Files / Voice Memos"
            cfg.secondaryText = "Choose audio files via Files app"
        case .record:
            cfg.text = "Record audio"
            cfg.secondaryText = "Capture new audio and add to library"
        case .fromURL:
            cfg.text = "Download from URL"
            cfg.secondaryText = "mp3 / m4a / wav direct link"
        case .fromS3Bundle:
            cfg.text = "Install S3 bundle"
            cfg.secondaryText = "Load bundle manifest and tracks"
        case .installSample:
            cfg.text = "Install free sample bundle"
            cfg.secondaryText = "Ships with the app"
        }
        cell.contentConfiguration = cfg
        cell.accessoryType = .disclosureIndicator
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
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
            self?.runImport(.recordedFile(url: url))
        }
        navigationController?.pushViewController(vc, animated: true)
    }

    private func promptForURL() {
        let a = UIAlertController(title: "Download from URL", message: "Enter a direct link to an audio file.", preferredStyle: .alert)
        a.addTextField { tf in tf.placeholder = "https://…/file.mp3" ; tf.keyboardType = .URL ; tf.autocapitalizationType = .none }
        a.addTextField { tf in tf.placeholder = "Optional title" }
        a.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        a.addAction(UIAlertAction(title: "Download", style: .default, handler: { [weak self] _ in
            guard let s = a.textFields?.first?.text?.trimmingCharacters(in: .whitespacesAndNewlines),
                  let u = URL(string: s) else { return }
            let title = a.textFields?[1].text
            self?.runImport(.remoteURL(url: u, suggestedTitle: title?.isEmpty == false ? title : nil))
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
            self?.runImport(.bundleManifest(url: u))
        }))
        present(a, animated: true)
    }

    private func runEmbeddedSample() {
        runImport(.embeddedSample)
    }

    // MARK: - Import runner w/ simple spinner

    private func runImport(_ src: ImportSource) {
        let spinner = UIActivityIndicatorView(style: .large)
        spinner.startAnimating()
        let host = UIViewController()
        host.view.backgroundColor = .systemBackground
        host.view.addSubview(spinner)
        spinner.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            spinner.centerXAnchor.constraint(equalTo: host.view.centerXAnchor),
            spinner.centerYAnchor.constraint(equalTo: host.view.centerYAnchor),
        ])
        host.modalPresentationStyle = .formSheet
        present(host, animated: true)

        importer.import(source: src) { [weak self] result in
            host.dismiss(animated: true) {
                switch result {
                case .failure(let e):
                    self?.alert("Import Failed", e.localizedDescription)
                case .success(let tracks):
                    let msg = tracks.isEmpty ? "No tracks imported." : "Imported \(tracks.count) track(s)."
                    self?.alert("Done", msg)
                }
            }
        }
    }

    // MARK: - Helpers

    @objc private func helpTapped() {
        alert("Tips", """
- Voice Memos: open “Files” → On My iPhone → Voice Memos.
- Videos: pick a video; we’ll extract audio as M4A.
- S3 bundles: host a JSON manifest with track URLs and optional segments.
""")
    }

    private func alert(_ title: String, _ msg: String) {
        let a = UIAlertController(title: title, message: msg, preferredStyle: .alert)
        a.addAction(UIAlertAction(title: "OK", style: .default))
        present(a, animated: true)
    }

    // MARK: - UIDocumentPickerDelegate

    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard let url = urls.first else { return }
        // Security-scoped
        let needs = url.startAccessingSecurityScopedResource()
        defer { if needs { url.stopAccessingSecurityScopedResource() } }
        runImport(.audioFile(url: url))
    }
}


extension ImportViewController: PHPickerViewControllerDelegate {
    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        dismiss(animated: true)
        guard let item = results.first else { return }
        if item.itemProvider.hasItemConformingToTypeIdentifier(UTType.movie.identifier) {
            item.itemProvider.loadFileRepresentation(forTypeIdentifier: UTType.movie.identifier) { [weak self] url, err in
                if let url = url {
                    self?.runImport(.videoFile(url: url))
                } else if let err = err {
                    DispatchQueue.main.async { self?.alert("Pick Failed", err.localizedDescription) }
                }
            }
        }
    }
}
