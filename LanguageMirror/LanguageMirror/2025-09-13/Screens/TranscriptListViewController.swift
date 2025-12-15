//
//  TranscriptListViewController.swift
//  LanguageMirror
//
//  Lightweight transcript viewer for verifying imported transcripts.
//

import UIKit

final class TranscriptListViewController: UITableViewController {
    private let trackTitle: String
    private let transcripts: [TranscriptSpan]
    
    init(trackTitle: String, transcripts: [TranscriptSpan]) {
        self.trackTitle = trackTitle
        self.transcripts = transcripts
        super.init(style: .insetGrouped)
        self.title = "Transcripts"
    }
    
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = AppColors.calmBackground
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
        navigationItem.largeTitleDisplayMode = .never
    }
    
    override func numberOfSections(in tableView: UITableView) -> Int { 1 }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        max(transcripts.count, 1)
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        var config = cell.defaultContentConfiguration()
        
        cell.backgroundColor = .clear
        cell.selectionStyle = .none
        
        if transcripts.isEmpty {
            config.text = "No transcripts"
            config.secondaryText = "This track does not contain transcript spans."
            config.textProperties.color = AppColors.primaryText
            config.secondaryTextProperties.color = AppColors.secondaryText
            cell.contentConfiguration = config
            return cell
        }
        
        let t = transcripts[indexPath.row]
        let speaker = (t.speaker?.isEmpty == false) ? t.speaker! : nil
        let lang = (t.languageCode?.isEmpty == false) ? t.languageCode! : nil
        
        config.text = t.text
        var meta: [String] = []
        meta.append("\(formatMs(t.startMs))–\(formatMs(t.endMs))")
        if let speaker { meta.append(speaker) }
        if let lang { meta.append(lang) }
        config.secondaryText = meta.joined(separator: " • ")
        
        config.textProperties.color = AppColors.primaryText
        config.secondaryTextProperties.color = AppColors.secondaryText
        
        cell.contentConfiguration = config
        return cell
    }
    
    private func formatMs(_ ms: Int) -> String {
        let totalSeconds = max(ms, 0) / 1000
        let m = totalSeconds / 60
        let s = totalSeconds % 60
        return String(format: "%d:%02d", m, s)
    }
}


