//
//  LibraryViewController.swift
//  LanguageMirror
//
//  Created by Matthew Flood on 9/13/25.
//
import UIKit

protocol LibraryViewControllerDelegate: AnyObject {
    func libraryViewController(_ vc: LibraryViewController, didSelect track: Track)
}

final class LibraryViewController: UIViewController {
    private let service: LibraryService
    private var packs: [Pack] = []
    private var filteredPacks: [Pack] = []
    private var expandedPackIds: Set<String> = []
    private var sortOrder: SortOrder = .titleAZ
    private var isSearching = false
    
    weak var delegate: LibraryViewControllerDelegate?
    
    enum SortOrder: String, CaseIterable {
        case titleAZ = "Title A-Z"
        case titleZA = "Title Z-A"
        case dateNewest = "Date Added (Newest)"
        case dateOldest = "Date Added (Oldest)"
        case durationLongest = "Duration (Longest)"
        case durationShortest = "Duration (Shortest)"
    }

    init(service: LibraryService) {
        self.service = service
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private lazy var tableView: UITableView = {
        let tv = UITableView(frame: .zero, style: .insetGrouped)
        tv.translatesAutoresizingMaskIntoConstraints = false
        tv.dataSource = self
        tv.delegate = self
        tv.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
        tv.register(PackHeaderView.self, forHeaderFooterViewReuseIdentifier: "packHeader")
        return tv
    }()
    
    private lazy var searchController: UISearchController = {
        let sc = UISearchController(searchResultsController: nil)
        sc.searchResultsUpdater = self
        sc.obscuresBackgroundDuringPresentation = false
        sc.searchBar.placeholder = "Search tracks"
        return sc
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        navigationItem.largeTitleDisplayMode = .always
        navigationController?.navigationBar.prefersLargeTitles = true
        navigationItem.searchController = searchController
        navigationItem.hidesSearchBarWhenScrolling = false
        
        // Sort button
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            image: UIImage(systemName: "arrow.up.arrow.down"),
            style: .plain,
            target: self,
            action: #selector(sortTapped)
        )

        view.addSubview(tableView)
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        loadExpansionState()
        loadSortOrder()
        loadData()
        
        // Listen for library changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleLibraryChanged),
            name: .LibraryDidChange,
            object: nil
        )
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    @objc private func handleLibraryChanged() {
        loadData()
    }

    private func loadData() {
        packs = service.listNonEmptyPacks()
        applySort()
        filteredPacks = packs
        tableView.reloadData()
    }
    
    private func applySort() {
        for (index, var pack) in packs.enumerated() {
            pack.tracks = sortTracks(pack.tracks)
            packs[index] = pack
        }
    }
    
    private func sortTracks(_ tracks: [Track]) -> [Track] {
        switch sortOrder {
        case .titleAZ:
            return tracks.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
        case .titleZA:
            return tracks.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedDescending }
        case .dateNewest:
            return tracks.sorted { ($0.createdAt ?? Date.distantPast) > ($1.createdAt ?? Date.distantPast) }
        case .dateOldest:
            return tracks.sorted { ($0.createdAt ?? Date.distantPast) < ($1.createdAt ?? Date.distantPast) }
        case .durationLongest:
            return tracks.sorted { ($0.durationMs ?? 0) > ($1.durationMs ?? 0) }
        case .durationShortest:
            return tracks.sorted { ($0.durationMs ?? 0) < ($1.durationMs ?? 0) }
        }
    }
    
    @objc private func sortTapped() {
        let alert = UIAlertController(title: "Sort Tracks", message: nil, preferredStyle: .actionSheet)
        
        for order in SortOrder.allCases {
            let isSelected = order == sortOrder
            let title = isSelected ? "✓ \(order.rawValue)" : order.rawValue
            alert.addAction(UIAlertAction(title: title, style: .default) { [weak self] _ in
                self?.sortOrder = order
                self?.saveSortOrder()
                self?.loadData()
            })
        }
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        if let popover = alert.popoverPresentationController {
            popover.barButtonItem = navigationItem.rightBarButtonItem
        }
        
        present(alert, animated: true)
    }
    
    // MARK: - Persistence
    
    private func loadExpansionState() {
        if let saved = UserDefaults.standard.array(forKey: "LibraryExpandedPacks") as? [String] {
            expandedPackIds = Set(saved)
        }
    }
    
    private func saveExpansionState() {
        UserDefaults.standard.set(Array(expandedPackIds), forKey: "LibraryExpandedPacks")
    }
    
    private func loadSortOrder() {
        if let saved = UserDefaults.standard.string(forKey: "LibrarySortOrder"),
           let order = SortOrder(rawValue: saved) {
            sortOrder = order
        }
    }
    
    private func saveSortOrder() {
        UserDefaults.standard.set(sortOrder.rawValue, forKey: "LibrarySortOrder")
    }
}

extension LibraryViewController: UITableViewDataSource, UITableViewDelegate {
    
    func numberOfSections(in tableView: UITableView) -> Int {
        if isSearching {
            return 1 // Flat list when searching
        }
        return filteredPacks.count
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if isSearching {
            // Flat list of all matching tracks
            return filteredPacks.flatMap(\.tracks).count
        }
        
        let pack = filteredPacks[section]
        return expandedPackIds.contains(pack.id) ? pack.tracks.count : 0
    }
    
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        if isSearching {
            return nil // No pack headers when searching
        }
        
        guard let header = tableView.dequeueReusableHeaderFooterView(withIdentifier: "packHeader") as? PackHeaderView else {
            return nil
        }
        
        let pack = filteredPacks[section]
        let isExpanded = expandedPackIds.contains(pack.id)
        header.configure(title: pack.title, trackCount: pack.tracks.count, isExpanded: isExpanded)
        header.onTap = { [weak self] in
            self?.togglePackExpansion(pack.id)
        }
        
        return header
    }
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return isSearching ? 0 : 50
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        
        let track: Track
        if isSearching {
            let allTracks = filteredPacks.flatMap(\.tracks)
            track = allTracks[indexPath.row]
        } else {
            let pack = filteredPacks[indexPath.section]
            track = pack.tracks[indexPath.row]
        }
        
        var config = cell.defaultContentConfiguration()
        config.text = track.title
        
        // Build subtitle with duration and tags
        var subtitle = ""
        if let duration = track.durationMs {
            subtitle += formatDuration(duration)
        }
        if !track.tags.isEmpty {
            let tagString = track.tags.prefix(3).joined(separator: ", ")
            subtitle += subtitle.isEmpty ? tagString : " • \(tagString)"
        }
        config.secondaryText = subtitle
        
        cell.contentConfiguration = config
        cell.accessoryType = .disclosureIndicator
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        let track: Track
        if isSearching {
            let allTracks = filteredPacks.flatMap(\.tracks)
            track = allTracks[indexPath.row]
        } else {
            let pack = filteredPacks[indexPath.section]
            track = pack.tracks[indexPath.row]
        }
        
        delegate?.libraryViewController(self, didSelect: track)
    }
    
    private func togglePackExpansion(_ packId: String) {
        if expandedPackIds.contains(packId) {
            expandedPackIds.remove(packId)
        } else {
            expandedPackIds.insert(packId)
        }
        saveExpansionState()
        tableView.reloadData()
    }
    
    private func formatDuration(_ ms: Int) -> String {
        let totalSeconds = ms / 1000
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

extension LibraryViewController: UISearchResultsUpdating {
    func updateSearchResults(for searchController: UISearchController) {
        guard let searchText = searchController.searchBar.text?.trimmingCharacters(in: .whitespaces) else {
            isSearching = false
            filteredPacks = packs
            tableView.reloadData()
            return
        }
        
        if searchText.isEmpty {
            isSearching = false
            filteredPacks = packs
        } else {
            isSearching = true
            // Filter tracks by title
            filteredPacks = packs.compactMap { pack in
                let matchingTracks = pack.tracks.filter { track in
                    track.title.localizedCaseInsensitiveContains(searchText)
                }
                if matchingTracks.isEmpty { return nil }
                var filteredPack = pack
                filteredPack.tracks = matchingTracks
                return filteredPack
            }
        }
        
        tableView.reloadData()
    }
}

// MARK: - Pack Header View

final class PackHeaderView: UITableViewHeaderFooterView {
    private let titleLabel = UILabel()
    private let countBadge = UILabel()
    private let chevronImageView = UIImageView()
    var onTap: (() -> Void)?
    
    override init(reuseIdentifier: String?) {
        super.init(reuseIdentifier: reuseIdentifier)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        contentView.backgroundColor = .secondarySystemGroupedBackground
        
        titleLabel.font = .systemFont(ofSize: 17, weight: .semibold)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        
        countBadge.font = .systemFont(ofSize: 14, weight: .medium)
        countBadge.textColor = .secondaryLabel
        countBadge.translatesAutoresizingMaskIntoConstraints = false
        
        chevronImageView.contentMode = .center
        chevronImageView.tintColor = .secondaryLabel
        chevronImageView.translatesAutoresizingMaskIntoConstraints = false
        
        contentView.addSubview(titleLabel)
        contentView.addSubview(countBadge)
        contentView.addSubview(chevronImageView)
        
        NSLayoutConstraint.activate([
            chevronImageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            chevronImageView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            chevronImageView.widthAnchor.constraint(equalToConstant: 24),
            chevronImageView.heightAnchor.constraint(equalToConstant: 24),
            
            titleLabel.leadingAnchor.constraint(equalTo: chevronImageView.trailingAnchor, constant: 8),
            titleLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            
            countBadge.leadingAnchor.constraint(equalTo: titleLabel.trailingAnchor, constant: 8),
            countBadge.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            countBadge.trailingAnchor.constraint(lessThanOrEqualTo: contentView.trailingAnchor, constant: -16)
        ])
        
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTap))
        contentView.addGestureRecognizer(tapGesture)
    }
    
    func configure(title: String, trackCount: Int, isExpanded: Bool) {
        titleLabel.text = title
        countBadge.text = "(\(trackCount))"
        chevronImageView.image = UIImage(systemName: isExpanded ? "chevron.down" : "chevron.right")
    }
    
    @objc private func handleTap() {
        onTap?()
    }
}
