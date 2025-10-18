//
//  PackSelectionViewController.swift
//  LanguageMirror
//
//  Created by AI Assistant on 10/18/25.
//

import UIKit

@MainActor
final class PackSelectionViewController: UITableViewController {
    
    private let manifestLoader: EmbeddedBundleManifestLoader
    private var packs: [EmbeddedPackMetadata] = []
    private var isLoading = false
    
    var onPackSelected: ((String) -> Void)?
    
    init(manifestLoader: EmbeddedBundleManifestLoader) {
        self.manifestLoader = manifestLoader
        super.init(style: .insetGrouped)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        title = "Select Pack to Import"
        view.backgroundColor = .systemBackground
        
        tableView.register(PackCell.self, forCellReuseIdentifier: "PackCell")
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 80
        
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .cancel,
            target: self,
            action: #selector(cancelTapped)
        )
        
        loadPacks()
    }
    
    @objc private func cancelTapped() {
        dismiss(animated: true)
    }
    
    private func loadPacks() {
        guard !isLoading else { return }
        isLoading = true
        
        // Show spinner while loading
        let spinner = UIActivityIndicatorView(style: .medium)
        spinner.startAnimating()
        navigationItem.rightBarButtonItem = UIBarButtonItem(customView: spinner)
        
        Task {
            do {
                let loadedPacks = try await manifestLoader.loadAvailablePacks()
                self.packs = loadedPacks
                self.tableView.reloadData()
                self.navigationItem.rightBarButtonItem = nil
            } catch {
                self.showError("Failed to load packs: \(error.localizedDescription)")
                self.navigationItem.rightBarButtonItem = nil
            }
            self.isLoading = false
        }
    }
    
    private func showError(_ message: String) {
        let alert = UIAlertController(
            title: "Error",
            message: message,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
    
    // MARK: - Table View Data Source
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return packs.count
    }
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return packs.isEmpty ? nil : "Available Packs"
    }
    
    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        return packs.isEmpty ? "Loading available packs..." : "Select a pack to import into your library."
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "PackCell", for: indexPath) as! PackCell
        let pack = packs[indexPath.row]
        cell.configure(with: pack)
        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        let pack = packs[indexPath.row]
        
        // Show confirmation alert
        let alert = UIAlertController(
            title: "Import \(pack.title)?",
            message: "This will import \(pack.trackCount) track\(pack.trackCount == 1 ? "" : "s") into your library.",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Import", style: .default) { [weak self] _ in
            self?.dismiss(animated: true) {
                self?.onPackSelected?(pack.id)
            }
        })
        
        present(alert, animated: true)
    }
}

// MARK: - Pack Cell

private class PackCell: UITableViewCell {
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: .subtitle, reuseIdentifier: reuseIdentifier)
        accessoryType = .disclosureIndicator
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func configure(with pack: EmbeddedPackMetadata) {
        var config = defaultContentConfiguration()
        config.text = pack.title
        config.secondaryText = pack.description
        
        // Style
        config.textProperties.font = .systemFont(ofSize: 17, weight: .medium)
        config.secondaryTextProperties.font = .systemFont(ofSize: 14)
        config.secondaryTextProperties.color = .secondaryLabel
        config.secondaryTextProperties.numberOfLines = 2
        
        contentConfiguration = config
    }
}

