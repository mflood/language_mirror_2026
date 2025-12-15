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
        case transcripts
    }
    
    private var headerContainerView: UIView?
    private weak var headerTitleLabel: UILabel?
    
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
        tableView.register(PracticeSetCell.self, forCellReuseIdentifier: "PracticeSetCell")
        tableView.backgroundColor = .clear
        tableView.separatorStyle = .none
        tableView.contentInset = UIEdgeInsets(top: 8, left: 0, bottom: 16, right: 0)
        
        configureNavigationItems()
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
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        // Ensure header view is correctly sized after layout changes
        guard let headerView = headerContainerView else { return }
        
        let targetSize = CGSize(width: tableView.bounds.width,
                                height: UIView.layoutFittingCompressedSize.height)
        let size = headerView.systemLayoutSizeFitting(targetSize,
                                                      withHorizontalFittingPriority: .required,
                                                      verticalFittingPriority: .fittingSizeLevel)
        if headerView.frame.size.height != size.height {
            headerView.frame = CGRect(origin: .zero, size: CGSize(width: size.width, height: size.height))
            tableView.tableHeaderView = headerView
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
        headerTitleLabel = titleLabel
        
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
        
        let subtitleLabel = UILabel()
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        subtitleLabel.text = "Tap a practice set below to start practicing."
        subtitleLabel.font = .systemFont(ofSize: 13, weight: .regular)
        subtitleLabel.textColor = AppColors.secondaryText
        subtitleLabel.numberOfLines = 2
        cardView.addSubview(subtitleLabel)
        
        NSLayoutConstraint.activate([
            cardView.topAnchor.constraint(equalTo: headerView.topAnchor, constant: 16),
            cardView.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: 16),
            cardView.trailingAnchor.constraint(equalTo: headerView.trailingAnchor, constant: -16),
            cardView.bottomAnchor.constraint(equalTo: headerView.bottomAnchor, constant: -16),
            
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
            
            subtitleLabel.topAnchor.constraint(equalTo: filenameLabel.bottomAnchor, constant: 6),
            subtitleLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            subtitleLabel.trailingAnchor.constraint(lessThanOrEqualTo: cardView.trailingAnchor, constant: -16),
            subtitleLabel.bottomAnchor.constraint(equalTo: cardView.bottomAnchor, constant: -16)
        ])
        
        cardView.applyAdaptiveShadow(radius: 10, opacity: 0.1)
        
        headerContainerView = headerView
        tableView.tableHeaderView = headerView
    }
    
    // MARK: - Navigation Items
    
    private func configureNavigationItems() {
        let addButton = UIBarButtonItem(barButtonSystemItem: .add,
                                        target: self,
                                        action: #selector(didTapAddPracticeSet))
        addButton.accessibilityLabel = "Add practice set"
        
        let moreButton = UIBarButtonItem(image: UIImage(systemName: "ellipsis.circle"),
                                         style: .plain,
                                         target: self,
                                         action: #selector(didTapMoreOptions))
        moreButton.accessibilityLabel = "Track options"
        
        navigationItem.rightBarButtonItems = [moreButton, addButton]
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
        switch Section(rawValue: section)! {
        case .practiceSets:
            label.text = "Practice sets"
        case .transcripts:
            label.text = "Transcripts"
        }
        
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
        case .transcripts:
            // Single row that navigates to transcript list (or empty state if none)
            return 1
        }
    }
    
    override func tableView(_ tableView: UITableView,
                            cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch Section(rawValue: indexPath.section)! {
        case .practiceSets:
            if track.practiceSets.isEmpty {
                let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
                var config = cell.defaultContentConfiguration()
                
                // Empty state style
                cell.backgroundColor = .clear
                let bgView = UIView()
                bgView.backgroundColor = AppColors.cardBackground
                bgView.layer.cornerRadius = 12
                bgView.layer.cornerCurve = .continuous
                cell.backgroundView = bgView
                config.textProperties.color = AppColors.primaryText
                config.secondaryTextProperties.color = AppColors.secondaryText
                config.text = "No practice sets yet"
                config.secondaryText = "Practice sets help you focus on the most useful parts of this track."
                cell.selectionStyle = .none
                cell.accessoryType = .none
                
                cell.contentConfiguration = config
                return cell
            } else {
                guard let cell = tableView.dequeueReusableCell(withIdentifier: "PracticeSetCell", for: indexPath) as? PracticeSetCell else {
                    return UITableViewCell()
                }
                
                let practiceSet = track.practiceSets[indexPath.row]
                let title = practiceSet.title?.isEmpty == false ? practiceSet.title! : "Practice Set \(indexPath.row + 1)"
                let drillCount = practiceSet.clips.filter { $0.kind == .drill }.count
                let clipCount = practiceSet.clips.count
                
                cell.configure(title: title,
                               clipCount: clipCount,
                               drillCount: drillCount,
                               isFavorite: practiceSet.isFavorite)
                cell.selectionStyle = .default
                cell.delegate = self
                
                return cell
            }
        case .transcripts:
            let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
            var config = cell.defaultContentConfiguration()
            
            cell.backgroundColor = .clear
            let bgView = UIView()
            bgView.backgroundColor = AppColors.cardBackground
            bgView.layer.cornerRadius = 12
            bgView.layer.cornerCurve = .continuous
            cell.backgroundView = bgView
            
            config.textProperties.color = AppColors.primaryText
            config.secondaryTextProperties.color = AppColors.secondaryText
            
            let count = track.transcripts.count
            config.text = "View transcripts"
            config.secondaryText = count == 0 ? "None" : "\(count) span(s)"
            
            cell.accessoryType = .disclosureIndicator
            cell.selectionStyle = .default
            cell.contentConfiguration = config
            return cell
        }
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        switch Section(rawValue: indexPath.section)! {
        case .practiceSets:
            if track.practiceSets.isEmpty {
                // Tapping the empty state can be a shortcut to creating the first practice set.
                didTapAddPracticeSet()
            } else {
                let practiceSet = track.practiceSets[indexPath.row]
                delegate?.trackDetailViewController(self, didSelectPracticeSet: practiceSet, forTrack: track)
            }
        case .transcripts:
            let vc = TranscriptListViewController(trackTitle: track.title, transcripts: track.transcripts)
            navigationController?.pushViewController(vc, animated: true)
        }
    }
    
    override func tableView(_ tableView: UITableView,
                            trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        guard Section(rawValue: indexPath.section) == .practiceSets,
              !track.practiceSets.isEmpty else {
            return nil
        }
        
        let practiceSet = track.practiceSets[indexPath.row]
        
        let deleteAction = UIContextualAction(style: .destructive, title: "Delete") { [weak self] _, _, completion in
            self?.confirmDeletePracticeSet(practiceSet, at: indexPath, completion: completion)
        }
        deleteAction.image = UIImage(systemName: "trash")
        
        let configuration = UISwipeActionsConfiguration(actions: [deleteAction])
        configuration.performsFirstActionWithFullSwipe = true
        return configuration
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
    
    @objc private func didTapAddPracticeSet() {
        let alert = UIAlertController(title: "New Practice Set",
                                      message: "Give this practice set a name (optional).",
                                      preferredStyle: .alert)
        alert.addTextField { textField in
            textField.placeholder = "e.g. Fast review, Sentence drills"
        }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Create", style: .default, handler: { [weak self] _ in
            guard let self = self else { return }
            let rawTitle = alert.textFields?.first?.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            self.createPracticeSet(withTitle: rawTitle.isEmpty ? nil : rawTitle)
        }))
        
        present(alert, animated: true)
    }
    
    @objc private func didTapMoreOptions() {
        let sheet = UIAlertController(title: "Track options",
                                      message: nil,
                                      preferredStyle: .actionSheet)
        
        sheet.addAction(UIAlertAction(title: "Rename track", style: .default, handler: { [weak self] _ in
            self?.presentRenameTrackAlert()
        }))
        
        sheet.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        // iPad popover configuration
        if let popover = sheet.popoverPresentationController,
           let barButton = navigationItem.rightBarButtonItems?.first {
            popover.barButtonItem = barButton
        }
        
        present(sheet, animated: true)
    }
    
    private func presentRenameTrackAlert() {
        let alert = UIAlertController(title: "Rename Track",
                                      message: "Update how this track appears in your library.",
                                      preferredStyle: .alert)
        alert.addTextField { [weak self] textField in
            textField.text = self?.track.title
            textField.clearButtonMode = .whileEditing
        }
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Save", style: .default, handler: { [weak self] _ in
            guard let self = self else { return }
            let newTitle = alert.textFields?.first?.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            guard !newTitle.isEmpty, newTitle != self.track.title else { return }
            self.renameTrack(to: newTitle)
        }))
        
        present(alert, animated: true)
    }
    
    private func renameTrack(to newTitle: String) {
        var updatedTrack = track
        updatedTrack.title = newTitle
        
        do {
            try library.updateTrack(updatedTrack)
            track = updatedTrack
            title = updatedTrack.title
            headerTitleLabel?.text = updatedTrack.title
            
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
        } catch {
            presentMessage("Error", "Failed to rename track: \(error.localizedDescription)")
        }
    }
    
    private func createPracticeSet(withTitle title: String?) {
        // Choose the next display order after the current maximum
        let nextDisplayOrder = (track.practiceSets.map { $0.displayOrder }.max() ?? -1) + 1
        var newSet = PracticeSet.fullTrackFactory(trackId: track.id,
                                                  displayOrder: nextDisplayOrder,
                                                  trackDurationMs: track.durationMs)
        if let title = title, !title.isEmpty {
            newSet.title = title
        }
        
        do {
            try library.addPracticeSet(newSet, to: track.id)
            reloadTrackAndPracticeSets(animatedScrollToLast: true)
            
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
        } catch {
            presentMessage("Error", "Failed to create practice set: \(error.localizedDescription)")
        }
    }
    
    private func confirmDeletePracticeSet(_ practiceSet: PracticeSet,
                                          at indexPath: IndexPath,
                                          completion: @escaping (Bool) -> Void) {
        let alert = UIAlertController(title: "Delete practice set?",
                                      message: "This will remove all clips in this set. This can't be undone.",
                                      preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { _ in
            completion(false)
        }))
        alert.addAction(UIAlertAction(title: "Delete", style: .destructive, handler: { [weak self] _ in
            self?.deletePracticeSet(practiceSet, at: indexPath, completion: completion)
        }))
        
        present(alert, animated: true)
    }
    
    private func deletePracticeSet(_ practiceSet: PracticeSet,
                                   at indexPath: IndexPath,
                                   completion: @escaping (Bool) -> Void) {
        do {
            try library.deletePracticeSet(id: practiceSet.id, from: track.id)
            reloadTrackAndPracticeSets(animatedScrollToLast: false)
            
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
            completion(true)
        } catch {
            presentMessage("Error", "Failed to delete practice set: \(error.localizedDescription)")
            completion(false)
        }
    }
    
    private func reloadTrackAndPracticeSets(animatedScrollToLast: Bool) {
        if let updatedTrack = try? library.loadTrack(id: track.id) {
            track = updatedTrack
            title = track.title
            headerTitleLabel?.text = track.title
        }
        
        if let sectionIndex = Section.allCases.firstIndex(of: .practiceSets) {
            tableView.reloadSections(IndexSet(integer: sectionIndex), with: .automatic)
        } else {
            tableView.reloadData()
        }
        
        guard animatedScrollToLast,
              !track.practiceSets.isEmpty else { return }
        
        let lastRow = track.practiceSets.count - 1
        let indexPath = IndexPath(row: lastRow, section: Section.practiceSets.rawValue)
        tableView.scrollToRow(at: indexPath, at: .middle, animated: true)
    }
    
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

// MARK: - PracticeSetCellDelegate

extension TrackDetailViewController: PracticeSetCellDelegate {
    func practiceSetCellDidTapFavorite(_ cell: PracticeSetCell) {
        guard let indexPath = tableView.indexPath(for: cell),
              Section(rawValue: indexPath.section) == .practiceSets,
              !track.practiceSets.isEmpty else { return }
        
        let practiceSet = track.practiceSets[indexPath.row]
        toggleFavorite(practiceSet: practiceSet, at: indexPath.row)
    }
}



