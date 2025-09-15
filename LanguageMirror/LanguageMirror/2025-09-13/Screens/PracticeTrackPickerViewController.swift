//
//  PracticeTrackPickerViewController.swift
//  LanguageMirror
//
//  Created by Matthew Flood on 9/15/25.
//

import UIKit

final class PracticeTrackPickerViewController: UITableViewController {
    private let library: LibraryService
    private var tracks: [Track] = []
    var onPick: ((Track) -> Void)?

    init(libraryService: LibraryService) {
        self.library = libraryService
        super.init(style: .insetGrouped)
        self.title = "Choose Track"
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
        tracks = library.listTracks(in: nil)
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        tracks.count
    }

    override func tableView(_ tableView: UITableView,
                            cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let t = tracks[indexPath.row]
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        var cfg = cell.defaultContentConfiguration()
        cfg.text = t.title
        cfg.secondaryText = t.filename
        cell.contentConfiguration = cfg
        cell.accessoryType = .disclosureIndicator
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        onPick?(tracks[indexPath.row])
        navigationController?.popViewController(animated: true)
    }
}
