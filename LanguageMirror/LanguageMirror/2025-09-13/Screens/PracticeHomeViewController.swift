//
//  PracticeHomeViewController.swift
//  LanguageMirror
//
//  Created by Matthew Flood on 9/13/25.
//

import UIKit

protocol PracticeHomeViewControllerDelegate: AnyObject {
    func practiceHomeViewController(_ vc: PracticeHomeViewController, didSelectPracticeSet practiceSet: PracticeSet, forTrack track: Track)
    func practiceHomeViewControllerDidRequestBrowseLibrary(_ vc: PracticeHomeViewController)
}

final class PracticeHomeViewController: UIViewController {

    private let libraryService: LibraryService
    private let practiceService: PracticeService

    weak var delegate: PracticeHomeViewControllerDelegate?

    // Data
    private struct ResolvedSession {
        let track: Track
        let practiceSet: PracticeSet
        let summary: PracticeSessionSummary
    }
    private var heroSession: ResolvedSession?
    private var recentSessions: [ResolvedSession] = []

    // UI Components
    private let tableView = UITableView(frame: .zero, style: .insetGrouped)
    private let refreshControl = UIRefreshControl()
    private let heroCard = HeroSessionCard()
    private let emptyStateView = EmptyStateView()

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
        title = L10n("tab.practice")
        navigationItem.largeTitleDisplayMode = .always

        setupTableView()
        setupEmptyState()
        loadData()

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

    /// Streak banner ("🔥 N-day streak"), shown for a real streak (2+ days) —
    /// a "1-day streak" reads as sad, not motivating. Returns nil otherwise.
    /// Lives INSIDE the table header alongside the hero card so the two never
    /// clobber each other's `tableView.tableHeaderView`.
    private func makeStreakBanner() -> UILabel? {
        let streak = StreakTracker.currentStreak()
        guard streak >= 2 else { return nil }
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = L10nf("session_complete.streak", streak)
        label.font = AppFont.rounded(17, weight: .semibold)
        label.textColor = AppColors.primaryText
        return label
    }

    // MARK: - Setup

    private func setupTableView() {
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.backgroundColor = AppColors.primaryBackground
        tableView.separatorStyle = .none
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(PracticeHomeCell.self, forCellReuseIdentifier: "PracticeHomeCell")

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

    private func setupEmptyState() {
        emptyStateView.translatesAutoresizingMaskIntoConstraints = false
        emptyStateView.isHidden = true
        emptyStateView.configure(
            icon: "waveform.path.ecg",
            title: L10n("empty.practice.title"),
            message: L10n("empty.practice.message"),
            actionTitle: L10n("empty.practice.action"),
            miriExpression: .sleeping
        )
        emptyStateView.onActionTapped = { [weak self] in
            guard let self else { return }
            self.delegate?.practiceHomeViewControllerDidRequestBrowseLibrary(self)
        }

        view.addSubview(emptyStateView)

        NSLayoutConstraint.activate([
            emptyStateView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            emptyStateView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            emptyStateView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            emptyStateView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor)
        ])
    }

    // MARK: - Data

    private func loadData() {
        let rawSessions = practiceService.listRecentSessions(limit: 6)
        let resolved: [ResolvedSession] = rawSessions.compactMap { session in
            guard let summary = practiceService.loadSessionSummary(
                packId: session.packId,
                trackId: session.trackId,
                libraryService: libraryService
            ) else { return nil }

            guard let track = try? libraryService.loadTrack(id: session.trackId) else { return nil }

            // Find matching practice set
            let practiceSet = track.practiceSets.first(where: { $0.id == summary.practiceSetId })
                ?? track.practiceSets.first

            guard let practiceSet else { return nil }

            return ResolvedSession(track: track, practiceSet: practiceSet, summary: summary)
        }

        heroSession = resolved.first
        recentSessions = Array(resolved.dropFirst().prefix(4))

        updateUI()
    }

    private func updateUI() {
        let hasSessions = heroSession != nil

        emptyStateView.isHidden = hasSessions
        tableView.isHidden = !hasSessions

        if hasSessions {
            configureHeroCard()
            tableView.reloadData()
        }
    }

    private func configureHeroCard() {
        guard let hero = heroSession else {
            tableView.tableHeaderView = nil
            return
        }

        heroCard.configure(
            trackTitle: hero.track.title,
            practiceSetTitle: hero.practiceSet.title,
            lastUpdatedAt: hero.summary.lastUpdatedAt,
            currentClipIndex: hero.summary.currentClipIndex,
            totalClips: hero.summary.totalClips
        )

        heroCard.onTap = { [weak self] in
            guard let self, let hero = self.heroSession else { return }
            self.delegate?.practiceHomeViewController(self, didSelectPracticeSet: hero.practiceSet, forTrack: hero.track)
        }

        // Header = optional streak banner stacked above the hero card, in a
        // single container (one owner of tableHeaderView).
        let headerContainer = UIView()
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        if let streak = makeStreakBanner() {
            stack.addArrangedSubview(streak)
        }
        heroCard.translatesAutoresizingMaskIntoConstraints = false
        stack.addArrangedSubview(heroCard)
        headerContainer.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: headerContainer.topAnchor, constant: 16),
            stack.leadingAnchor.constraint(equalTo: headerContainer.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: headerContainer.trailingAnchor, constant: -20),
            stack.bottomAnchor.constraint(equalTo: headerContainer.bottomAnchor, constant: -8),
        ])

        // Calculate fitting size
        let targetWidth = view.bounds.width
        let fittingSize = headerContainer.systemLayoutSizeFitting(
            CGSize(width: targetWidth, height: UIView.layoutFittingCompressedSize.height),
            withHorizontalFittingPriority: .required,
            verticalFittingPriority: .fittingSizeLevel
        )
        headerContainer.frame = CGRect(origin: .zero, size: CGSize(width: targetWidth, height: fittingSize.height))

        tableView.tableHeaderView = headerContainer
    }

    // MARK: - Actions

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
}

// MARK: - UITableViewDataSource

extension PracticeHomeViewController: UITableViewDataSource {

    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return recentSessions.isEmpty ? nil : L10n("practice_home.recent")
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return recentSessions.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "PracticeHomeCell", for: indexPath) as! PracticeHomeCell

        let session = recentSessions[indexPath.row]
        cell.configure(
            track: session.track,
            practiceSet: session.practiceSet,
            lastUpdated: session.summary.lastUpdatedAt
        )

        return cell
    }
}

// MARK: - UITableViewDelegate

extension PracticeHomeViewController: UITableViewDelegate {

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        let session = recentSessions[indexPath.row]
        delegate?.practiceHomeViewController(self, didSelectPracticeSet: session.practiceSet, forTrack: session.track)
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
        subtitleLabel.text = practiceSet.title?.isEmpty == false ? practiceSet.title : L10n("practice_home.practice_set")

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

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)

        if traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
            containerView.updateAdaptiveShadowForAppearance()
        }
    }
}
