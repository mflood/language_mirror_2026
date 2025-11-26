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
    enum PracticeModeRow: Int, CaseIterable { case toggle }
    enum SimpleRow: Int, CaseIterable { case repeats }
    enum BasicRow: Int, CaseIterable { case gap, interGap, preroll, duck }
    enum ProgressionRow: Int, CaseIterable { case minSpeed, progressionMinRepeats, progressionLinearRepeats, maxSpeed, progressionMaxRepeats }

    init(settings: SettingsService) {
        self.settings = settings
        super.init(style: .insetGrouped)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    // MARK: - Mode Helpers

    private var isSimpleModeActive: Bool {
        return !settings.useProgressionMode
    }

    private var isProgressionModeActive: Bool {
        return settings.useProgressionMode
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = AppColors.calmBackground
        tableView.backgroundColor = AppColors.calmBackground
        tableView.register(SettingsCell.self, forCellReuseIdentifier: "settingsCell")
        configureControls()
    }

    private func configureControls() {
        // Repeats slider
        repeatsSlider.minimumValue = 1
        repeatsSlider.maximumValue = 100
        repeatsSlider.value = Float(settings.globalRepeats)
        repeatsSlider.minimumTrackTintColor = SimpleRow.repeats.iconColor
        repeatsSlider.addTarget(self, action: #selector(repeatsChanged), for: .valueChanged)

        // Gap slider
        gapSlider.minimumValue = 0.0
        gapSlider.maximumValue = 2.0
        gapSlider.value = Float(settings.gapSeconds)
        gapSlider.minimumTrackTintColor = BasicRow.gap.iconColor
        gapSlider.addTarget(self, action: #selector(gapChanged), for: .valueChanged)

        // Inter-segment gap slider
        interGapSlider.minimumValue = 0.0
        interGapSlider.maximumValue = 2.0
        interGapSlider.value = Float(settings.interSegmentGapSeconds)
        interGapSlider.minimumTrackTintColor = BasicRow.interGap.iconColor
        interGapSlider.addTarget(self, action: #selector(interGapChanged), for: .valueChanged)

        // Preroll segmented control
        let ms = settings.prerollMs
        let idx = [0,100,200,300].firstIndex(of: max(0, min(ms, 300))) ?? 0
        prerollSeg.selectedSegmentIndex = idx
        prerollSeg.selectedSegmentTintColor = BasicRow.preroll.iconColor
        prerollSeg.addTarget(self, action: #selector(prerollChanged), for: .valueChanged)
        
        // Practice mode segmented control
        practiceModeSeg.selectedSegmentIndex = settings.useProgressionMode ? 1 : 0
        practiceModeSeg.selectedSegmentTintColor = PracticeModeRow.toggle.iconColor
        practiceModeSeg.addTarget(self, action: #selector(practiceModeChanged), for: .valueChanged)
        
        // Progression min repeats slider (0-100)
        progressionMinRepeatsSlider.minimumValue = 0
        progressionMinRepeatsSlider.maximumValue = 100
        progressionMinRepeatsSlider.value = Float(settings.progressionMinRepeats)
        progressionMinRepeatsSlider.minimumTrackTintColor = ProgressionRow.progressionMinRepeats.iconColor
        progressionMinRepeatsSlider.addTarget(self, action: #selector(progressionMinRepeatsChanged), for: .valueChanged)
        
        // Progression linear repeats slider (0-100)
        progressionLinearRepeatsSlider.minimumValue = 0
        progressionLinearRepeatsSlider.maximumValue = 100
        progressionLinearRepeatsSlider.value = Float(settings.progressionLinearRepeats)
        progressionLinearRepeatsSlider.minimumTrackTintColor = ProgressionRow.progressionLinearRepeats.iconColor
        progressionLinearRepeatsSlider.addTarget(self, action: #selector(progressionLinearRepeatsChanged), for: .valueChanged)
        
        // Progression max repeats slider (1-100)
        progressionMaxRepeatsSlider.minimumValue = 1
        progressionMaxRepeatsSlider.maximumValue = 100
        progressionMaxRepeatsSlider.value = Float(settings.progressionMaxRepeats)
        progressionMaxRepeatsSlider.minimumTrackTintColor = ProgressionRow.progressionMaxRepeats.iconColor
        progressionMaxRepeatsSlider.addTarget(self, action: #selector(progressionMaxRepeatsChanged), for: .valueChanged)
        
        // Min speed slider
        minSpeedSlider.minimumValue = 0.3
        minSpeedSlider.maximumValue = 1.0
        minSpeedSlider.value = settings.minSpeed
        minSpeedSlider.minimumTrackTintColor = ProgressionRow.minSpeed.iconColor
        minSpeedSlider.addTarget(self, action: #selector(minSpeedChanged), for: .valueChanged)
        
        // Max speed slider
        maxSpeedSlider.minimumValue = 0.5
        maxSpeedSlider.maximumValue = 3.0
        maxSpeedSlider.value = settings.maxSpeed
        maxSpeedSlider.minimumTrackTintColor = ProgressionRow.maxSpeed.iconColor
        maxSpeedSlider.addTarget(self, action: #selector(maxSpeedChanged), for: .valueChanged)
    }

    // MARK: - Table

    override func numberOfSections(in tableView: UITableView) -> Int { 
        Section.allCases.count 
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch Section(rawValue: section)! {
        case .practiceMode:
            return "Practice Mode"
        case .simple:
            // Only show header when Simple Mode section is active
            return isSimpleModeActive ? "Simple Mode Settings" : nil
        case .progression:
            // Only show header when Progression Mode section is active
            return isProgressionModeActive ? "Progression Mode Settings" : nil
        case .basic:
            return "Basic Settings"
        }
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch Section(rawValue: section)! {
        case .practiceMode:
            return PracticeModeRow.allCases.count
        case .simple:
            // Only show Simple Mode Settings when simple mode is active
            return isSimpleModeActive ? SimpleRow.allCases.count : 0
        case .progression:
            // Only show Progression Mode Settings when progression mode is active
            return isProgressionModeActive ? ProgressionRow.allCases.count : 0
        case .basic:
            // Basic Settings are always visible
            return BasicRow.allCases.count
        }
    }

    override func tableView(_ tableView: UITableView,
                            cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: "settingsCell", for: indexPath) as? SettingsCell else {
            return UITableViewCell()
        }

        let section = Section(rawValue: indexPath.section)!
        
        switch section {
        case .practiceMode:
            let row = PracticeModeRow(rawValue: indexPath.row)!
            configurePracticeModeCell(cell, for: row)
        case .simple:
            let row = SimpleRow(rawValue: indexPath.row)!
            configureSimpleCell(cell, for: row)
        case .progression:
            let row = ProgressionRow(rawValue: indexPath.row)!
            configureProgressionCell(cell, for: row)
        case .basic:
            let row = BasicRow(rawValue: indexPath.row)!
            configureBasicCell(cell, for: row)
        }
        
        return cell
    }
    
    private func configurePracticeModeCell(_ cell: SettingsCell, for row: PracticeModeRow) {
        switch row {
        case .toggle:
            cell.configure(
                title: row.title,
                value: nil, // Segmented control shows the value itself
                control: practiceModeSeg
            )
        }
    }
    
    private func configureSimpleCell(_ cell: SettingsCell, for row: SimpleRow) {
        switch row {
        case .repeats:
            let value = "\(settings.globalRepeats)x"
            cell.configure(
                title: row.title,
                value: value,
                control: repeatsSlider
            )
        }
    }
    
    private func configureBasicCell(_ cell: SettingsCell, for row: BasicRow) {
        switch row {
        case .gap:
            let value = String(format: "%.1f seconds", settings.gapSeconds)
            cell.configure(
                title: row.title,
                value: value,
                control: gapSlider
            )

        case .interGap:
            let value = String(format: "%.1f seconds", settings.interSegmentGapSeconds)
            cell.configure(
                title: row.title,
                value: value,
                control: interGapSlider
            )

        case .preroll:
            cell.configure(
                title: row.title,
                value: nil, // No redundant value label for segmented control
                control: prerollSeg
            )
            
        case .duck:
            let sw = UISwitch()
            sw.isOn = settings.duckOthers
            sw.onTintColor = .systemBlue
            sw.addTarget(self, action: #selector(duckToggled(_:)), for: .valueChanged)
            
            let value = settings.duckOthers ? "Enabled" : "Disabled"
            cell.configure(
                title: row.title,
                value: value,
                control: sw
            )
        }
    }
    
    private func configureProgressionCell(_ cell: SettingsCell, for row: ProgressionRow) {
        switch row {
        case .minSpeed:
            let value = String(format: "%.1fx", settings.minSpeed)
            cell.configure(
                title: row.title,
                value: value,
                control: minSpeedSlider
            )
            
        case .progressionMinRepeats:
            let value = "\(settings.progressionMinRepeats)x"
            cell.configure(
                title: row.title,
                value: value,
                control: progressionMinRepeatsSlider
            )
            
        case .progressionLinearRepeats:
            let value = "\(settings.progressionLinearRepeats)x"
            cell.configure(
                title: row.title,
                value: value,
                control: progressionLinearRepeatsSlider
            )
            
        case .maxSpeed:
            let value = String(format: "%.1fx", settings.maxSpeed)
            cell.configure(
                title: row.title,
                value: value,
                control: maxSpeedSlider
            )
            
        case .progressionMaxRepeats:
            let value = "\(settings.progressionMaxRepeats)x"
            cell.configure(
                title: row.title,
                value: value,
                control: progressionMaxRepeatsSlider
            )
        }
    }
    
    private func updateSecondary(section: Section, row: Int) {
        let indexPath = IndexPath(row: row, section: section.rawValue)
        guard let cell = tableView.cellForRow(at: indexPath) as? SettingsCell else { return }

        // Only update value label for rows that have one
        switch section {
        case .practiceMode:
            let practiceModeRow = PracticeModeRow(rawValue: row)!
            switch practiceModeRow {
            case .toggle:
                cell.updateValue(settings.useProgressionMode ? "Progression" : "Simple", animated: true)
            }
        case .simple:
            let simpleRow = SimpleRow(rawValue: row)!
            switch simpleRow {
            case .repeats:
                cell.updateValue("\(settings.globalRepeats)x", animated: true)
            }
        case .progression:
            let progressionRow = ProgressionRow(rawValue: row)!
            switch progressionRow {
            case .progressionMinRepeats:
                cell.updateValue("\(settings.progressionMinRepeats)x", animated: true)
            case .progressionLinearRepeats:
                cell.updateValue("\(settings.progressionLinearRepeats)x", animated: true)
            case .progressionMaxRepeats:
                cell.updateValue("\(settings.progressionMaxRepeats)x", animated: true)
            case .minSpeed:
                cell.updateValue(String(format: "%.1fx", settings.minSpeed), animated: true)
            case .maxSpeed:
                cell.updateValue(String(format: "%.1fx", settings.maxSpeed), animated: true)
            }
        case .basic:
            let basicRow = BasicRow(rawValue: row)!
            switch basicRow {
            case .gap:
                cell.updateValue(String(format: "%.1f seconds", settings.gapSeconds), animated: true)
            case .interGap:
                cell.updateValue(String(format: "%.1f seconds", settings.interSegmentGapSeconds), animated: true)
            case .preroll:
                // No value label for preroll (segmented control shows the value)
                break
            case .duck:
                cell.updateValue(settings.duckOthers ? "Enabled" : "Disabled", animated: true)
            }
        }
    }
    
    // MARK: - Actions

    @objc private func repeatsChanged() {
        let value = Int(repeatsSlider.value)
        settings.globalRepeats = value
        updateSecondary(section: .simple, row: SimpleRow.repeats.rawValue)
        
        // Haptic feedback
        let generator = UISelectionFeedbackGenerator()
        generator.selectionChanged()
    }

    @objc private func gapChanged() {
        // snap to 0.1s for nicer values
        let stepped = Double(round(gapSlider.value * 10) / 10)
        gapSlider.value = Float(stepped)
        settings.gapSeconds = Double(gapSlider.value)
        updateSecondary(section: .basic, row: BasicRow.gap.rawValue)
        
        // Haptic feedback
        let generator = UISelectionFeedbackGenerator()
        generator.selectionChanged()
    }

    @objc private func interGapChanged() {
        let stepped = Double(round(interGapSlider.value * 10) / 10)
        interGapSlider.value = Float(stepped)
        settings.interSegmentGapSeconds = Double(interGapSlider.value)
        updateSecondary(section: .basic, row: BasicRow.interGap.rawValue)
        
        // Haptic feedback
        let generator = UISelectionFeedbackGenerator()
        generator.selectionChanged()
    }

    @objc private func prerollChanged() {
        let values = [0, 100, 200, 300]
        settings.prerollMs = values[prerollSeg.selectedSegmentIndex]
        updateSecondary(section: .basic, row: BasicRow.preroll.rawValue)
        
        // Haptic feedback
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
    }

    
    @objc private func duckToggled(_ sw: UISwitch) {
        settings.duckOthers = sw.isOn
        updateSecondary(section: .basic, row: BasicRow.duck.rawValue)
        
        // Haptic feedback
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
    }
    
    @objc private func practiceModeChanged() {
        settings.useProgressionMode = practiceModeSeg.selectedSegmentIndex == 1

        // Refresh Simple and Progression sections to reflect the new mode
        let sectionsToReload = IndexSet([
            Section.simple.rawValue,
            Section.progression.rawValue
        ])
        tableView.reloadSections(sectionsToReload, with: .fade)

        // Haptic feedback
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
    }
    
    @objc private func progressionMinRepeatsChanged() {
        let value = Int(progressionMinRepeatsSlider.value)
        settings.progressionMinRepeats = value
        updateSecondary(section: .progression, row: ProgressionRow.progressionMinRepeats.rawValue)
        
        // Haptic feedback
        let generator = UISelectionFeedbackGenerator()
        generator.selectionChanged()
    }
    
    @objc private func progressionLinearRepeatsChanged() {
        let value = Int(progressionLinearRepeatsSlider.value)
        settings.progressionLinearRepeats = value
        updateSecondary(section: .progression, row: ProgressionRow.progressionLinearRepeats.rawValue)
        
        // Haptic feedback
        let generator = UISelectionFeedbackGenerator()
        generator.selectionChanged()
    }
    
    @objc private func progressionMaxRepeatsChanged() {
        let value = Int(progressionMaxRepeatsSlider.value)
        settings.progressionMaxRepeats = value
        updateSecondary(section: .progression, row: ProgressionRow.progressionMaxRepeats.rawValue)
        
        // Haptic feedback
        let generator = UISelectionFeedbackGenerator()
        generator.selectionChanged()
    }
    
    @objc private func minSpeedChanged() {
        // Snap to 0.1x for nicer values
        let stepped = Float(round(minSpeedSlider.value * 10) / 10)
        minSpeedSlider.value = stepped
        settings.minSpeed = stepped
        
        // Ensure max speed is always >= min speed
        if settings.maxSpeed < settings.minSpeed {
            settings.maxSpeed = settings.minSpeed
            maxSpeedSlider.value = settings.maxSpeed
            updateSecondary(section: .progression, row: ProgressionRow.maxSpeed.rawValue)
        }
        
        updateSecondary(section: .progression, row: ProgressionRow.minSpeed.rawValue)
        
        // Haptic feedback
        let generator = UISelectionFeedbackGenerator()
        generator.selectionChanged()
    }
    
    @objc private func maxSpeedChanged() {
        // Snap to 0.1x for nicer values
        let stepped = Float(round(maxSpeedSlider.value * 10) / 10)
        maxSpeedSlider.value = stepped
        settings.maxSpeed = stepped
        
        // Ensure max speed is always >= min speed
        if settings.maxSpeed < settings.minSpeed {
            settings.maxSpeed = settings.minSpeed
            maxSpeedSlider.value = settings.maxSpeed
        }
        
        updateSecondary(section: .progression, row: ProgressionRow.maxSpeed.rawValue)
        
        // Haptic feedback
        let generator = UISelectionFeedbackGenerator()
        generator.selectionChanged()
    }
    
    
    // MARK: - Table View Height
    
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return UITableView.automaticDimension
    }
    
    override func tableView(_ tableView: UITableView, estimatedHeightForRowAt indexPath: IndexPath) -> CGFloat {
        return 84
    }
    
    // MARK: - Trait Collection
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        
        if traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
            // Update colors for dark mode transition
            view.backgroundColor = AppColors.primaryBackground
            tableView.backgroundColor = AppColors.primaryBackground
        }
    }

}

// MARK: - PracticeModeRow
extension SettingsViewController.PracticeModeRow {
    var title: String {
        switch self {
        case .toggle: return "Practice Mode"
        }
    }
    
    var iconName: String {
        switch self {
        case .toggle: return "chart.line.uptrend.xyaxis"
        }
    }
    
    var iconColor: UIColor {
        switch self {
        case .toggle: return .systemIndigo
        }
    }
}

// MARK: - SimpleRow
extension SettingsViewController.SimpleRow {
    var title: String {
        switch self {
        case .repeats: return "Repeat Count"
        }
    }
    
    var iconName: String {
        switch self {
        case .repeats: return "arrow.clockwise.circle.fill"
        }
    }
    
    var iconColor: UIColor {
        switch self {
        case .repeats: return .systemBlue
        }
    }
}

// MARK: - BasicRow
extension SettingsViewController.BasicRow {
    var title: String {
        switch self {
        case .gap: return "Gap Between Repeats"
        case .interGap: return "Gap Between Clips"
        case .preroll: return "Preroll"
        case .duck: return "Duck Other Audio"
        }
    }
    
    var iconName: String {
        switch self {
        case .gap: return "timer"
        case .interGap: return "arrow.left.and.right"
        case .preroll: return "play.circle.fill"
        case .duck: return "speaker.wave.2.fill"
        }
    }
    
    var iconColor: UIColor {
        switch self {
        case .gap: return .systemGreen
        case .interGap: return .systemPurple
        case .preroll: return .systemOrange
        case .duck: return .systemTeal
        }
    }
}

// MARK: - ProgressionRow
extension SettingsViewController.ProgressionRow {
    var title: String {
        switch self {
        case .progressionMinRepeats: return "Starting Speed Repeats"
        case .progressionLinearRepeats: return "Linear Progression Repeats"
        case .progressionMaxRepeats: return "Ending Speed Repeats"
        case .minSpeed: return "Starting Speed"
        case .maxSpeed: return "Ending Speed"
        }
    }
    
    var iconName: String {
        switch self {
        case .progressionMinRepeats: return "1.circle.fill"
        case .progressionLinearRepeats: return "2.circle.fill"
        case .progressionMaxRepeats: return "3.circle.fill"
        case .minSpeed: return "tortoise.fill"
        case .maxSpeed: return "hare.fill"
        }
    }
    
    var iconColor: UIColor {
        switch self {
        case .minSpeed: return .systemGreen
        case .progressionMinRepeats: return .systemGreen
        case .progressionLinearRepeats: return .systemYellow
        case .maxSpeed: return .systemRed
        case .progressionMaxRepeats: return .systemRed
        }
    }
}
