//
//  TrackDetailViewController.swift
//  LanguageMirror
//
//  Created by Matthew Flood on 9/14/25.
//
//  Track detail view, upgraded to follow ADHD-friendly UI patterns:
//  - Calm background
//  - Single track info card (title, duration, language, filename)
//  - Clear list of practice sets
//

import UIKit

protocol TrackDetailViewControllerDelegate: AnyObject {
    func trackDetailViewController(_ vc: TrackDetailViewController, didSelectPracticeSet practiceSet: PracticeSet, forTrack track: Track)
}

final class TrackDetailViewController: UITableViewController {

    private var track: Track
    private let audioPlayer: AudioPlayerService
    private let clipService: ClipService
    private let settings: SettingsService
    private let library: LibraryService
    
    weak var delegate: TrackDetailViewControllerDelegate?
    
    private enum Section: Int, CaseIterable {
        case practiceSets
    }
    
    // MARK: - Init
    
    init(track: Track,
         audioPlayer: AudioPlayerService,
         clipService: ClipService,
         settings: SettingsService,
         library: LibraryService) {
        self.track = track
        self.audioPlayer = audioPlayer
        self.clipService = clipService
        self.settings = settings
        self.library = library
        super.init(style: .insetGrouped)
        self.title = track.title
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = AppColors.calmBackground
        navigationItem.largeTitleDisplayMode = .never
        
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
        tableView.backgroundColor = .clear
        tableView.separatorStyle = .none
        
        buildHeader()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Reload track from library to get latest practice sets
        if let updatedTrack = try? library.loadTrack(id: track.id) {
            track = updatedTrack
            title = track.title
        }
        
        if let sectionIndex = Section.allCases.firstIndex(of: .practiceSets) {
            tableView.reloadSections(IndexSet(integer: sectionIndex), with: .none)
        } else {
            tableView.reloadData()
        }
    }
    
    // MARK: - Header
    
    private func buildHeader() {
        let headerView = UIView()
        headerView.backgroundColor = .clear
        
        let cardView = UIView()
        cardView.translatesAutoresizingMaskIntoConstraints = false
        cardView.backgroundColor = AppColors.cardBackground
        cardView.layer.cornerRadius = 16
        cardView.layer.cornerCurve = .continuous
        headerView.addSubview(cardView)
        
        let titleLabel = UILabel()
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.text = track.title
        titleLabel.font = .systemFont(ofSize: 22, weight: .semibold)
        titleLabel.textColor = AppColors.primaryText
        titleLabel.numberOfLines = 0
        cardView.addSubview(titleLabel)
        
        let durationBadge = DurationBadge()
        durationBadge.translatesAutoresizingMaskIntoConstraints = false
        if let durationMs = track.durationMs {
            durationBadge.configure(durationMs: durationMs)
            durationBadge.isHidden = false
        } else {
            durationBadge.isHidden = true
        }
        cardView.addSubview(durationBadge)
        
        let languageTag = TagView()
        languageTag.translatesAutoresizingMaskIntoConstraints = false
        let languageText = trackLanguageDisplay()
        if languageText == "—" {
            languageTag.isHidden = true
        } else {
            languageTag.configure(text: languageText)
            languageTag.isHidden = false
        }
        cardView.addSubview(languageTag)
        
        let filenameLabel = UILabel()
        filenameLabel.translatesAutoresizingMaskIntoConstraints = false
        filenameLabel.text = track.filename
        filenameLabel.font = .systemFont(ofSize: 14, weight: .regular)
        filenameLabel.textColor = AppColors.secondaryText
        filenameLabel.numberOfLines = 1
        cardView.addSubview(filenameLabel)
        
        NSLayoutConstraint.activate([
            cardView.topAnchor.constraint(equalTo: headerView.topAnchor, constant: 16),
            cardView.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: 16),
            cardView.trailingAnchor.constraint(equalTo: headerView.trailingAnchor, constant: -16),
            
            titleLabel.topAnchor.constraint(equalTo: cardView.topAnchor, constant: 16),
            titleLabel.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 16),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: durationBadge.leadingAnchor, constant: -12),
            
            durationBadge.topAnchor.constraint(equalTo: cardView.topAnchor, constant: 16),
            durationBadge.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -16),
            
            languageTag.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            languageTag.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            
            filenameLabel.topAnchor.constraint(equalTo: languageTag.bottomAnchor, constant: 8),
            filenameLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            filenameLabel.trailingAnchor.constraint(lessThanOrEqualTo: cardView.trailingAnchor, constant: -16),
            filenameLabel.bottomAnchor.constraint(equalTo: cardView.bottomAnchor, constant: -16)
        ])
        
        cardView.applyAdaptiveShadow(radius: 10, opacity: 0.1)
        
        tableView.tableHeaderView = headerView
        headerView.layoutIfNeeded()
        let size = headerView.systemLayoutSizeFitting(CGSize(width: tableView.bounds.width,
                                                             height: UIView.layoutFittingCompressedSize.height))
        headerView.frame = CGRect(origin: .zero, size: CGSize(width: size.width, height: size.height))
    }
    
    // MARK: - Table
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        Section.allCases.count
    }
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        nil
    }
    
    override func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let container = UIView()
        container.backgroundColor = .clear
        
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .systemFont(ofSize: 15, weight: .semibold)
        label.textColor = AppColors.secondaryText
        label.text = "Practice sets"
        
        container.addSubview(label)
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 20),
            label.trailingAnchor.constraint(lessThanOrEqualTo: container.trailingAnchor, constant: -20),
            label.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -4)
        ])
        
        return container
    }
    
    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        32
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch Section(rawValue: section)! {
        case .practiceSets:
            return max(track.practiceSets.count, 1)
        }
    }
    
    override func tableView(_ tableView: UITableView,
                            cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        var config = cell.defaultContentConfiguration()
        
        // Common ADHD-friendly style for all rows
        cell.backgroundColor = .clear
        let bgView = UIView()
        bgView.backgroundColor = AppColors.cardBackground
        bgView.layer.cornerRadius = 12
        bgView.layer.cornerCurve = .continuous
        cell.backgroundView = bgView
        config.textProperties.color = AppColors.primaryText
        config.secondaryTextProperties.color = AppColors.secondaryText
        
        switch Section(rawValue: indexPath.section)! {
        case .practiceSets:
            if track.practiceSets.isEmpty {
                config.text = "No practice sets yet"
                config.secondaryText = "Practice sets help you focus on the most useful parts of this track."
                cell.selectionStyle = .none
                cell.accessoryType = .none
            } else {
                let practiceSet = track.practiceSets[indexPath.row]
                let title = practiceSet.title?.isEmpty == false ? practiceSet.title! : "Practice Set \(indexPath.row + 1)"
                let drillCount = practiceSet.clips.filter { $0.kind == .drill }.count
                config.text = title
                config.secondaryText = "\(practiceSet.clips.count) clips • \(drillCount) drills"
                cell.selectionStyle = .default
                cell.accessoryType = .disclosureIndicator
                
                if practiceSet.isFavorite {
                    config.image = UIImage(systemName: "heart.fill")
                    config.imageProperties.tintColor = AppColors.errorColor
                } else {
                    config.image = UIImage(systemName: "heart")
                    config.imageProperties.tintColor = AppColors.secondaryText
                }
            }
        }
        
        cell.contentConfiguration = config
        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        switch Section(rawValue: indexPath.section)! {
        case .practiceSets:
            guard !track.practiceSets.isEmpty else { return }
            let practiceSet = track.practiceSets[indexPath.row]
            delegate?.trackDetailViewController(self, didSelectPracticeSet: practiceSet, forTrack: track)
        }
    }
    
    override func tableView(_ tableView: UITableView,
                            trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        switch Section(rawValue: indexPath.section)! {
        case .practiceSets:
            guard !track.practiceSets.isEmpty else { return nil }
            
            let practiceSet = track.practiceSets[indexPath.row]
            let actionTitle = practiceSet.isFavorite ? "Unfavorite" : "Favorite"
            let actionImage = practiceSet.isFavorite ? "heart.slash" : "heart"
            
            let favoriteAction = UIContextualAction(style: .normal, title: actionTitle) { [weak self] _, _, completion in
                self?.toggleFavorite(practiceSet: practiceSet, at: indexPath.row)
                completion(true)
            }
            
            favoriteAction.backgroundColor = practiceSet.isFavorite ? AppColors.errorColor : AppColors.primaryAccent
            favoriteAction.image = UIImage(systemName: actionImage)
            
            return UISwipeActionsConfiguration(actions: [favoriteAction])
        }
    }
    
    private func toggleFavorite(practiceSet: PracticeSet, at index: Int) {
        do {
            try library.togglePracticeSetFavorite(trackId: track.id, practiceSetId: practiceSet.id)
            
            if let updatedTrack = try? library.loadTrack(id: track.id) {
                track = updatedTrack
            }
            
            let indexPath = IndexPath(row: index, section: Section.practiceSets.rawValue)
            tableView.reloadRows(at: [indexPath], with: .automatic)
            
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
        } catch {
            presentMessage("Error", "Failed to toggle favorite: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Helpers
    
    private func trackLanguageDisplay() -> String {
        if let code = track.languageCode?.trimmingCharacters(in: .whitespacesAndNewlines),
           !code.isEmpty {
            return code
        }
        return "—"
    }
    
    private func presentMessage(_ title: String, _ message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}


