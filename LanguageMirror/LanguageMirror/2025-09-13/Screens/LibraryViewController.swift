//
//  LibraryViewController.swift
//  LanguageMirror
//
//  Created by Matthew Flood on 9/13/25.
//

import UIKit

// MARK: - Section & Item Types

enum LibrarySection: Hashable {
    case continuePracticing
    case recentlyAdded
    case favorites
    case allContent(packId: String)
}

enum LibraryItem: Hashable {
    case continueCard(sessionSummary: PracticeSessionSummary)
    case recentTrack(trackId: String)
    case favoriteSet(trackId: String, practiceSetId: String)
    case packTrack(packId: String, trackId: String)
}

// MARK: - Delegate Protocol

protocol LibraryViewControllerDelegate: AnyObject {
    func libraryViewController(_ vc: LibraryViewController, didSelectTrack track: Track)
    func libraryViewController(_ vc: LibraryViewController, didRequestResumePractice track: Track, practiceSet: PracticeSet)
    func libraryViewControllerDidRequestImport(_ vc: LibraryViewController)
}

// MARK: - LibraryViewController

final class LibraryViewController: UIViewController {
    private let libraryService: LibraryService
    private let practiceService: PracticeService
    private var packs: [Pack] = []
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

    // MARK: - Init

    init(libraryService: LibraryService, practiceService: PracticeService) {
        self.libraryService = libraryService
        self.practiceService = practiceService
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    // MARK: - Collection View

    private var collectionView: UICollectionView!
    private var dataSource: UICollectionViewDiffableDataSource<LibrarySection, LibraryItem>!

    private lazy var searchController: UISearchController = {
        let sc = UISearchController(searchResultsController: nil)
        sc.searchResultsUpdater = self
        sc.obscuresBackgroundDuringPresentation = false
        sc.searchBar.placeholder = "Search tracks"
        return sc
    }()

    private var emptyStateView: EmptyStateView?

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = AppColors.primaryBackground
        navigationItem.largeTitleDisplayMode = .always
        navigationController?.navigationBar.prefersLargeTitles = true
        navigationItem.searchController = searchController
        navigationItem.hidesSearchBarWhenScrolling = false

        navigationItem.rightBarButtonItem = UIBarButtonItem(
            image: UIImage(systemName: "arrow.up.arrow.down.circle"),
            style: .plain,
            target: self,
            action: #selector(sortTapped)
        )

        configureCollectionView()
        configureDataSource()

        loadExpansionState()
        loadSortOrder()
        loadData()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleLibraryChanged),
            name: .LibraryDidChange,
            object: nil
        )

        let refreshControl = UIRefreshControl()
        refreshControl.addTarget(self, action: #selector(handleRefresh), for: .valueChanged)
        collectionView.refreshControl = refreshControl
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // Refresh after returning from practice so Continue Practicing updates
        loadData()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Collection View Configuration

    private func configureCollectionView() {
        collectionView = UICollectionView(frame: .zero, collectionViewLayout: createLayout())
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        collectionView.backgroundColor = AppColors.primaryBackground
        collectionView.delegate = self
        collectionView.contentInset = UIEdgeInsets(top: 8, left: 0, bottom: 8, right: 0)

        view.addSubview(collectionView)
        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: view.topAnchor),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }

    // MARK: - Compositional Layout

    private func createLayout() -> UICollectionViewCompositionalLayout {
        let layout = UICollectionViewCompositionalLayout { [weak self] sectionIndex, environment in
            guard let self = self,
                  let section = self.dataSource?.snapshot().sectionIdentifiers[safe: sectionIndex] else {
                return self?.makeVerticalListSection(environment: environment, estimatedHeight: 100)
            }

            switch section {
            case .continuePracticing:
                return self.makeContinuePracticingSection()
            case .recentlyAdded:
                return self.makeVerticalListSection(environment: environment, estimatedHeight: 100)
            case .favorites:
                return self.makeVerticalListSection(environment: environment, estimatedHeight: 60)
            case .allContent:
                return self.makeAllContentSection(environment: environment)
            }
        }
        return layout
    }

    private func makeContinuePracticingSection() -> NSCollectionLayoutSection {
        let itemSize = NSCollectionLayoutSize(widthDimension: .absolute(160), heightDimension: .absolute(120))
        let item = NSCollectionLayoutItem(layoutSize: itemSize)

        let groupSize = NSCollectionLayoutSize(widthDimension: .absolute(160), heightDimension: .absolute(120))
        let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitems: [item])

        let section = NSCollectionLayoutSection(group: group)
        section.orthogonalScrollingBehavior = .continuousGroupLeadingBoundary
        section.interGroupSpacing = 12
        section.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: 16, bottom: 16, trailing: 16)

        let headerSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .estimated(36))
        let header = NSCollectionLayoutBoundarySupplementaryItem(layoutSize: headerSize, elementKind: LibrarySectionHeaderView.elementKind, alignment: .top)
        section.boundarySupplementaryItems = [header]

        return section
    }

    private func makeVerticalListSection(environment: NSCollectionLayoutEnvironment, estimatedHeight: CGFloat) -> NSCollectionLayoutSection {
        let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .estimated(estimatedHeight))
        let item = NSCollectionLayoutItem(layoutSize: itemSize)

        let groupSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .estimated(estimatedHeight))
        let group = NSCollectionLayoutGroup.vertical(layoutSize: groupSize, subitems: [item])

        let section = NSCollectionLayoutSection(group: group)
        section.contentInsets = NSDirectionalEdgeInsets(top: 4, leading: 0, bottom: 12, trailing: 0)

        let headerSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .estimated(36))
        let header = NSCollectionLayoutBoundarySupplementaryItem(layoutSize: headerSize, elementKind: LibrarySectionHeaderView.elementKind, alignment: .top)
        section.boundarySupplementaryItems = [header]

        return section
    }

    private func makeAllContentSection(environment: NSCollectionLayoutEnvironment) -> NSCollectionLayoutSection {
        let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .estimated(100))
        let item = NSCollectionLayoutItem(layoutSize: itemSize)

        let groupSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .estimated(100))
        let group = NSCollectionLayoutGroup.vertical(layoutSize: groupSize, subitems: [item])

        let section = NSCollectionLayoutSection(group: group)
        section.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 0, bottom: 8, trailing: 0)

        let headerSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .estimated(72))
        let header = NSCollectionLayoutBoundarySupplementaryItem(layoutSize: headerSize, elementKind: LibrarySectionHeaderView.elementKind, alignment: .top)
        section.boundarySupplementaryItems = [header]

        // Swipe-to-delete
        section.visibleItemsInvalidationHandler = nil

        return section
    }

    // MARK: - Data Source Configuration

    private func configureDataSource() {
        // Cell registrations
        let continueCardRegistration = UICollectionView.CellRegistration<ContinuePracticingCardCell, PracticeSessionSummary> { [weak self] cell, indexPath, summary in
            guard let self = self else { return }
            let trackTitle = (try? self.libraryService.loadTrack(id: summary.trackId))?.title ?? "Track"
            let practiceSetTitle = (try? self.libraryService.loadPracticeSet(id: summary.practiceSetId))?.title
            cell.configure(
                trackTitle: trackTitle,
                practiceSetTitle: practiceSetTitle,
                lastUpdatedAt: summary.lastUpdatedAt,
                currentClipIndex: summary.currentClipIndex,
                totalClips: summary.totalClips,
                colorIndex: indexPath.item
            )
        }

        let recentTrackRegistration = UICollectionView.CellRegistration<TrackCollectionCell, String> { [weak self] cell, indexPath, trackId in
            guard let self = self, let track = try? self.libraryService.loadTrack(id: trackId) else { return }
            cell.configure(with: track, progress: 0.0)
        }

        let favoriteRegistration = UICollectionView.CellRegistration<FavoriteCompactCell, (String, String)> { [weak self] cell, indexPath, pair in
            guard let self = self else { return }
            let (trackId, practiceSetId) = pair
            let trackTitle = (try? self.libraryService.loadTrack(id: trackId))?.title ?? "Track"
            let practiceSetTitle = (try? self.libraryService.loadPracticeSet(id: practiceSetId))?.title
            cell.configure(trackTitle: trackTitle, practiceSetTitle: practiceSetTitle)
        }

        let packTrackRegistration = UICollectionView.CellRegistration<TrackCollectionCell, (String, String)> { [weak self] cell, indexPath, pair in
            guard let self = self else { return }
            let (_, trackId) = pair
            guard let track = try? self.libraryService.loadTrack(id: trackId) else { return }
            cell.configure(with: track, progress: 0.0)
        }

        dataSource = UICollectionViewDiffableDataSource<LibrarySection, LibraryItem>(collectionView: collectionView) { collectionView, indexPath, item in
            switch item {
            case .continueCard(let summary):
                return collectionView.dequeueConfiguredReusableCell(using: continueCardRegistration, for: indexPath, item: summary)
            case .recentTrack(let trackId):
                return collectionView.dequeueConfiguredReusableCell(using: recentTrackRegistration, for: indexPath, item: trackId)
            case .favoriteSet(let trackId, let practiceSetId):
                return collectionView.dequeueConfiguredReusableCell(using: favoriteRegistration, for: indexPath, item: (trackId, practiceSetId))
            case .packTrack(let packId, let trackId):
                return collectionView.dequeueConfiguredReusableCell(using: packTrackRegistration, for: indexPath, item: (packId, trackId))
            }
        }

        // Supplementary (headers)
        let headerRegistration = UICollectionView.SupplementaryRegistration<LibrarySectionHeaderView>(elementKind: LibrarySectionHeaderView.elementKind) { [weak self] header, elementKind, indexPath in
            guard let self = self,
                  let section = self.dataSource.snapshot().sectionIdentifiers[safe: indexPath.section] else { return }

            switch section {
            case .continuePracticing:
                header.configure(mode: .sectionTitle("CONTINUE PRACTICING"))
                header.onPackTap = nil
            case .recentlyAdded:
                header.configure(mode: .sectionTitle("RECENTLY ADDED"))
                header.onPackTap = nil
            case .favorites:
                header.configure(mode: .sectionTitle("FAVORITES"))
                header.onPackTap = nil
            case .allContent(let packId):
                let packIndex = self.packs.firstIndex(where: { $0.id == packId }) ?? 0
                let pack = self.packs.first(where: { $0.id == packId })
                let isExpanded = self.expandedPackIds.contains(packId)
                header.configure(mode: .packHeader(
                    title: pack?.title ?? "Pack",
                    count: pack?.tracks.count ?? 0,
                    expanded: isExpanded,
                    colorIndex: packIndex
                ))
                header.onPackTap = { [weak self] in
                    self?.togglePackExpansion(packId: packId)
                }
            }
        }

        dataSource.supplementaryViewProvider = { collectionView, kind, indexPath in
            return collectionView.dequeueConfiguredReusableSupplementary(using: headerRegistration, for: indexPath)
        }
    }

    // MARK: - Data Loading

    private func loadData() {
        packs = libraryService.listNonEmptyPacks()
        applySort()
        applySnapshot()
        updateEmptyState()
    }

    // MARK: - Snapshot Assembly

    private func applySnapshot(animating: Bool = false) {
        var snapshot = NSDiffableDataSourceSnapshot<LibrarySection, LibraryItem>()

        if isSearching {
            // Flat filtered list — skip top sections, show search results as a single section
            let allFilteredTracks = filteredTracksForSearch()
            if !allFilteredTracks.isEmpty {
                // Use a pseudo "allContent" section for flat results
                let searchSection = LibrarySection.allContent(packId: "__search__")
                snapshot.appendSections([searchSection])
                let items = allFilteredTracks.map { LibraryItem.packTrack(packId: $0.packId, trackId: $0.id) }
                snapshot.appendItems(items, toSection: searchSection)
            }
        } else {
            // Continue Practicing
            let sessionSummaries = buildContinuePracticingItems()
            if !sessionSummaries.isEmpty {
                snapshot.appendSections([.continuePracticing])
                snapshot.appendItems(sessionSummaries.map { .continueCard(sessionSummary: $0) }, toSection: .continuePracticing)
            }

            // Recently Added
            let recentTracks = libraryService.listRecentlyAddedTracks(limit: 5, withinDays: 14)
            if !recentTracks.isEmpty {
                snapshot.appendSections([.recentlyAdded])
                snapshot.appendItems(recentTracks.map { .recentTrack(trackId: $0.id) }, toSection: .recentlyAdded)
            }

            // Favorites
            let favorites = libraryService.getAllFavoritePracticeSets()
            if !favorites.isEmpty {
                snapshot.appendSections([.favorites])
                snapshot.appendItems(favorites.map { .favoriteSet(trackId: $0.track.id, practiceSetId: $0.practiceSet.id) }, toSection: .favorites)
            }

            // All Content (one section per pack)
            for pack in packs {
                let section = LibrarySection.allContent(packId: pack.id)
                snapshot.appendSections([section])

                if expandedPackIds.contains(pack.id) {
                    let items = pack.tracks.map { LibraryItem.packTrack(packId: pack.id, trackId: $0.id) }
                    snapshot.appendItems(items, toSection: section)
                }
            }
        }

        dataSource.apply(snapshot, animatingDifferences: animating)
    }

    private func buildContinuePracticingItems() -> [PracticeSessionSummary] {
        let recentSessions = practiceService.listRecentSessions(limit: 5)
        return recentSessions.compactMap { entry in
            practiceService.loadSessionSummary(packId: entry.packId, trackId: entry.trackId, libraryService: libraryService)
        }
    }

    private var searchFilteredPacks: [Pack] = []

    private func filteredTracksForSearch() -> [Track] {
        return searchFilteredPacks.flatMap(\.tracks)
    }

    // MARK: - Track Highlighting

    func highlightTrack(withId trackId: String) {
        loadData()

        // Find the pack containing this track
        guard let pack = packs.first(where: { $0.tracks.contains(where: { $0.id == trackId }) }) else {
            print("Could not find track with ID: \(trackId)")
            return
        }

        // Expand only the target pack
        expandedPackIds = [pack.id]
        saveExpansionState()
        applySnapshot()

        let targetItem = LibraryItem.packTrack(packId: pack.id, trackId: trackId)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            guard let indexPath = self.dataSource.indexPath(for: targetItem) else { return }
            self.collectionView.scrollToItem(at: indexPath, at: .centeredVertically, animated: true)

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                if let cell = self.collectionView.cellForItem(at: indexPath) as? TrackCollectionCell {
                    cell.highlightBriefly()
                }
            }
        }
    }

    // MARK: - Sorting

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
            let title = isSelected ? "\u{2713} \(order.rawValue)" : order.rawValue
            alert.addAction(UIAlertAction(title: title, style: .default) { [weak self] _ in
                self?.sortOrder = order
                self?.saveSortOrder()
                self?.loadData()

                UIImpactFeedbackGenerator(style: .light).impactOccurred()
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
        let isEmpty = packs.isEmpty || packs.allSatisfy { $0.tracks.isEmpty }

        if isEmpty && !isSearching {
            if emptyStateView == nil {
                let empty = EmptyStateView.emptyLibrary { [weak self] in
                    self?.handleEmptyStateAction()
                }
                empty.translatesAutoresizingMaskIntoConstraints = false
                view.addSubview(empty)
                NSLayoutConstraint.activate([
                    empty.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
                    empty.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                    empty.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                    empty.bottomAnchor.constraint(equalTo: view.bottomAnchor),
                ])
                emptyStateView = empty
            }
            emptyStateView?.isHidden = false
            collectionView.isHidden = true
        } else if isSearching && filteredTracksForSearch().isEmpty {
            if emptyStateView == nil {
                let empty = EmptyStateView.noSearchResults()
                empty.translatesAutoresizingMaskIntoConstraints = false
                view.addSubview(empty)
                NSLayoutConstraint.activate([
                    empty.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
                    empty.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                    empty.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                    empty.bottomAnchor.constraint(equalTo: view.bottomAnchor),
                ])
                emptyStateView = empty
            }
            emptyStateView?.isHidden = false
            collectionView.isHidden = true
        } else {
            emptyStateView?.isHidden = true
            collectionView.isHidden = false
        }
    }

    private func handleEmptyStateAction() {
        delegate?.libraryViewControllerDidRequestImport(self)
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    // MARK: - Pack Expand/Collapse

    private func togglePackExpansion(packId: String) {
        if expandedPackIds.contains(packId) {
            expandedPackIds.remove(packId)
        } else {
            expandedPackIds.insert(packId)
        }
        saveExpansionState()
        applySnapshot(animating: true)

        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    // MARK: - Track Deletion

    private func confirmDeleteTrack(_ track: Track) {
        let alert = UIAlertController(
            title: "Delete Track",
            message: "Are you sure you want to delete \"\(track.title)\"? This action cannot be undone.",
            preferredStyle: .alert
        )

        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))

        alert.addAction(UIAlertAction(title: "Delete", style: .destructive) { [weak self] _ in
            self?.performTrackDeletion(track)
        })

        present(alert, animated: true)
    }

    private func performTrackDeletion(_ track: Track) {
        do {
            try libraryService.deleteTrack(id: track.id)
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            loadData()
        } catch {
            print("Failed to delete track: \(error)")
            let errorAlert = UIAlertController(
                title: "Delete Failed",
                message: "Could not delete the track. Please try again.",
                preferredStyle: .alert
            )
            errorAlert.addAction(UIAlertAction(title: "OK", style: .default))
            present(errorAlert, animated: true)
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        }
    }

    // MARK: - Notifications & Refresh

    @objc private func handleLibraryChanged() {
        DispatchQueue.main.async { [weak self] in
            self?.loadData()
        }
    }

    @objc private func handleRefresh() {
        loadData()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.collectionView.refreshControl?.endRefreshing()
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
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
            view.backgroundColor = AppColors.primaryBackground
            collectionView.backgroundColor = AppColors.primaryBackground
        }
    }
}

// MARK: - UICollectionViewDelegate

extension LibraryViewController: UICollectionViewDelegate {

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: true)

        guard let item = dataSource.itemIdentifier(for: indexPath) else { return }

        switch item {
        case .continueCard(let summary):
            guard let track = try? libraryService.loadTrack(id: summary.trackId),
                  let practiceSet = try? libraryService.loadPracticeSet(id: summary.practiceSetId) else { return }
            delegate?.libraryViewController(self, didRequestResumePractice: track, practiceSet: practiceSet)

        case .recentTrack(let trackId):
            guard let track = try? libraryService.loadTrack(id: trackId) else { return }
            delegate?.libraryViewController(self, didSelectTrack: track)

        case .favoriteSet(let trackId, let practiceSetId):
            guard let track = try? libraryService.loadTrack(id: trackId),
                  let practiceSet = try? libraryService.loadPracticeSet(id: practiceSetId) else { return }
            delegate?.libraryViewController(self, didRequestResumePractice: track, practiceSet: practiceSet)

        case .packTrack(_, let trackId):
            guard let track = try? libraryService.loadTrack(id: trackId) else { return }
            delegate?.libraryViewController(self, didSelectTrack: track)
        }
    }

    func collectionView(_ collectionView: UICollectionView, contextMenuConfigurationForItemAt indexPath: IndexPath, point: CGPoint) -> UIContextMenuConfiguration? {
        guard let item = dataSource.itemIdentifier(for: indexPath) else { return nil }

        // Only offer delete on pack tracks
        guard case .packTrack(_, let trackId) = item,
              let track = try? libraryService.loadTrack(id: trackId) else { return nil }

        return UIContextMenuConfiguration(identifier: nil, previewProvider: nil) { [weak self] _ in
            let delete = UIAction(title: "Delete", image: UIImage(systemName: "trash"), attributes: .destructive) { _ in
                self?.confirmDeleteTrack(track)
            }
            return UIMenu(children: [delete])
        }
    }
}

// MARK: - UISearchResultsUpdating

extension LibraryViewController: UISearchResultsUpdating {
    func updateSearchResults(for searchController: UISearchController) {
        guard let searchText = searchController.searchBar.text?.trimmingCharacters(in: .whitespaces) else {
            isSearching = false
            searchFilteredPacks = []
            applySnapshot()
            updateEmptyState()
            return
        }

        if searchText.isEmpty {
            isSearching = false
            searchFilteredPacks = []
        } else {
            isSearching = true
            searchFilteredPacks = packs.compactMap { pack in
                let matchingTracks = pack.tracks.filter { track in
                    track.title.localizedCaseInsensitiveContains(searchText)
                }
                if matchingTracks.isEmpty { return nil }
                var filteredPack = pack
                filteredPack.tracks = matchingTracks
                return filteredPack
            }
        }

        applySnapshot()
        updateEmptyState()
    }
}

// MARK: - Collection Safe Subscript

private extension Collection {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
