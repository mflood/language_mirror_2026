//
//  SettingsViewController.swift
//  LanguageMirror
//
//  Created by Matthew Flood on 9/13/25.
//

// path: Screens/SettingsViewController.swift
import UIKit

final class SettingsViewController: UIViewController {

    private let settings: SettingsService

    // Scroll / stack layout
    private let scrollView = UIScrollView()
    private let contentStack = UIStackView()

    // Mode toggle
    private let practiceModeSeg = UISegmentedControl(items: ["Simple", "Progression"])

    // Simple mode section
    private let simpleSection = UIStackView()
    private let speedStrip = SpeedPresetStrip()
    private let repeatsSlider = UISlider()
    private let repeatsValueLabel = UILabel()

    // Progression mode section
    private let progressionSection = UIStackView()
    private let curveView = ProgressionCurveView()
    private let startCard = PhaseCard(phase: .start)
    private let rampCard = PhaseCard(phase: .ramp)
    private let endCard = PhaseCard(phase: .end)

    // Basic section
    private let gapSlider = UISlider()
    private let gapValueLabel = UILabel()
    private let interGapSlider = UISlider()
    private let interGapValueLabel = UILabel()
    private let prerollSeg = UISegmentedControl(items: ["0ms", "100ms", "200ms", "300ms"])
    private let duckSwitch = UISwitch()
    private let duckValueLabel = UILabel()

    init(settings: SettingsService) {
        self.settings = settings
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Settings"
        view.backgroundColor = AppColors.calmBackground
        buildLayout()
        configureControls()
        syncModeVisibility(animated: false)
    }

    // MARK: - Layout

    private func buildLayout() {
        // Scroll view
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.alwaysBounceVertical = true
        scrollView.keyboardDismissMode = .onDrag
        view.addSubview(scrollView)

        // Content stack
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        contentStack.axis = .vertical
        contentStack.spacing = 24
        scrollView.addSubview(contentStack)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            contentStack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 16),
            contentStack.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor, constant: 16),
            contentStack.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor, constant: -16),
            contentStack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -24),
            contentStack.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor, constant: -32),
        ])

        // --- Practice Mode Section ---
        let modeSection = makeSectionStack(header: "Practice Mode")
        practiceModeSeg.translatesAutoresizingMaskIntoConstraints = false
        modeSection.addArrangedSubview(practiceModeSeg)
        contentStack.addArrangedSubview(modeSection)

        // --- Simple Mode Section ---
        simpleSection.axis = .vertical
        simpleSection.spacing = 16
        simpleSection.translatesAutoresizingMaskIntoConstraints = false

        let simpleHeader = makeSectionHeaderLabel("Simple Mode")
        simpleSection.addArrangedSubview(simpleHeader)

        let speedLabel = makeFieldLabel("Speed")
        simpleSection.addArrangedSubview(speedLabel)

        speedStrip.translatesAutoresizingMaskIntoConstraints = false
        speedStrip.heightAnchor.constraint(equalToConstant: 44).isActive = true
        simpleSection.addArrangedSubview(speedStrip)

        let repeatsRow = makeSliderRow(title: "Repeat Count", valueLabel: repeatsValueLabel, slider: repeatsSlider)
        simpleSection.addArrangedSubview(repeatsRow)

        contentStack.addArrangedSubview(simpleSection)

        // --- Progression Mode Section ---
        progressionSection.axis = .vertical
        progressionSection.spacing = 16
        progressionSection.translatesAutoresizingMaskIntoConstraints = false

        let progressionHeader = makeSectionHeaderLabel("Progression Mode")
        progressionSection.addArrangedSubview(progressionHeader)

        curveView.translatesAutoresizingMaskIntoConstraints = false
        curveView.heightAnchor.constraint(equalToConstant: 140).isActive = true
        progressionSection.addArrangedSubview(curveView)

        startCard.translatesAutoresizingMaskIntoConstraints = false
        rampCard.translatesAutoresizingMaskIntoConstraints = false
        endCard.translatesAutoresizingMaskIntoConstraints = false
        progressionSection.addArrangedSubview(startCard)
        progressionSection.addArrangedSubview(rampCard)
        progressionSection.addArrangedSubview(endCard)

        contentStack.addArrangedSubview(progressionSection)

        // --- Basic Section ---
        let basicSection = makeSectionStack(header: "Playback")

        let gapRow = makeSliderRow(title: "Gap Between Repeats", valueLabel: gapValueLabel, slider: gapSlider)
        basicSection.addArrangedSubview(gapRow)

        let interGapRow = makeSliderRow(title: "Gap Between Clips", valueLabel: interGapValueLabel, slider: interGapSlider)
        basicSection.addArrangedSubview(interGapRow)

        let prerollRow = makeControlRow(title: "Preroll", control: prerollSeg)
        basicSection.addArrangedSubview(prerollRow)

        let duckRow = makeSwitchRow(title: "Duck Other Audio", valueLabel: duckValueLabel, toggle: duckSwitch)
        basicSection.addArrangedSubview(duckRow)

        contentStack.addArrangedSubview(basicSection)
    }

    // MARK: - Configure Controls

    private func configureControls() {
        // Mode toggle
        practiceModeSeg.selectedSegmentIndex = settings.useProgressionMode ? 1 : 0
        practiceModeSeg.selectedSegmentTintColor = .systemIndigo
        practiceModeSeg.addTarget(self, action: #selector(practiceModeChanged), for: .valueChanged)

        // Speed strip
        speedStrip.configure(speeds: type(of: settings).speedPresets, selected: settings.simpleSpeed)
        speedStrip.delegate = self

        // Repeats
        repeatsSlider.minimumValue = 1
        repeatsSlider.maximumValue = 100
        repeatsSlider.value = Float(settings.globalRepeats)
        repeatsSlider.minimumTrackTintColor = .systemBlue
        repeatsSlider.addTarget(self, action: #selector(repeatsChanged), for: .valueChanged)
        repeatsValueLabel.text = "\(settings.globalRepeats)x"

        // Phase cards
        startCard.configure(speed: settings.minSpeed, repeats: settings.progressionMinRepeats)
        rampCard.configure(speed: nil, repeats: settings.progressionLinearRepeats)
        endCard.configure(speed: settings.maxSpeed, repeats: settings.progressionMaxRepeats)

        startCard.onSpeedChanged = { [weak self] speed in
            guard let self else { return }
            self.settings.minSpeed = speed
            if self.settings.maxSpeed < speed {
                self.settings.maxSpeed = speed
                self.endCard.configure(speed: self.settings.maxSpeed, repeats: self.settings.progressionMaxRepeats)
            }
            self.refreshCurve()
        }
        startCard.onRepeatsChanged = { [weak self] val in
            self?.settings.progressionMinRepeats = val
            self?.refreshCurve()
        }
        rampCard.onRepeatsChanged = { [weak self] val in
            self?.settings.progressionLinearRepeats = val
            self?.refreshCurve()
        }
        endCard.onSpeedChanged = { [weak self] speed in
            guard let self else { return }
            self.settings.maxSpeed = speed
            if speed < self.settings.minSpeed {
                self.settings.maxSpeed = self.settings.minSpeed
                self.endCard.configure(speed: self.settings.maxSpeed, repeats: self.settings.progressionMaxRepeats)
            }
            self.refreshCurve()
        }
        endCard.onRepeatsChanged = { [weak self] val in
            self?.settings.progressionMaxRepeats = val
            self?.refreshCurve()
        }

        refreshCurve()

        // Gap
        gapSlider.minimumValue = 0.0
        gapSlider.maximumValue = 2.0
        gapSlider.value = Float(settings.gapSeconds)
        gapSlider.minimumTrackTintColor = .systemGreen
        gapSlider.addTarget(self, action: #selector(gapChanged), for: .valueChanged)
        gapValueLabel.text = String(format: "%.1fs", settings.gapSeconds)

        // Inter-gap
        interGapSlider.minimumValue = 0.0
        interGapSlider.maximumValue = 2.0
        interGapSlider.value = Float(settings.interSegmentGapSeconds)
        interGapSlider.minimumTrackTintColor = .systemPurple
        interGapSlider.addTarget(self, action: #selector(interGapChanged), for: .valueChanged)
        interGapValueLabel.text = String(format: "%.1fs", settings.interSegmentGapSeconds)

        // Preroll
        let ms = settings.prerollMs
        let idx = [0, 100, 200, 300].firstIndex(of: max(0, min(ms, 300))) ?? 0
        prerollSeg.selectedSegmentIndex = idx
        prerollSeg.selectedSegmentTintColor = .systemOrange
        prerollSeg.addTarget(self, action: #selector(prerollChanged), for: .valueChanged)

        // Duck
        duckSwitch.isOn = settings.duckOthers
        duckSwitch.onTintColor = .systemTeal
        duckSwitch.addTarget(self, action: #selector(duckToggled(_:)), for: .valueChanged)
        duckValueLabel.text = settings.duckOthers ? "Enabled" : "Disabled"
    }

    // MARK: - Mode Toggle

    private func syncModeVisibility(animated: Bool) {
        let isSimple = !settings.useProgressionMode
        let work = {
            self.simpleSection.isHidden = !isSimple
            self.simpleSection.alpha = isSimple ? 1 : 0
            self.progressionSection.isHidden = isSimple
            self.progressionSection.alpha = isSimple ? 0 : 1
        }
        if animated {
            UIView.animate(withDuration: 0.3, delay: 0, options: .curveEaseInOut) {
                work()
                self.contentStack.layoutIfNeeded()
            }
        } else {
            work()
        }
    }

    // MARK: - Helpers

    private func refreshCurve() {
        curveView.update(
            minSpeed: settings.minSpeed,
            maxSpeed: settings.maxSpeed,
            minRepeats: settings.progressionMinRepeats,
            linearRepeats: settings.progressionLinearRepeats,
            maxRepeats: settings.progressionMaxRepeats
        )
    }

    private func makeSectionStack(header: String) -> UIStackView {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        let label = makeSectionHeaderLabel(header)
        stack.addArrangedSubview(label)
        return stack
    }

    private func makeSectionHeaderLabel(_ text: String) -> UILabel {
        let label = UILabel()
        label.text = text.uppercased()
        label.font = .systemFont(ofSize: 13, weight: .semibold)
        label.textColor = AppColors.secondaryText
        return label
    }

    private func makeFieldLabel(_ text: String) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = .systemFont(ofSize: 15, weight: .medium)
        label.textColor = AppColors.primaryText
        return label
    }

    private func makeSliderRow(title: String, valueLabel: UILabel, slider: UISlider) -> UIView {
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false

        let titleLabel = UILabel()
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.text = title
        titleLabel.font = .systemFont(ofSize: 15, weight: .medium)
        titleLabel.textColor = AppColors.primaryText
        container.addSubview(titleLabel)

        valueLabel.translatesAutoresizingMaskIntoConstraints = false
        valueLabel.font = .monospacedSystemFont(ofSize: 14, weight: .semibold)
        valueLabel.textColor = AppColors.secondaryText
        valueLabel.textAlignment = .right
        container.addSubview(valueLabel)

        slider.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(slider)

        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: container.topAnchor),
            titleLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            valueLabel.topAnchor.constraint(equalTo: container.topAnchor),
            valueLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            valueLabel.leadingAnchor.constraint(greaterThanOrEqualTo: titleLabel.trailingAnchor, constant: 8),
            slider.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 6),
            slider.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            slider.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            slider.bottomAnchor.constraint(equalTo: container.bottomAnchor),
        ])
        return container
    }

    private func makeControlRow(title: String, control: UIView) -> UIView {
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false

        let titleLabel = UILabel()
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.text = title
        titleLabel.font = .systemFont(ofSize: 15, weight: .medium)
        titleLabel.textColor = AppColors.primaryText
        container.addSubview(titleLabel)

        control.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(control)

        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: container.topAnchor),
            titleLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            titleLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            control.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 6),
            control.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            control.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            control.bottomAnchor.constraint(equalTo: container.bottomAnchor),
        ])
        return container
    }

    private func makeSwitchRow(title: String, valueLabel: UILabel, toggle: UISwitch) -> UIView {
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false

        let titleLabel = UILabel()
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.text = title
        titleLabel.font = .systemFont(ofSize: 15, weight: .medium)
        titleLabel.textColor = AppColors.primaryText
        container.addSubview(titleLabel)

        valueLabel.translatesAutoresizingMaskIntoConstraints = false
        valueLabel.font = .systemFont(ofSize: 14, weight: .medium)
        valueLabel.textColor = AppColors.secondaryText
        container.addSubview(valueLabel)

        toggle.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(toggle)

        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: container.topAnchor, constant: 4),
            titleLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            titleLabel.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -4),

            valueLabel.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            valueLabel.trailingAnchor.constraint(equalTo: toggle.leadingAnchor, constant: -8),

            toggle.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            toggle.trailingAnchor.constraint(equalTo: container.trailingAnchor),
        ])
        return container
    }

    // MARK: - Actions

    @objc private func practiceModeChanged() {
        settings.useProgressionMode = practiceModeSeg.selectedSegmentIndex == 1
        syncModeVisibility(animated: true)
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    @objc private func repeatsChanged() {
        let value = Int(repeatsSlider.value)
        settings.globalRepeats = value
        repeatsValueLabel.text = "\(value)x"
        UISelectionFeedbackGenerator().selectionChanged()
    }

    @objc private func gapChanged() {
        let stepped = Float(round(gapSlider.value * 10) / 10)
        gapSlider.value = stepped
        settings.gapSeconds = Double(stepped)
        gapValueLabel.text = String(format: "%.1fs", stepped)
        UISelectionFeedbackGenerator().selectionChanged()
    }

    @objc private func interGapChanged() {
        let stepped = Float(round(interGapSlider.value * 10) / 10)
        interGapSlider.value = stepped
        settings.interSegmentGapSeconds = Double(stepped)
        interGapValueLabel.text = String(format: "%.1fs", stepped)
        UISelectionFeedbackGenerator().selectionChanged()
    }

    @objc private func prerollChanged() {
        let values = [0, 100, 200, 300]
        settings.prerollMs = values[prerollSeg.selectedSegmentIndex]
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    @objc private func duckToggled(_ sw: UISwitch) {
        settings.duckOthers = sw.isOn
        duckValueLabel.text = sw.isOn ? "Enabled" : "Disabled"
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    // MARK: - Trait Collection

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
            view.backgroundColor = AppColors.calmBackground
        }
    }
}

// MARK: - SpeedPresetStripDelegate

extension SettingsViewController: SpeedPresetStripDelegate {
    func speedPresetStrip(_ strip: SpeedPresetStrip, didSelectSpeed speed: Float) {
        settings.simpleSpeed = speed
    }
}
