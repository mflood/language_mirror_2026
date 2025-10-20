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
        case repeats, gap, interGap, preroll, duck
        
        var title: String {
            switch self {
            case .repeats: return "Repeat Count"
            case .gap: return "Gap Between Repeats"
            case .interGap: return "Gap Between Segments"
            case .preroll: return "Preroll Delay"
            case .duck: return "Duck Other Audio"
            }
        }
        
        var iconName: String {
            switch self {
            case .repeats: return "arrow.clockwise.circle.fill"
            case .gap: return "timer"
            case .interGap: return "arrow.left.and.right"
            case .preroll: return "play.circle.fill"
            case .duck: return "speaker.wave.2.fill"
            }
        }
        
        var iconColor: UIColor {
            switch self {
            case .repeats: return .systemBlue
            case .gap: return .systemGreen
            case .interGap: return .systemPurple
            case .preroll: return .systemOrange
            case .duck: return .systemTeal
            }
        }
    }

    init(settings: SettingsService) {
        self.settings = settings
        super.init(style: .insetGrouped)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = AppColors.primaryBackground
        tableView.backgroundColor = AppColors.primaryBackground
        tableView.register(SettingsCell.self, forCellReuseIdentifier: "settingsCell")
        tableView.separatorStyle = .none
        tableView.contentInset = UIEdgeInsets(top: 8, left: 0, bottom: 8, right: 0)
        configureControls()
    }

    private func configureControls() {
        // Repeats stepper
        repeatsStepper.minimumValue = 1
        repeatsStepper.maximumValue = 20
        repeatsStepper.stepValue = 1
        repeatsStepper.value = Double(settings.globalRepeats)
        repeatsStepper.tintColor = Row.repeats.iconColor
        repeatsStepper.addTarget(self, action: #selector(repeatsChanged), for: .valueChanged)

        // Gap slider
        gapSlider.minimumValue = 0.0
        gapSlider.maximumValue = 2.0
        gapSlider.value = Float(settings.gapSeconds)
        gapSlider.minimumTrackTintColor = Row.gap.iconColor
        gapSlider.addTarget(self, action: #selector(gapChanged), for: .valueChanged)

        // Inter-segment gap slider
        interGapSlider.minimumValue = 0.0
        interGapSlider.maximumValue = 2.0
        interGapSlider.value = Float(settings.interSegmentGapSeconds)
        interGapSlider.minimumTrackTintColor = Row.interGap.iconColor
        interGapSlider.addTarget(self, action: #selector(interGapChanged), for: .valueChanged)

        // Preroll segmented control
        let ms = settings.prerollMs
        let idx = [0,100,200,300].firstIndex(of: max(0, min(ms, 300))) ?? 0
        prerollSeg.selectedSegmentIndex = idx
        prerollSeg.selectedSegmentTintColor = Row.preroll.iconColor
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
        guard let cell = tableView.dequeueReusableCell(withIdentifier: "settingsCell", for: indexPath) as? SettingsCell else {
            return UITableViewCell()
        }

        let row = Row(rawValue: indexPath.row)!

        switch row {
        case .repeats:
            let value = "\(settings.globalRepeats)x"
            cell.configure(
                title: row.title,
                value: value,
                iconName: row.iconName,
                iconColor: row.iconColor,
                control: repeatsStepper
            )

        case .gap:
            let value = String(format: "%.1f seconds", settings.gapSeconds)
            cell.configure(
                title: row.title,
                value: value,
                iconName: row.iconName,
                iconColor: row.iconColor,
                control: gapSlider
            )

        case .interGap:
            let value = String(format: "%.1f seconds", settings.interSegmentGapSeconds)
            cell.configure(
                title: row.title,
                value: value,
                iconName: row.iconName,
                iconColor: row.iconColor,
                control: interGapSlider
            )

        case .preroll:
            let value = "\(settings.prerollMs) ms"
            cell.configure(
                title: row.title,
                value: value,
                iconName: row.iconName,
                iconColor: row.iconColor,
                control: prerollSeg
            )
            
        case .duck:
            let sw = UISwitch()
            sw.isOn = settings.duckOthers
            sw.onTintColor = row.iconColor
            sw.addTarget(self, action: #selector(duckToggled(_:)), for: .valueChanged)
            
            let value = settings.duckOthers ? "Enabled" : "Disabled"
            cell.configure(
                title: row.title,
                value: value,
                iconName: row.iconName,
                iconColor: row.iconColor,
                control: sw
            )
        }

        return cell
    }
    
    private func updateSecondary(_ row: Row) {
        let indexPath = IndexPath(row: row.rawValue, section: 0)
        guard let cell = tableView.cellForRow(at: indexPath) as? SettingsCell else { return }

        let newValue: String
        switch row {
        case .repeats:   newValue = "\(settings.globalRepeats)x"
        case .gap:       newValue = String(format: "%.1f seconds", settings.gapSeconds)
        case .interGap:  newValue = String(format: "%.1f seconds", settings.interSegmentGapSeconds)
        case .preroll:   newValue = "\(settings.prerollMs) ms"
        case .duck:      newValue = settings.duckOthers ? "Enabled" : "Disabled"
        }
        
        cell.updateValue(newValue, animated: true)
    }
    
    // MARK: - Actions

    @objc private func repeatsChanged() {
        settings.globalRepeats = Int(repeatsStepper.value)
        updateSecondary(.repeats)
        
        // Haptic feedback
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
    }

    @objc private func gapChanged() {
        // snap to 0.1s for nicer values
        let stepped = Double(round(gapSlider.value * 10) / 10)
        gapSlider.value = Float(stepped)
        settings.gapSeconds = Double(gapSlider.value)
        updateSecondary(.gap)
        
        // Haptic feedback
        let generator = UISelectionFeedbackGenerator()
        generator.selectionChanged()
    }

    @objc private func interGapChanged() {
        let stepped = Double(round(interGapSlider.value * 10) / 10)
        interGapSlider.value = Float(stepped)
        settings.interSegmentGapSeconds = Double(interGapSlider.value)
        updateSecondary(.interGap)
        
        // Haptic feedback
        let generator = UISelectionFeedbackGenerator()
        generator.selectionChanged()
    }

    @objc private func prerollChanged() {
        let values = [0, 100, 200, 300]
        settings.prerollMs = values[prerollSeg.selectedSegmentIndex]
        updateSecondary(.preroll)
        
        // Haptic feedback
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
    }

    
    @objc private func duckToggled(_ sw: UISwitch) {
        settings.duckOthers = sw.isOn
        updateSecondary(.duck)
        
        // Haptic feedback
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
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
