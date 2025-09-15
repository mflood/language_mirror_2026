//
//  SettingsViewController.swift
//  LanguageMirror
//
//  Created by Matthew Flood on 9/13/25.
//

// path: Screens/SettingsViewController.swift
import UIKit

final class SettingsViewController: UITableViewController {

    private let settings: SettingsService

    // Controls
    private let repeatsStepper = UIStepper()
    private let gapSlider = UISlider()
    private let interGapSlider = UISlider()
    private let prerollSeg = UISegmentedControl(items: ["0ms", "100ms", "200ms", "300ms"])

    private enum Row: Int, CaseIterable {
        case repeats, gap, interGap, preroll
    }

    init(settings: SettingsService) {
        self.settings = settings
        super.init(style: .insetGrouped)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
        configureControls()
    }

    private func configureControls() {
        // Repeats
        repeatsStepper.minimumValue = 1
        repeatsStepper.maximumValue = 20
        repeatsStepper.stepValue = 1
        repeatsStepper.value = Double(settings.globalRepeats)
        repeatsStepper.addTarget(self, action: #selector(repeatsChanged), for: .valueChanged)

        // Gap
        gapSlider.minimumValue = 0.0
        gapSlider.maximumValue = 2.0
        gapSlider.value = Float(settings.gapSeconds)
        gapSlider.addTarget(self, action: #selector(gapChanged), for: .valueChanged)

        // Inter-segment gap
        interGapSlider.minimumValue = 0.0
        interGapSlider.maximumValue = 2.0
        interGapSlider.value = Float(settings.interSegmentGapSeconds)
        interGapSlider.addTarget(self, action: #selector(interGapChanged), for: .valueChanged)

        // Preroll
        let ms = settings.prerollMs
        let idx = [0,100,200,300].firstIndex(of: max(0, min(ms, 300))) ?? 0
        prerollSeg.selectedSegmentIndex = idx
        prerollSeg.addTarget(self, action: #selector(prerollChanged), for: .valueChanged)
    }

    // MARK: - Table

    override func numberOfSections(in tableView: UITableView) -> Int { 1 }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        "Playback"
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        Row.allCases.count
    }

    override func tableView(_ tableView: UITableView,
                            cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        var config = cell.defaultContentConfiguration()

        switch Row(rawValue: indexPath.row)! {
        case .repeats:
            config.text = "Repeats (global N)"
            config.secondaryText = "\(settings.globalRepeats)x"
            cell.accessoryView = repeatsStepper

        case .gap:
            config.text = "Gap between repeats"
            config.secondaryText = String(format: "%.1fs", settings.gapSeconds)
            cell.accessoryView = gapSlider

        case .interGap:
            config.text = "Gap between segments"
            config.secondaryText = String(format: "%.1fs", settings.interSegmentGapSeconds)
            cell.accessoryView = interGapSlider

        case .preroll:
            config.text = "Preroll"
            config.secondaryText = "\(settings.prerollMs) ms"
            cell.accessoryView = prerollSeg
        }

        cell.selectionStyle = .none
        cell.contentConfiguration = config
        return cell
    }
    
    private func updateSecondary(_ row: Row) {
        let indexPath = IndexPath(row: row.rawValue, section: 0)
        guard let cell = tableView.cellForRow(at: indexPath),
              var cfg = cell.contentConfiguration as? UIListContentConfiguration else { return }

        switch row {
        case .repeats:   cfg.secondaryText = "\(settings.globalRepeats)x"
        case .gap:       cfg.secondaryText = String(format: "%.1fs", settings.gapSeconds)
        case .interGap:  cfg.secondaryText = String(format: "%.1fs", settings.interSegmentGapSeconds)
        case .preroll:   cfg.secondaryText = "\(settings.prerollMs) ms"
        }
        cell.contentConfiguration = cfg
    }
    
    // MARK: - Actions

    @objc private func repeatsChanged() {
        settings.globalRepeats = Int(repeatsStepper.value)
        updateSecondary(.repeats)
    }

    @objc private func gapChanged() {
        // snap to 0.1s for nicer values
        let stepped = Double(round(gapSlider.value * 10) / 10)
        gapSlider.value = Float(stepped)
        settings.gapSeconds = Double(gapSlider.value)
        updateSecondary(.gap)
    }

    @objc private func interGapChanged() {
        let stepped = Double(round(interGapSlider.value * 10) / 10)
        interGapSlider.value = Float(stepped)
        settings.interSegmentGapSeconds = Double(interGapSlider.value)
        updateSecondary(.interGap)
    }

    @objc private func prerollChanged() {
        let values = [0, 100, 200, 300]
        settings.prerollMs = values[prerollSeg.selectedSegmentIndex]
        updateSecondary(.preroll)
    }

    private func reload(_ row: Row) {
        // This was originally called, and caused to hang
        // guard let idx = Row.allCases.firstIndex(of: row) else { return }
        // tableView.reloadRows(at: [IndexPath(row: idx, section: 0)], with: .none)
        
        // Chatgpt said to move to async, but we should really use the updateSecondary method
        // AS such, this entire method is not needed anymore
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.tableView.reloadRows(at: [IndexPath(row: row.rawValue, section: 0)], with: .none)
        }

    }
}
