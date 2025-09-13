//
//  LibraryViewController.swift
//  LanguageMirror
//
//  Created by Matthew Flood on 9/13/25.
//

import UIKit

final class LibraryViewController: UIViewController {
    private let label: UILabel = {
        let l = UILabel()
        l.text = "Library"
        l.font = .systemFont(ofSize: 24, weight: .semibold)
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        view.addSubview(label)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
        navigationItem.largeTitleDisplayMode = .always
        navigationController?.navigationBar.prefersLargeTitles = true
    }
}
