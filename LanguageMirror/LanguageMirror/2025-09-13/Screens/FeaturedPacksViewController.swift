//
//  FeaturedPacksViewController.swift
//  LanguageMirror
//
//  Browsable list of featured packs (a mix of app-embedded and CloudFront-
//  hosted bundles). The user sees them as a single cohesive set; the import
//  path (offline vs network) is determined by the source.kind field.
//

import UIKit
import TelemetryDeck

@MainActor
final class FeaturedPacksViewController: UIViewController {

    private let catalog: FeaturedCatalogService
    private let importService: ImportService

    private let tableView = UITableView(frame: .zero, style: .insetGrouped)
    private let loadingIndicator = UIActivityIndicatorView(style: .large)
    private let emptyLabel = UILabel()
    private var packs: [FeaturedPack] = []
    private var currentImportTask: Task<Void, Never>?
    private var progressViewController: UIViewController?

    init(catalog: FeaturedCatalogService, importService: ImportService) {
        self.catalog = catalog
        self.importService = importService
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = L10n("featured.title")
        view.backgroundColor = AppColors.primaryBackground
        view.addGrainField()
        navigationItem.largeTitleDisplayMode = .never

        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.backgroundColor = .clear
        tableView.dataSource = self
        tableView.delegate = self
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 100
        tableView.separatorStyle = .none
        tableView.register(FeaturedPackCell.self, forCellReuseIdentifier: "FeaturedPackCell")
        view.addSubview(tableView)

        loadingIndicator.translatesAutoresizingMaskIntoConstraints = false
        loadingIndicator.color = AppColors.primaryAccent
        view.addSubview(loadingIndicator)

        emptyLabel.translatesAutoresizingMaskIntoConstraints = false
        emptyLabel.text = L10n("featured.empty")
        emptyLabel.font = .preferredFont(forTextStyle: .body)
        emptyLabel.textColor = AppColors.secondaryText
        emptyLabel.textAlignment = .center
        emptyLabel.numberOfLines = 0
        emptyLabel.isHidden = true
        view.addSubview(emptyLabel)

        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            loadingIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            loadingIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor),

            emptyLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            emptyLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            emptyLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 32),
            emptyLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -32),
        ])

        Task { await loadCatalog() }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        currentImportTask?.cancel()
        currentImportTask = nil
    }

    private func loadCatalog() async {
        loadingIndicator.startAnimating()
        emptyLabel.isHidden = true
        do {
            let catalog = try await catalog.loadCatalog()
            self.packs = catalog.packs
            tableView.reloadData()
            emptyLabel.isHidden = !packs.isEmpty
        } catch {
            print("Failed to load featured catalog: \(error)")
            emptyLabel.text = L10n("featured.error")
            emptyLabel.isHidden = false
        }
        loadingIndicator.stopAnimating()
    }

    private func confirmInstall(_ pack: FeaturedPack) {
        let message = pack.subtitle ?? ""
        let alert = UIAlertController(
            title: L10nf("featured.install_title", pack.title),
            message: message,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: L10n("common.cancel"), style: .cancel))
        alert.addAction(UIAlertAction(title: L10n("featured.install_action"), style: .default) { [weak self] _ in
            self?.startInstall(pack)
        })
        present(alert, animated: true)
    }

    private func startInstall(_ pack: FeaturedPack) {
        currentImportTask?.cancel()

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
            progressView.bottomAnchor.constraint(equalTo: host.view.bottomAnchor),
        ])
        progressView.onCancel = { [weak self] in
            self?.currentImportTask?.cancel()
            host.dismiss(animated: true)
        }
        progressViewController = host
        present(host, animated: true)

        currentImportTask = Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                let source: ImportSource
                switch pack.source.kind {
                case "embedded":
                    guard let bundleId = pack.source.bundleId else {
                        throw FeaturedCatalogError.missingBundledCatalog
                    }
                    source = .appBundleManifest(bundleId: bundleId)
                case "remote":
                    guard let urlString = pack.source.manifestUrl,
                          let url = URL(string: urlString) else {
                        throw BundleManifestError.invalidManifestURL("featured pack '\(pack.id)' missing manifestUrl")
                    }
                    source = .bundleManifest(url: url)
                default:
                    throw FeaturedCatalogError.missingBundledCatalog
                }

                let tracks = try await self.importService.performImport(source: source) { progress in
                    DispatchQueue.main.async {
                        progressView.updateState(.downloading(progress: progress, message: L10n("featured.installing")))
                    }
                }

                let count = tracks.count
                let message = count == 1
                    ? L10n("import.success.one_track")
                    : L10nf("import.success.n_tracks", count)
                progressView.updateState(.success(message: message))
                TelemetryDeck.signal("FeaturedPacks.installed", parameters: [
                    "packId": pack.id,
                    "packTitle": pack.title,
                    "trackCount": "\(count)",
                    "source": pack.source.kind,
                ])

                if let firstId = tracks.first?.id {
                    NotificationCenter.default.post(
                        name: .libraryDidAddTrack,
                        object: nil,
                        userInfo: ["trackID": firstId]
                    )
                }

                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    host.dismiss(animated: true)
                }
            } catch is CancellationError {
                // already dismissed
            } catch {
                progressView.updateState(.error(message: error.localizedDescription))
                progressView.onCancel = { host.dismiss(animated: true) }
            }
        }
    }
}

// MARK: - Today's News

extension FeaturedPacksViewController {
    /// The daily news bundle, pinned above the catalog. Points at the
    /// pipeline's stable `news_latest` alias so no date math is needed —
    /// the same URL the daily-reminder notification resolves.
    static func todaysNewsPack() -> FeaturedPack {
        let df = DateFormatter()
        df.dateStyle = .medium
        df.timeStyle = .none
        return FeaturedPack(
            id: "news_latest",
            title: L10n("featured.news.title"),
            subtitle: L10nf("featured.news.subtitle", df.string(from: Date())),
            languageCode: "ko",
            level: nil,
            trackCount: nil,
            durationSeconds: nil,
            author: nil,
            iconSymbol: nil,
            accentColor: nil,
            source: FeaturedPackSource(
                kind: "remote",
                bundleId: nil,
                manifestUrl: NewsNotificationService.latestNewsBundleURL.absoluteString)
        )
    }
}

// MARK: - DataSource / Delegate

extension FeaturedPacksViewController: UITableViewDataSource, UITableViewDelegate {

    private var sections: [(header: String, packs: [FeaturedPack])] {
        [(L10n("featured.section.news"), [Self.todaysNewsPack()]),
         (L10n("featured.section.starter"), packs)]
    }

    func numberOfSections(in tableView: UITableView) -> Int { sections.count }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        sections[section].packs.count
    }

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        guard !sections[section].packs.isEmpty else { return nil }
        let container = UIView()
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.attributedText = AppFont.plateCaption(sections[section].header)
        let rule = GoldRule()
        container.addSubview(label)
        container.addSubview(rule)
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
            label.trailingAnchor.constraint(lessThanOrEqualTo: container.trailingAnchor, constant: -16),
            label.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -10),
            rule.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
            rule.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16),
            rule.topAnchor.constraint(equalTo: label.bottomAnchor, constant: 5),
        ])
        return container
    }

    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        sections[section].packs.isEmpty ? 0 : 42
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "FeaturedPackCell", for: indexPath) as! FeaturedPackCell
        cell.configure(with: sections[indexPath.section].packs[indexPath.row])
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        confirmInstall(sections[indexPath.section].packs[indexPath.row])
    }
}

// MARK: - Cell

final class FeaturedPackCell: UITableViewCell {

    private let cardView = UIView()
    private let coverView = CoverArtView()
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let metaLabel = UILabel()
    private let chevron = UIImageView(image: UIImage(systemName: "arrow.down.circle"))

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func setupUI() {
        backgroundColor = .clear
        selectionStyle = .none

        cardView.translatesAutoresizingMaskIntoConstraints = false
        cardView.backgroundColor = AppColors.cardBackground
        cardView.applyGoldPlateBorder(cornerRadius: 14)
        contentView.addSubview(cardView)

        // Ink-wash cover plate, seeded per pack — the gallery-wall look
        // from the Library.
        coverView.translatesAutoresizingMaskIntoConstraints = false
        cardView.addSubview(coverView)

        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = AppFont.plate(17, weight: .semibold)
        titleLabel.textColor = AppColors.primaryText
        titleLabel.numberOfLines = 2
        cardView.addSubview(titleLabel)

        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        subtitleLabel.font = .preferredFont(forTextStyle: .subheadline)
        subtitleLabel.textColor = AppColors.secondaryText
        subtitleLabel.numberOfLines = 2
        cardView.addSubview(subtitleLabel)

        metaLabel.translatesAutoresizingMaskIntoConstraints = false
        metaLabel.font = .preferredFont(forTextStyle: .caption1)
        metaLabel.textColor = AppColors.tertiaryText
        cardView.addSubview(metaLabel)

        // Quiet engraved download mark — outline gold, not a filled aqua disc.
        chevron.translatesAutoresizingMaskIntoConstraints = false
        chevron.tintColor = AppColors.antiqueGold
        chevron.preferredSymbolConfiguration = UIImage.SymbolConfiguration(weight: .light)
        chevron.contentMode = .scaleAspectFit
        cardView.addSubview(chevron)

        NSLayoutConstraint.activate([
            cardView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 6),
            cardView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -6),
            cardView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            cardView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),

            coverView.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 14),
            coverView.topAnchor.constraint(equalTo: cardView.topAnchor, constant: 14),
            coverView.widthAnchor.constraint(equalToConstant: 56),
            coverView.heightAnchor.constraint(equalToConstant: 56),

            titleLabel.topAnchor.constraint(equalTo: cardView.topAnchor, constant: 14),
            titleLabel.leadingAnchor.constraint(equalTo: coverView.trailingAnchor, constant: 14),
            titleLabel.trailingAnchor.constraint(equalTo: chevron.leadingAnchor, constant: -8),

            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),
            subtitleLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            subtitleLabel.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor),

            metaLabel.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: 6),
            metaLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            metaLabel.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor),
            metaLabel.bottomAnchor.constraint(equalTo: cardView.bottomAnchor, constant: -14),

            chevron.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -16),
            chevron.centerYAnchor.constraint(equalTo: cardView.centerYAnchor),
            chevron.widthAnchor.constraint(equalToConstant: 26),
            chevron.heightAnchor.constraint(equalToConstant: 26),
        ])

        cardView.applyAdaptiveShadow(radius: 6, opacity: 0.06)
    }

    func configure(with pack: FeaturedPack) {
        titleLabel.text = pack.title
        subtitleLabel.text = pack.subtitle
        subtitleLabel.isHidden = (pack.subtitle ?? "").isEmpty

        // Meta line: "Korean · Beginner · 2 tracks · ~5 min"
        var metaParts: [String] = []
        if let lang = pack.languageCode { metaParts.append(languageDisplayName(lang)) }
        if let level = pack.level { metaParts.append(level.capitalized) }
        if let count = pack.trackCount {
            metaParts.append(L10nf(count == 1 ? "featured.track_one" : "featured.track_n", count))
        }
        if let secs = pack.durationSeconds, secs > 0 {
            let mins = max(1, Int(round(Double(secs) / 60.0)))
            metaParts.append(L10nf("featured.minutes", mins))
        }
        metaLabel.text = metaParts.joined(separator: " · ")

        coverView.configure(seed: pack.id)
    }

    private func languageDisplayName(_ code: String) -> String {
        // Use the device locale to render a friendly language name
        if let lang = Locale.current.localizedString(forIdentifier: code), !lang.isEmpty {
            return lang
        }
        return code
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
            cardView.updateAdaptiveShadowForAppearance()
        }
    }
}

// MARK: - UIColor hex helper

private extension UIColor {
    convenience init?(hex: String?) {
        guard var s = hex?.trimmingCharacters(in: .whitespacesAndNewlines), !s.isEmpty else { return nil }
        if s.hasPrefix("#") { s.removeFirst() }
        guard s.count == 6, let v = UInt32(s, radix: 16) else { return nil }
        let r = CGFloat((v >> 16) & 0xFF) / 255.0
        let g = CGFloat((v >> 8) & 0xFF) / 255.0
        let b = CGFloat(v & 0xFF) / 255.0
        self.init(red: r, green: g, blue: b, alpha: 1.0)
    }
}
