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
    private var tracks: [Track] = []
    weak var delegate: LibraryViewControllerDelegate?

    init(service: LibraryService) {
        self.service = service
        super.init(nibName: nil, bundle: nil)
        createInternalUUIDs()
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private lazy var tableView: UITableView = {
        let tv = UITableView(frame: .zero, style: .insetGrouped)
        tv.translatesAutoresizingMaskIntoConstraints = false
        tv.dataSource = self
        tv.delegate = self
        tv.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
        return tv
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        navigationItem.largeTitleDisplayMode = .always
        navigationController?.navigationBar.prefersLargeTitles = true

        view.addSubview(tableView)
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        loadData()
    }

    private func loadData() {
        tracks = service.listTracks(in: nil)
        tableView.reloadData()
    }
}

extension LibraryViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        tracks.count
    }

    func tableView(_ tableView: UITableView,
                   cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let track = tracks[indexPath.row]
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        var config = cell.defaultContentConfiguration()
        config.text = track.title
        config.secondaryText = track.filename
        cell.contentConfiguration = config
        cell.accessoryType = .disclosureIndicator
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
         delegate?.libraryViewController(self, didSelect: tracks[indexPath.row])
        
        /*
        let track = tracks[indexPath.row]
        let alert = UIAlertController(
            title: track.title,
            message: "Track ID: \(track.id)\nFile: \(track.filename)\nDuration: \(track.durationMs ?? 0) ms",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
         */


    }
}
