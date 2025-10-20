//
//  PracticeSettingsViewController.swift
//  LanguageMirror
//
//  Created by Matthew Flood on 10/20/25.
//

import UIKit

/// Modal settings view for practice configuration
final class PracticeSettingsViewController: UITableViewController {
    
    private let settings: SettingsService
    
    // Controls
    private let repeatsStepper = UIStepper()
    private let gapSlider = UISlider()
    private let interGapSlider = UISlider()
    private let prerollSeg = UISegmentedControl(items: ["0ms", "100ms", "200ms", "300ms"])
    private let minSpeedSlider = UISlider()
    private let maxSpeedSlider = UISlider()
    private let speedModeSeg = UISegmentedControl(items: SpeedMode.allCases.map { $0.label })
    private let speedModeNStepper = UIStepper()
    
    private enum Section: Int, CaseIterable { case practice, speed }
    private enum PracticeRow: Int, CaseIterable { case repeats, gap, interGap, preroll }
    private enum SpeedRow: Int, CaseIterable { case minSpeed, maxSpeed, speedMode, speedModeN }
    
    init(settings: SettingsService) {
        self.settings = settings
        super.init(style: .insetGrouped)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        title = "Practice Settings"
        view.backgroundColor = AppColors.calmBackground
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
        
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .done,
            target: self,
            action: #selector(doneTapped)
        )
        
        configureControls()
    }
    
    private func configureControls() {
        // Repeats
        repeatsStepper.minimumValue = 1
        repeatsStepper.maximumValue = 50
        repeatsStepper.stepValue = 1
        repeatsStepper.value = Double(settings.globalRepeats)
        repeatsStepper.addTarget(self, action: #selector(repeatsChanged), for: .valueChanged)
        
        // Gap
        gapSlider.minimumValue = 0.0
        gapSlider.maximumValue = 3.0
        gapSlider.value = Float(settings.gapSeconds)
        gapSlider.addTarget(self, action: #selector(gapChanged), for: .valueChanged)
        
        // Inter-segment gap
        interGapSlider.minimumValue = 0.0
        interGapSlider.maximumValue = 3.0
        interGapSlider.value = Float(settings.interSegmentGapSeconds)
        interGapSlider.addTarget(self, action: #selector(interGapChanged), for: .valueChanged)
        
        // Preroll
        let values = [0, 100, 200, 300]
        let idx = values.firstIndex(of: max(0, min(settings.prerollMs, 300))) ?? 0
        prerollSeg.selectedSegmentIndex = idx
        prerollSeg.addTarget(self, action: #selector(prerollChanged), for: .valueChanged)
        
        // Speed controls
        minSpeedSlider.minimumValue = 0.3
        minSpeedSlider.maximumValue = 1.0
        minSpeedSlider.value = settings.minSpeed
        minSpeedSlider.addTarget(self, action: #selector(minSpeedChanged), for: .valueChanged)
        
        maxSpeedSlider.minimumValue = 0.5
        maxSpeedSlider.maximumValue = 2.0
        maxSpeedSlider.value = settings.maxSpeed
        maxSpeedSlider.addTarget(self, action: #selector(maxSpeedChanged), for: .valueChanged)
        
        let modeIndex = SpeedMode.allCases.firstIndex(of: settings.speedMode) ?? 0
        speedModeSeg.selectedSegmentIndex = modeIndex
        speedModeSeg.addTarget(self, action: #selector(speedModeChanged), for: .valueChanged)
        
        speedModeNStepper.minimumValue = 1
        speedModeNStepper.maximumValue = 50
        speedModeNStepper.stepValue = 1
        speedModeNStepper.value = Double(settings.speedModeN)
        speedModeNStepper.addTarget(self, action: #selector(speedModeNChanged), for: .valueChanged)
    }
    
    // MARK: - Table View
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return Section.allCases.count
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch Section(rawValue: section)! {
        case .practice: return PracticeRow.allCases.count
        case .speed:
            // Hide speedModeN row if current mode doesn't use it
            return settings.speedMode.usesN ? SpeedRow.allCases.count : SpeedRow.allCases.count - 1
        }
    }
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch Section(rawValue: section)! {
        case .practice: return "Practice Controls"
        case .speed: return "Speed Settings"
        }
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        var cfg = cell.defaultContentConfiguration()
        cell.selectionStyle = .none
        
        switch Section(rawValue: indexPath.section)! {
        case .practice:
            switch PracticeRow(rawValue: indexPath.row)! {
            case .repeats:
                cfg.text = "Repeats per Clip"
                cfg.secondaryText = "\(settings.globalRepeats)x"
                cell.accessoryView = repeatsStepper
            case .gap:
                cfg.text = "Gap Between Repeats"
                cfg.secondaryText = String(format: "%.1fs", settings.gapSeconds)
                cell.accessoryView = gapSlider
            case .interGap:
                cfg.text = "Gap Between Clips"
                cfg.secondaryText = String(format: "%.1fs", settings.interSegmentGapSeconds)
                cell.accessoryView = interGapSlider
            case .preroll:
                cfg.text = "Preroll"
                cfg.secondaryText = "\(settings.prerollMs) ms"
                cell.accessoryView = prerollSeg
            }
            
        case .speed:
            let speedModeUsesN = settings.speedMode.usesN
            var row = SpeedRow(rawValue: indexPath.row)!
            
            // Skip speedModeN row if mode doesn't use it
            if indexPath.row >= SpeedRow.speedModeN.rawValue && !speedModeUsesN {
                row = SpeedRow(rawValue: indexPath.row + 1)!
            }
            
            switch row {
            case .minSpeed:
                cfg.text = "Minimum Speed"
                cfg.secondaryText = String(format: "%.2fx", settings.minSpeed)
                cell.accessoryView = minSpeedSlider
            case .maxSpeed:
                cfg.text = "Maximum Speed"
                cfg.secondaryText = String(format: "%.2fx", settings.maxSpeed)
                cell.accessoryView = maxSpeedSlider
            case .speedMode:
                cfg.text = "Speed Progression"
                cfg.secondaryText = settings.speedMode.label
                cell.accessoryView = speedModeSeg
            case .speedModeN:
                cfg.text = "N Loops for Mode"
                cfg.secondaryText = "\(settings.speedModeN)"
                cell.accessoryView = speedModeNStepper
            }
        }
        
        cell.contentConfiguration = cfg
        return cell
    }
    
    // MARK: - Actions
    
    @objc private func doneTapped() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        dismiss(animated: true)
    }
    
    @objc private func repeatsChanged() {
        settings.globalRepeats = Int(repeatsStepper.value)
        updateCellSecondaryText(section: .practice, row: PracticeRow.repeats.rawValue, text: "\(settings.globalRepeats)x")
    }
    
    @objc private func gapChanged() {
        let stepped = Double(round(gapSlider.value * 10) / 10)
        gapSlider.value = Float(stepped)
        settings.gapSeconds = stepped
        updateCellSecondaryText(section: .practice, row: PracticeRow.gap.rawValue, text: String(format: "%.1fs", stepped))
    }
    
    @objc private func interGapChanged() {
        let stepped = Double(round(interGapSlider.value * 10) / 10)
        interGapSlider.value = Float(stepped)
        settings.interSegmentGapSeconds = stepped
        updateCellSecondaryText(section: .practice, row: PracticeRow.interGap.rawValue, text: String(format: "%.1fs", stepped))
    }
    
    @objc private func prerollChanged() {
        let values = [0, 100, 200, 300]
        settings.prerollMs = values[prerollSeg.selectedSegmentIndex]
        updateCellSecondaryText(section: .practice, row: PracticeRow.preroll.rawValue, text: "\(settings.prerollMs) ms")
    }
    
    @objc private func minSpeedChanged() {
        let stepped = Float(round(minSpeedSlider.value * 100) / 100)
        minSpeedSlider.value = stepped
        settings.minSpeed = stepped
        updateCellSecondaryText(section: .speed, row: SpeedRow.minSpeed.rawValue, text: String(format: "%.2fx", stepped))
    }
    
    @objc private func maxSpeedChanged() {
        let stepped = Float(round(maxSpeedSlider.value * 100) / 100)
        maxSpeedSlider.value = stepped
        settings.maxSpeed = stepped
        updateCellSecondaryText(section: .speed, row: SpeedRow.maxSpeed.rawValue, text: String(format: "%.2fx", stepped))
    }
    
    @objc private func speedModeChanged() {
        let newMode = SpeedMode.allCases[speedModeSeg.selectedSegmentIndex]
        let oldMode = settings.speedMode
        settings.speedMode = newMode
        
        // Reload section if usesN changed to show/hide N stepper
        // Use async to avoid conflicts with the control's event handling
        if oldMode.usesN != newMode.usesN {
            DispatchQueue.main.async { [weak self] in
                self?.tableView.reloadSections(IndexSet(integer: Section.speed.rawValue), with: .automatic)
            }
        } else {
            updateCellSecondaryText(section: .speed, row: SpeedRow.speedMode.rawValue, text: newMode.label)
        }
    }
    
    @objc private func speedModeNChanged() {
        settings.speedModeN = Int(speedModeNStepper.value)
        updateCellSecondaryText(section: .speed, row: SpeedRow.speedModeN.rawValue, text: "\(settings.speedModeN)")
    }
    
    // MARK: - Helpers
    
    private func updateCellSecondaryText(section: Section, row: Int, text: String) {
        let indexPath = IndexPath(row: row, section: section.rawValue)
        guard let cell = tableView.cellForRow(at: indexPath),
              var config = cell.contentConfiguration as? UIListContentConfiguration else {
            return
        }
        
        config.secondaryText = text
        cell.contentConfiguration = config
    }
}

