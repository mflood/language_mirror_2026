//
//  PracticeSettingsViewController.swift
//  LanguageMirror
//
//  Created by Matthew Flood on 10/20/25.
//

import UIKit

/// Custom cell for practice settings with flexible layout for different control types
final class PracticeSettingCell: UITableViewCell {
    
    private let titleLabel = UILabel()
    private let valueLabel = UILabel()
    private let controlContainer = UIView()
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        selectionStyle = .none
        
        // Title label
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = .systemFont(ofSize: 17, weight: .regular)
        titleLabel.textColor = .label
        contentView.addSubview(titleLabel)
        
        // Value label (for steppers and other controls that need value display)
        valueLabel.translatesAutoresizingMaskIntoConstraints = false
        valueLabel.font = .systemFont(ofSize: 15, weight: .medium)
        valueLabel.textColor = .secondaryLabel
        valueLabel.textAlignment = .right
        contentView.addSubview(valueLabel)
        
        // Control container
        controlContainer.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(controlContainer)
        
        NSLayoutConstraint.activate([
            // Title label
            titleLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            titleLabel.trailingAnchor.constraint(equalTo: valueLabel.leadingAnchor, constant: -8),
            
            // Value label (for steppers)
            valueLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            valueLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            valueLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 60),
            
            // Control container
            controlContainer.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            controlContainer.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            controlContainer.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            controlContainer.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -12),
            controlContainer.heightAnchor.constraint(greaterThanOrEqualToConstant: 30)
        ])
    }
    
    func configure(title: String, value: String? = nil, control: UIView) {
        titleLabel.text = title
        valueLabel.text = value
        valueLabel.isHidden = value == nil
        
        // Remove any existing control
        controlContainer.subviews.forEach { $0.removeFromSuperview() }
        
        // Add new control
        control.translatesAutoresizingMaskIntoConstraints = false
        controlContainer.addSubview(control)
        
        NSLayoutConstraint.activate([
            control.topAnchor.constraint(equalTo: controlContainer.topAnchor),
            control.leadingAnchor.constraint(equalTo: controlContainer.leadingAnchor),
            control.trailingAnchor.constraint(equalTo: controlContainer.trailingAnchor),
            control.bottomAnchor.constraint(equalTo: controlContainer.bottomAnchor)
        ])
    }
    
    func updateValue(_ text: String) {
        valueLabel.text = text
        valueLabel.isHidden = false
    }
}

/// Modal settings view for practice configuration
final class PracticeSettingsViewController: UITableViewController {
    
    private let settings: SettingsService
    
    // Controls
    private let repeatsSlider = UISlider()
    private let gapSlider = UISlider()
    private let interGapSlider = UISlider()
    private let prerollSeg = UISegmentedControl(items: ["0ms", "100ms", "200ms", "300ms"])
    
    // Progression mode controls
    private let practiceModeSeg = UISegmentedControl(items: ["Simple", "Progression"])
    private let progressionMinRepeatsSlider = UISlider()
    private let progressionLinearRepeatsSlider = UISlider()
    private let progressionMaxRepeatsSlider = UISlider()
    private let minSpeedSlider = UISlider()
    private let maxSpeedSlider = UISlider()
    
    private enum Section: Int, CaseIterable { case practiceMode, simple, progression, basic }
    private enum PracticeModeRow: Int, CaseIterable { case toggle }
    private enum SimpleRow: Int, CaseIterable { case repeats }
    private enum BasicRow: Int, CaseIterable { case gap, interGap, preroll }
    private enum ProgressionRow: Int, CaseIterable { case minSpeed, progressionMinRepeats, progressionLinearRepeats, maxSpeed, progressionMaxRepeats }
    
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
        tableView.register(PracticeSettingCell.self, forCellReuseIdentifier: "PracticeSettingCell")
        
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .done,
            target: self,
            action: #selector(doneTapped)
        )
        
        configureControls()
    }
    
    private func configureControls() {
        // Repeats
        repeatsSlider.minimumValue = 1
        repeatsSlider.maximumValue = 100
        repeatsSlider.value = Float(settings.globalRepeats)
        repeatsSlider.addTarget(self, action: #selector(repeatsChanged), for: .valueChanged)
        
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
        
        // Practice mode segmented control
        practiceModeSeg.selectedSegmentIndex = settings.useProgressionMode ? 1 : 0
        practiceModeSeg.addTarget(self, action: #selector(practiceModeChanged), for: .valueChanged)
        
        // Progression min repeats slider (0-100)
        progressionMinRepeatsSlider.minimumValue = 0
        progressionMinRepeatsSlider.maximumValue = 100
        progressionMinRepeatsSlider.value = Float(settings.progressionMinRepeats)
        progressionMinRepeatsSlider.minimumTrackTintColor = .systemGreen
        progressionMinRepeatsSlider.addTarget(self, action: #selector(progressionMinRepeatsChanged), for: .valueChanged)
        
        // Progression linear repeats slider (0-100)
        progressionLinearRepeatsSlider.minimumValue = 0
        progressionLinearRepeatsSlider.maximumValue = 100
        progressionLinearRepeatsSlider.value = Float(settings.progressionLinearRepeats)
        progressionLinearRepeatsSlider.minimumTrackTintColor = .systemYellow
        progressionLinearRepeatsSlider.addTarget(self, action: #selector(progressionLinearRepeatsChanged), for: .valueChanged)
        
        // Progression max repeats slider (1-100)
        progressionMaxRepeatsSlider.minimumValue = 1
        progressionMaxRepeatsSlider.maximumValue = 100
        progressionMaxRepeatsSlider.value = Float(settings.progressionMaxRepeats)
        progressionMaxRepeatsSlider.minimumTrackTintColor = .systemRed
        progressionMaxRepeatsSlider.addTarget(self, action: #selector(progressionMaxRepeatsChanged), for: .valueChanged)
        
        // Min speed slider
        minSpeedSlider.minimumValue = 0.3
        minSpeedSlider.maximumValue = 1.0
        minSpeedSlider.value = settings.minSpeed
        minSpeedSlider.minimumTrackTintColor = .systemGreen
        minSpeedSlider.addTarget(self, action: #selector(minSpeedChanged), for: .valueChanged)
        
        // Max speed slider
        maxSpeedSlider.minimumValue = 0.5
        maxSpeedSlider.maximumValue = 3.0
        maxSpeedSlider.value = settings.maxSpeed
        maxSpeedSlider.minimumTrackTintColor = .systemRed
        maxSpeedSlider.addTarget(self, action: #selector(maxSpeedChanged), for: .valueChanged)
    }
    
    // MARK: - Table View
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return Section.allCases.count
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch Section(rawValue: section)! {
        case .practiceMode: return PracticeModeRow.allCases.count
        case .simple: return SimpleRow.allCases.count
        case .progression: return ProgressionRow.allCases.count
        case .basic: return BasicRow.allCases.count
        }
    }
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch Section(rawValue: section)! {
        case .practiceMode: return "Practice Mode"
        case .simple: return "Simple Mode Settings"
        case .progression: return "Progression Mode Settings"
        case .basic: return "Basic Settings"
        }
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "PracticeSettingCell", for: indexPath) as! PracticeSettingCell
        
        switch Section(rawValue: indexPath.section)! {
        case .practiceMode:
            switch PracticeModeRow(rawValue: indexPath.row)! {
            case .toggle:
                cell.configure(
                    title: "Practice Mode",
                    value: nil, // Segmented control shows the value itself
                    control: practiceModeSeg
                )
            }
        case .simple:
            switch SimpleRow(rawValue: indexPath.row)! {
            case .repeats:
                cell.configure(
                    title: "Repeat Count",
                    value: "\(settings.globalRepeats)x",
                    control: repeatsSlider
                )
            }
        case .progression:
            switch ProgressionRow(rawValue: indexPath.row)! {
            case .minSpeed:
                cell.configure(
                    title: "Starting Speed",
                    value: String(format: "%.1fx", settings.minSpeed),
                    control: minSpeedSlider
                )
            case .progressionMinRepeats:
                cell.configure(
                    title: "Starting Speed Repeats",
                    value: "\(settings.progressionMinRepeats)x",
                    control: progressionMinRepeatsSlider
                )
            case .progressionLinearRepeats:
                cell.configure(
                    title: "Linear Progression Repeats",
                    value: "\(settings.progressionLinearRepeats)x",
                    control: progressionLinearRepeatsSlider
                )
            case .maxSpeed:
                cell.configure(
                    title: "Ending Speed",
                    value: String(format: "%.1fx", settings.maxSpeed),
                    control: maxSpeedSlider
                )
            case .progressionMaxRepeats:
                cell.configure(
                    title: "Ending Speed Repeats",
                    value: "\(settings.progressionMaxRepeats)x",
                    control: progressionMaxRepeatsSlider
                )
            }
        case .basic:
            switch BasicRow(rawValue: indexPath.row)! {
            case .gap:
                cell.configure(
                    title: "Gap Between Repeats",
                    value: String(format: "%.1fs", settings.gapSeconds),
                    control: gapSlider
                )
            case .interGap:
                cell.configure(
                    title: "Gap Between Clips",
                    value: String(format: "%.1fs", settings.interSegmentGapSeconds),
                    control: interGapSlider
                )
            case .preroll:
                cell.configure(
                    title: "Preroll",
                    value: nil, // No redundant value label for segmented control
                    control: prerollSeg
                )
            }
        }
        
        return cell
    }
    
    // MARK: - Actions
    
    @objc private func doneTapped() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        dismiss(animated: true)
    }
    
    @objc private func repeatsChanged() {
        let value = Int(repeatsSlider.value)
        settings.globalRepeats = value
        updateCellSecondaryText(section: .simple, row: SimpleRow.repeats.rawValue, text: "\(value)x")
    }
    
    @objc private func gapChanged() {
        let stepped = Double(round(gapSlider.value * 10) / 10)
        gapSlider.value = Float(stepped)
        settings.gapSeconds = stepped
        updateCellSecondaryText(section: .basic, row: BasicRow.gap.rawValue, text: String(format: "%.1fs", stepped))
    }
    
    @objc private func interGapChanged() {
        let stepped = Double(round(interGapSlider.value * 10) / 10)
        interGapSlider.value = Float(stepped)
        settings.interSegmentGapSeconds = stepped
        updateCellSecondaryText(section: .basic, row: BasicRow.interGap.rawValue, text: String(format: "%.1fs", stepped))
    }
    
    @objc private func prerollChanged() {
        let values = [0, 100, 200, 300]
        settings.prerollMs = values[prerollSeg.selectedSegmentIndex]
        updateCellSecondaryText(section: .basic, row: BasicRow.preroll.rawValue, text: "\(settings.prerollMs) ms")
    }
    
    @objc private func practiceModeChanged() {
        settings.useProgressionMode = practiceModeSeg.selectedSegmentIndex == 1
    }
    
    @objc private func progressionMinRepeatsChanged() {
        let value = Int(progressionMinRepeatsSlider.value)
        settings.progressionMinRepeats = value
        updateCellSecondaryText(section: .progression, row: ProgressionRow.progressionMinRepeats.rawValue, text: "\(value)x")
    }
    
    @objc private func progressionLinearRepeatsChanged() {
        let value = Int(progressionLinearRepeatsSlider.value)
        settings.progressionLinearRepeats = value
        updateCellSecondaryText(section: .progression, row: ProgressionRow.progressionLinearRepeats.rawValue, text: "\(value)x")
    }
    
    @objc private func progressionMaxRepeatsChanged() {
        let value = Int(progressionMaxRepeatsSlider.value)
        settings.progressionMaxRepeats = value
        updateCellSecondaryText(section: .progression, row: ProgressionRow.progressionMaxRepeats.rawValue, text: "\(value)x")
    }
    
    @objc private func minSpeedChanged() {
        let stepped = Float(round(minSpeedSlider.value * 10) / 10)
        minSpeedSlider.value = stepped
        settings.minSpeed = stepped
        
        // Ensure max speed is always >= min speed
        if settings.maxSpeed < settings.minSpeed {
            settings.maxSpeed = settings.minSpeed
            maxSpeedSlider.value = settings.maxSpeed
            updateCellSecondaryText(section: .progression, row: ProgressionRow.maxSpeed.rawValue, text: String(format: "%.1fx", settings.maxSpeed))
        }
        
        updateCellSecondaryText(section: .progression, row: ProgressionRow.minSpeed.rawValue, text: String(format: "%.1fx", stepped))
    }
    
    @objc private func maxSpeedChanged() {
        let stepped = Float(round(maxSpeedSlider.value * 10) / 10)
        maxSpeedSlider.value = stepped
        settings.maxSpeed = stepped
        
        // Ensure max speed is always >= min speed
        if settings.maxSpeed < settings.minSpeed {
            settings.maxSpeed = settings.minSpeed
            maxSpeedSlider.value = settings.maxSpeed
        }
        
        updateCellSecondaryText(section: .progression, row: ProgressionRow.maxSpeed.rawValue, text: String(format: "%.1fx", settings.maxSpeed))
    }
    
    // MARK: - Helpers
    
    private func updateCellSecondaryText(section: Section, row: Int, text: String) {
        let indexPath = IndexPath(row: row, section: section.rawValue)
        guard let cell = tableView.cellForRow(at: indexPath) as? PracticeSettingCell else {
            return
        }
        
        // Update the value label in the custom cell
        cell.updateValue(text)
    }
}

