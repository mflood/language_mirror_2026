//
//  PracticeHomeViewController.swift
//  LanguageMirror
//
//  Created by Matthew Flood on 9/13/25.
//

import UIKit

protocol PracticeHomeViewControllerDelegate: AnyObject {
    func practiceHomeViewController(_ vc: PracticeHomeViewController, didSelectPracticeSet practiceSet: PracticeSet, forTrack track: Track)
}

final class PracticeHomeViewController: UIViewController {
    
    private let libraryService: LibraryService
    private let practiceService: PracticeService
    
    weak var delegate: PracticeHomeViewControllerDelegate?
    
    // Data
    private var recentSessions: [(packId: String, trackId: String, lastUpdated: Date)] = []
    private var favoritePracticeSets: [(track: Track, practiceSet: PracticeSet)] = []
    
    // UI Components
    private let tableView = UITableView(frame: .zero, style: .insetGrouped)
    private let refreshControl = UIRefreshControl()
    
    // Sections
    private enum Section: Int, CaseIterable {
        case recent = 0
        case favorites = 1
        
        var title: String {
            switch self {
            case .recent: return "Recent"
            case .favorites: return "Favorites"
            }
        }
    }
    
    init(libraryService: LibraryService, practiceService: PracticeService) {
        self.libraryService = libraryService
        self.practiceService = practiceService
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = AppColors.primaryBackground
        title = "Practice"
        navigationItem.largeTitleDisplayMode = .always
        
        setupTableView()
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
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        loadData()
    }
    
    private func setupTableView() {
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.backgroundColor = AppColors.primaryBackground
        tableView.separatorStyle = .none
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(PracticeHomeCell.self, forCellReuseIdentifier: "PracticeHomeCell")
        
        // Add refresh control
        refreshControl.addTarget(self, action: #selector(handleRefresh), for: .valueChanged)
        tableView.refreshControl = refreshControl
        
        view.addSubview(tableView)
        
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }
    
    private func loadData() {
        // Load recent sessions
        recentSessions = practiceService.listRecentSessions(limit: 10)
        
        // Load favorite practice sets
        favoritePracticeSets = libraryService.getAllFavoritePracticeSets()
        
        DispatchQueue.main.async { [weak self] in
            self?.tableView.reloadData()
        }
    }
    
    @objc private func handleRefresh() {
        loadData()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.refreshControl.endRefreshing()
            
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
        }
    }
    
    @objc private func handleLibraryChanged() {
        DispatchQueue.main.async { [weak self] in
            self?.loadData()
        }
    }
    
    private func getTrackForSession(_ session: (packId: String, trackId: String, lastUpdated: Date)) -> Track? {
        do {
            return try libraryService.loadTrack(id: session.trackId)
        } catch {
            return nil
        }
    }
    
    private func getPracticeSetForSession(_ session: (packId: String, trackId: String, lastUpdated: Date)) -> PracticeSet? {
        guard let track = getTrackForSession(session) else { return nil }
        
        // Try to find a practice set that matches the session's practice set ID
        // For now, return the first practice set (we'll need to enhance this when we have session-to-practice-set mapping)
        return track.practiceSets.first
    }
}

// MARK: - UITableViewDataSource

extension PracticeHomeViewController: UITableViewDataSource {
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return Section.allCases.count
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return Section(rawValue: section)?.title
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch Section(rawValue: section)! {
        case .recent:
            return max(recentSessions.count, 1) // Always show at least 1 row for empty state
        case .favorites:
            return max(favoritePracticeSets.count, 1) // Always show at least 1 row for empty state
        }
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "PracticeHomeCell", for: indexPath) as! PracticeHomeCell
        
        switch Section(rawValue: indexPath.section)! {
        case .recent:
            if recentSessions.isEmpty {
                cell.configureEmptyState(title: "No Recent Practice", subtitle: "Start practicing from the Library!")
            } else {
                let session = recentSessions[indexPath.row]
                if let track = getTrackForSession(session),
                   let practiceSet = getPracticeSetForSession(session) {
                    cell.configure(track: track, practiceSet: practiceSet, lastUpdated: session.lastUpdated)
                } else {
                    cell.configureEmptyState(title: "Session Not Found", subtitle: "Track may have been deleted")
                }
            }
            
        case .favorites:
            if favoritePracticeSets.isEmpty {
                cell.configureEmptyState(title: "No Favorites", subtitle: "Add practice sets from Track Details")
            } else {
                let favorite = favoritePracticeSets[indexPath.row]
                cell.configure(track: favorite.track, practiceSet: favorite.practiceSet, lastUpdated: nil)
            }
        }
        
        return cell
    }
}

// MARK: - UITableViewDelegate

extension PracticeHomeViewController: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        switch Section(rawValue: indexPath.section)! {
        case .recent:
            guard !recentSessions.isEmpty else { return }
            let session = recentSessions[indexPath.row]
            if let track = getTrackForSession(session),
               let practiceSet = getPracticeSetForSession(session) {
                delegate?.practiceHomeViewController(self, didSelectPracticeSet: practiceSet, forTrack: track)
            }
            
        case .favorites:
            guard !favoritePracticeSets.isEmpty else { return }
            let favorite = favoritePracticeSets[indexPath.row]
            delegate?.practiceHomeViewController(self, didSelectPracticeSet: favorite.practiceSet, forTrack: favorite.track)
        }
    }
    
    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        switch Section(rawValue: indexPath.section)! {
        case .recent:
            return nil // No swipe actions for recent
            
        case .favorites:
            guard !favoritePracticeSets.isEmpty else { return nil }
            
            let favorite = favoritePracticeSets[indexPath.row]
            let unfavoriteAction = UIContextualAction(style: .destructive, title: "Unfavorite") { [weak self] _, _, completion in
                self?.unfavoritePracticeSet(trackId: favorite.track.id, practiceSetId: favorite.practiceSet.id)
                completion(true)
            }
            
            unfavoriteAction.backgroundColor = .systemRed
            unfavoriteAction.image = UIImage(systemName: "heart.slash")
            
            return UISwipeActionsConfiguration(actions: [unfavoriteAction])
        }
    }
    
    private func unfavoritePracticeSet(trackId: String, practiceSetId: String) {
        do {
            try libraryService.togglePracticeSetFavorite(trackId: trackId, practiceSetId: practiceSetId)
            
            // Reload data to reflect changes
            loadData()
            
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
        } catch {
            presentAlert("Error", "Failed to unfavorite practice set: \(error.localizedDescription)")
        }
    }
    
    private func presentAlert(_ title: String, _ message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}

// MARK: - Practice Home Cell

final class PracticeHomeCell: UITableViewCell {
    
    private let containerView = UIView()
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let timeLabel = UILabel()
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        backgroundColor = .clear
        selectionStyle = .none
        
        // Container
        containerView.translatesAutoresizingMaskIntoConstraints = false
        containerView.backgroundColor = AppColors.cardBackground
        containerView.layer.cornerRadius = 12
        containerView.layer.cornerCurve = .continuous
        contentView.addSubview(containerView)
        
        // Title label
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = .systemFont(ofSize: 17, weight: .semibold)
        titleLabel.textColor = AppColors.primaryText
        titleLabel.numberOfLines = 2
        containerView.addSubview(titleLabel)
        
        // Subtitle label
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        subtitleLabel.font = .systemFont(ofSize: 14, weight: .medium)
        subtitleLabel.textColor = AppColors.secondaryText
        subtitleLabel.numberOfLines = 1
        containerView.addSubview(subtitleLabel)
        
        // Time label
        timeLabel.translatesAutoresizingMaskIntoConstraints = false
        timeLabel.font = .systemFont(ofSize: 12, weight: .regular)
        timeLabel.textColor = AppColors.tertiaryText
        timeLabel.textAlignment = .right
        containerView.addSubview(timeLabel)
        
        NSLayoutConstraint.activate([
            // Container
            containerView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
            containerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            containerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            containerView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -8),
            containerView.heightAnchor.constraint(greaterThanOrEqualToConstant: 72),
            
            // Title
            titleLabel.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 12),
            titleLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
            titleLabel.trailingAnchor.constraint(equalTo: timeLabel.leadingAnchor, constant: -8),
            
            // Subtitle
            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),
            subtitleLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            subtitleLabel.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor),
            subtitleLabel.bottomAnchor.constraint(lessThanOrEqualTo: containerView.bottomAnchor, constant: -12),
            
            // Time
            timeLabel.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 12),
            timeLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),
            timeLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 60)
        ])
        
        // Apply shadow
        containerView.applyAdaptiveShadow(radius: 6, opacity: 0.08)
    }
    
    func configure(track: Track, practiceSet: PracticeSet, lastUpdated: Date?) {
        titleLabel.text = track.title
        subtitleLabel.text = practiceSet.title?.isEmpty == false ? practiceSet.title : "Practice Set"
        
        if let lastUpdated = lastUpdated {
            let formatter = RelativeDateTimeFormatter()
            formatter.unitsStyle = .abbreviated
            timeLabel.text = formatter.localizedString(for: lastUpdated, relativeTo: Date())
            timeLabel.isHidden = false
        } else {
            timeLabel.isHidden = true
        }
        
        containerView.backgroundColor = AppColors.cardBackground
    }
    
    func configureEmptyState(title: String, subtitle: String) {
        self.titleLabel.text = title
        self.subtitleLabel.text = subtitle
        self.timeLabel.isHidden = true
        
        containerView.backgroundColor = AppColors.tertiaryBackground
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        
        if traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
            containerView.updateAdaptiveShadowForAppearance()
        }
    }
}
