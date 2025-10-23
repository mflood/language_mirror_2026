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
        tv.register(TrackCell.self, forCellReuseIdentifier: "trackCell")
        tv.register(PackHeaderView.self, forHeaderFooterViewReuseIdentifier: "packHeader")
        tv.backgroundColor = AppColors.primaryBackground
        tv.separatorStyle = .none  // Custom cells handle their own spacing
        tv.contentInset = UIEdgeInsets(top: 8, left: 0, bottom: 8, right: 0)
        return tv
    }()
    
    private lazy var searchController: UISearchController = {
        let sc = UISearchController(searchResultsController: nil)
        sc.searchResultsUpdater = self
        sc.obscuresBackgroundDuringPresentation = false
        sc.searchBar.placeholder = "Search tracks"
        return sc
    }()
    
    private var emptyStateView: EmptyStateView?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = AppColors.primaryBackground
        navigationItem.largeTitleDisplayMode = .always
        navigationController?.navigationBar.prefersLargeTitles = true
        navigationItem.searchController = searchController
        navigationItem.hidesSearchBarWhenScrolling = false
        
        // Sort button with better icon
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            image: UIImage(systemName: "arrow.up.arrow.down.circle"),
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
        
        // Add pull to refresh
        let refreshControl = UIRefreshControl()
        refreshControl.addTarget(self, action: #selector(handleRefresh), for: .valueChanged)
        tableView.refreshControl = refreshControl
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    @objc private func handleLibraryChanged() {
        DispatchQueue.main.async { [weak self] in
            self?.loadData()
        }
    }
    
    @objc private func handleRefresh() {
        loadData()
        
        // Add slight delay for visual feedback
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.tableView.refreshControl?.endRefreshing()
            
            // Haptic feedback
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
        }
    }

    private func loadData() {
        packs = service.listNonEmptyPacks()
        applySort()
        filteredPacks = packs
        tableView.reloadData()
        updateEmptyState()
    }
    
    // MARK: - Track Highlighting
    
    /// Highlight a specific track by ID (useful after importing)
    func highlightTrack(withId trackId: String) {
        // Reload data to ensure we have the latest tracks
        loadData()
        
        // Find the track in our data
        var targetIndexPath: IndexPath?
        
        for (sectionIndex, pack) in filteredPacks.enumerated() {
            for (rowIndex, track) in pack.tracks.enumerated() {
                if track.id == trackId {
                    targetIndexPath = IndexPath(row: rowIndex, section: sectionIndex)
                    break
                }
            }
            if targetIndexPath != nil { break }
        }
        
        guard let indexPath = targetIndexPath else {
            print("Could not find track with ID: \(trackId)")
            return
        }
        
        // Ensure the pack is expanded so the track is visible
        let pack = filteredPacks[indexPath.section]
        if !expandedPackIds.contains(pack.id) {
            expandedPackIds.insert(pack.id)
            tableView.reloadSections([indexPath.section], with: .fade)
        }
        
        // Scroll to the track with a slight delay to ensure the table is ready
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.tableView.scrollToRow(at: indexPath, at: .middle, animated: true)
            
            // Add a brief highlight animation
            if let cell = self.tableView.cellForRow(at: indexPath) as? TrackCell {
                cell.highlightBriefly()
            }
        }
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
                
                // Haptic feedback
                let generator = UIImpactFeedbackGenerator(style: .light)
                generator.impactOccurred()
            })
        }
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        if let popover = alert.popoverPresentationController {
            popover.barButtonItem = navigationItem.rightBarButtonItem
        }
        
        present(alert, animated: true)
    }
    
    // MARK: - Empty State
    
    private func updateEmptyState() {
        let isEmpty = filteredPacks.isEmpty || filteredPacks.allSatisfy { $0.tracks.isEmpty }
        
        if isEmpty && !isSearching {
            // Show empty library state
            if emptyStateView == nil {
                let empty = EmptyStateView.emptyLibrary { [weak self] in
                    // Handle action - could navigate to import or pack selection
                    self?.handleEmptyStateAction()
                }
                empty.translatesAutoresizingMaskIntoConstraints = false
                view.addSubview(empty)
                NSLayoutConstraint.activate([
                    empty.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
                    empty.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                    empty.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                    empty.bottomAnchor.constraint(equalTo: view.bottomAnchor)
                ])
                emptyStateView = empty
            }
            emptyStateView?.isHidden = false
            tableView.isHidden = true
        } else if isEmpty && isSearching {
            // Show no search results
            if emptyStateView == nil {
                let empty = EmptyStateView.noSearchResults()
                empty.translatesAutoresizingMaskIntoConstraints = false
                view.addSubview(empty)
                NSLayoutConstraint.activate([
                    empty.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
                    empty.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                    empty.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                    empty.bottomAnchor.constraint(equalTo: view.bottomAnchor)
                ])
                emptyStateView = empty
            }
            emptyStateView?.isHidden = false
            tableView.isHidden = true
        } else {
            emptyStateView?.isHidden = true
            tableView.isHidden = false
        }
    }
    
    private func handleEmptyStateAction() {
        // Could notify coordinator to navigate to import/pack selection
        // For now, just provide haptic feedback
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
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
    
    // MARK: - Trait Collection
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        
        if traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
            // Update colors for dark mode transition
            view.backgroundColor = AppColors.primaryBackground
            tableView.backgroundColor = AppColors.primaryBackground
        }
    }
}

// MARK: - UITableViewDataSource, UITableViewDelegate

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
        header.configure(
            title: pack.title,
            trackCount: pack.tracks.count,
            isExpanded: isExpanded,
            colorIndex: section
        )
        header.onTap = { [weak self] in
            self?.togglePackExpansion(packId: pack.id, section: section)
        }
        
        return header
    }
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return isSearching ? 0 : UITableView.automaticDimension
    }
    
    func tableView(_ tableView: UITableView, estimatedHeightForHeaderInSection section: Int) -> CGFloat {
        return 56
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: "trackCell", for: indexPath) as? TrackCell else {
            return UITableViewCell()
        }
        
        let track: Track
        if isSearching {
            let allTracks = filteredPacks.flatMap(\.tracks)
            track = allTracks[indexPath.row]
        } else {
            let pack = filteredPacks[indexPath.section]
            track = pack.tracks[indexPath.row]
        }
        
        // Configure with mock progress (could track real progress later)
        cell.configure(with: track, progress: 0.0)
        
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
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
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return UITableView.automaticDimension
    }
    
    func tableView(_ tableView: UITableView, estimatedHeightForRowAt indexPath: IndexPath) -> CGFloat {
        return 100
    }
    
    private func togglePackExpansion(packId: String, section: Int) {
        let isExpanding = !expandedPackIds.contains(packId)
        
        if isExpanding {
            expandedPackIds.insert(packId)
        } else {
            expandedPackIds.remove(packId)
        }
        saveExpansionState()
        
        // Smooth animated expansion
        tableView.performBatchUpdates({
            tableView.reloadSections(IndexSet(integer: section), with: .fade)
        }, completion: nil)
        
        // Haptic feedback
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
    }
}

// MARK: - UISearchResultsUpdating

extension LibraryViewController: UISearchResultsUpdating {
    func updateSearchResults(for searchController: UISearchController) {
        guard let searchText = searchController.searchBar.text?.trimmingCharacters(in: .whitespaces) else {
            isSearching = false
            filteredPacks = packs
            tableView.reloadData()
            updateEmptyState()
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
        updateEmptyState()
    }
}

// MARK: - Pack Header View (Enhanced)

final class PackHeaderView: UITableViewHeaderFooterView {
    
    private let containerView = UIView()
    private let colorStripeView = UIView()
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
        contentView.backgroundColor = .clear
        
        // Container with card-like appearance
        containerView.translatesAutoresizingMaskIntoConstraints = false
        containerView.backgroundColor = AppColors.cardBackground
        containerView.layer.cornerRadius = 12
        containerView.layer.cornerCurve = .continuous
        contentView.addSubview(containerView)
        
        // Color stripe (accent on the left)
        colorStripeView.translatesAutoresizingMaskIntoConstraints = false
        colorStripeView.layer.cornerRadius = 4
        colorStripeView.layer.cornerCurve = .continuous
        containerView.addSubview(colorStripeView)
        
        // Chevron
        chevronImageView.translatesAutoresizingMaskIntoConstraints = false
        chevronImageView.contentMode = .scaleAspectFit
        chevronImageView.tintColor = AppColors.secondaryText
        containerView.addSubview(chevronImageView)
        
        // Title
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = .systemFont(ofSize: 18, weight: .semibold)
        titleLabel.textColor = AppColors.primaryText
        containerView.addSubview(titleLabel)
        
        // Count badge
        countBadge.translatesAutoresizingMaskIntoConstraints = false
        countBadge.font = .systemFont(ofSize: 14, weight: .medium)
        countBadge.textColor = AppColors.secondaryText
        countBadge.backgroundColor = AppColors.tertiaryBackground
        countBadge.layer.cornerRadius = 10
        countBadge.layer.cornerCurve = .continuous
        countBadge.clipsToBounds = true
        countBadge.textAlignment = .center
        containerView.addSubview(countBadge)
        
        NSLayoutConstraint.activate([
            // Container with margins
            containerView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
            containerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            containerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            containerView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -4),
            containerView.heightAnchor.constraint(greaterThanOrEqualToConstant: 56),
            
            // Color stripe
            colorStripeView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 12),
            colorStripeView.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            colorStripeView.widthAnchor.constraint(equalToConstant: 4),
            colorStripeView.heightAnchor.constraint(equalToConstant: 32),
            
            // Chevron
            chevronImageView.leadingAnchor.constraint(equalTo: colorStripeView.trailingAnchor, constant: 12),
            chevronImageView.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            chevronImageView.widthAnchor.constraint(equalToConstant: 16),
            chevronImageView.heightAnchor.constraint(equalToConstant: 16),
            
            // Title
            titleLabel.leadingAnchor.constraint(equalTo: chevronImageView.trailingAnchor, constant: 12),
            titleLabel.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            
            // Count badge
            countBadge.leadingAnchor.constraint(equalTo: titleLabel.trailingAnchor, constant: 8),
            countBadge.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            countBadge.trailingAnchor.constraint(lessThanOrEqualTo: containerView.trailingAnchor, constant: -16),
            countBadge.widthAnchor.constraint(greaterThanOrEqualToConstant: 32),
            countBadge.heightAnchor.constraint(equalToConstant: 24)
        ])
        
        // Apply shadow
        containerView.applyAdaptiveShadow(radius: 6, opacity: 0.08)
        
        // Tap gesture
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTap))
        containerView.addGestureRecognizer(tapGesture)
    }
    
    func configure(title: String, trackCount: Int, isExpanded: Bool, colorIndex: Int) {
        titleLabel.text = title
        countBadge.text = "\(trackCount)"
        
        // Animate chevron rotation
        let targetRotation: CGFloat = isExpanded ? .pi / 2 : 0
        UIView.animate(
            withDuration: 0.3,
            delay: 0,
            usingSpringWithDamping: 0.7,
            initialSpringVelocity: 0.5,
            options: [.beginFromCurrentState]
        ) {
            self.chevronImageView.transform = CGAffineTransform(rotationAngle: targetRotation)
        }
        
        chevronImageView.image = UIImage(systemName: "chevron.right")
        
        // Set color stripe based on pack index
        colorStripeView.backgroundColor = AppColors.packAccent(index: colorIndex)
        
        // Subtle background tint
        containerView.backgroundColor = AppColors.packBackground(index: colorIndex)
    }
    
    @objc private func handleTap() {
        // Animate press
        UIView.animate(
            withDuration: 0.1,
            animations: {
                self.containerView.transform = CGAffineTransform(scaleX: 0.98, y: 0.98)
            },
            completion: { _ in
                UIView.animate(withDuration: 0.1) {
                    self.containerView.transform = .identity
                }
            }
        )
        
        onTap?()
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        
        if traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
            containerView.updateAdaptiveShadowForAppearance()
        }
    }
}
