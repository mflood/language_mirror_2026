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
    private let practiceModeSeg = UISegmentedControl(items: [L10n("settings.mode.simple"), L10n("settings.mode.progression")])

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

    // Collapsible body of the Advanced section (timing/preroll/duck).
    private weak var advancedBody: UIStackView?

    // Daily news reminder
    private let reminderSwitch = UISwitch()
    private let reminderValueLabel = UILabel()
    private let reminderTimePicker = UIDatePicker()
    private weak var reminderTimeRow: UIView?

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
        title = L10n("tab.settings")
        view.backgroundColor = AppColors.calmBackground
        view.addGrainField()
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

        // --- Daily News Reminder Section ---
        let reminderSection = makeSectionStack(header: L10n("settings.section.reminders"),
                                               stamp: "SettingsStampBell")
        let reminderRow = makeSwitchRow(title: L10n("settings.news_reminder"),
                                        valueLabel: reminderValueLabel, toggle: reminderSwitch)
        reminderSection.addArrangedSubview(reminderRow)
        let timeRow = makeControlRow(title: L10n("settings.news_reminder_time"), control: reminderTimePicker)
        reminderTimeRow = timeRow
        reminderSection.addArrangedSubview(timeRow)
        reminderSection.addArrangedSubview(makeHelperText(L10n("settings.news_reminder.help")))
        contentStack.addArrangedSubview(reminderSection)

        // --- Practice Mode Section ---
        let modeSection = makeSectionStack(header: L10n("settings.section.practice_mode"),
                                           stamp: "SettingsStampMirror")
        practiceModeSeg.translatesAutoresizingMaskIntoConstraints = false
        modeSection.addArrangedSubview(practiceModeSeg)
        modeSection.addArrangedSubview(makeHelperText(L10n("settings.practice_mode.help")))
        contentStack.addArrangedSubview(modeSection)

        // --- Simple Mode Section ---
        simpleSection.axis = .vertical
        simpleSection.spacing = 16
        simpleSection.translatesAutoresizingMaskIntoConstraints = false

        let simpleHeader = makeSectionHeaderLabel(L10n("settings.section.simple_mode"))
        simpleSection.addArrangedSubview(simpleHeader)

        let speedLabel = makeFieldLabel(L10n("settings.speed"))
        simpleSection.addArrangedSubview(speedLabel)

        speedStrip.translatesAutoresizingMaskIntoConstraints = false
        speedStrip.heightAnchor.constraint(equalToConstant: 44).isActive = true
        simpleSection.addArrangedSubview(speedStrip)

        let repeatsRow = makeSliderRow(title: L10n("settings.repeat_count"), valueLabel: repeatsValueLabel, slider: repeatsSlider)
        simpleSection.addArrangedSubview(repeatsRow)

        contentStack.addArrangedSubview(simpleSection)

        // --- Progression Mode Section ---
        progressionSection.axis = .vertical
        progressionSection.spacing = 16
        progressionSection.translatesAutoresizingMaskIntoConstraints = false

        let progressionHeader = makeSectionHeaderLabel(L10n("settings.section.progression_mode"))
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

        // --- Advanced Section (collapsed by default) ---
        // Timing, preroll and audio-ducking are fine-tuning most learners
        // never need — hide them behind a disclosure so the core screen is
        // just mode / speed / repeats.
        let advancedSection = UIStackView()
        advancedSection.axis = .vertical
        advancedSection.spacing = 12
        advancedSection.translatesAutoresizingMaskIntoConstraints = false

        advancedSection.addArrangedSubview(makeAdvancedDisclosureHeader())

        let advancedBody = UIStackView()
        advancedBody.axis = .vertical
        advancedBody.spacing = 12
        advancedBody.isHidden = true
        self.advancedBody = advancedBody

        let gapRow = makeSliderRow(title: L10n("settings.gap_between_repeats"), valueLabel: gapValueLabel, slider: gapSlider)
        advancedBody.addArrangedSubview(gapRow)

        let interGapRow = makeSliderRow(title: L10n("settings.gap_between_clips"), valueLabel: interGapValueLabel, slider: interGapSlider)
        advancedBody.addArrangedSubview(interGapRow)

        let prerollRow = makeControlRow(title: L10n("settings.preroll"), control: prerollSeg)
        advancedBody.addArrangedSubview(prerollRow)

        let duckRow = makeSwitchRow(title: L10n("settings.duck_other_audio"), valueLabel: duckValueLabel, toggle: duckSwitch)
        advancedBody.addArrangedSubview(duckRow)

        advancedSection.addArrangedSubview(advancedBody)
        contentStack.addArrangedSubview(advancedSection)
    }

    private func makeAdvancedDisclosureHeader() -> UIView {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.contentHorizontalAlignment = .leading
        button.accessibilityIdentifier = "settings.advanced.toggle"

        var config = UIButton.Configuration.plain()
        var attrs = AttributeContainer()
        attrs.font = AppFont.plate(13, weight: .semibold)
        attrs.foregroundColor = AppColors.antiqueGold
        attrs.kern = 13 * 0.12
        config.attributedTitle = AttributedString(L10n("settings.section.advanced").uppercased(), attributes: attrs)
        config.image = UIImage(systemName: "chevron.right")
        config.imagePlacement = .trailing
        config.imagePadding = 6
        config.preferredSymbolConfigurationForImage = UIImage.SymbolConfiguration(pointSize: 11, weight: .semibold)
        config.baseForegroundColor = AppColors.antiqueGold
        config.contentInsets = .zero
        button.configuration = config

        button.addAction(UIAction { [weak self] _ in
            guard let self, let body = self.advancedBody else { return }
            UISelectionFeedbackGenerator().selectionChanged()
            let willExpand = body.isHidden
            UIView.animate(withDuration: 0.25) {
                body.isHidden = !willExpand
                body.alpha = willExpand ? 1 : 0
                button.configuration?.image = UIImage(systemName: willExpand ? "chevron.down" : "chevron.right")
            }
        }, for: .touchUpInside)

        let row = UIStackView(arrangedSubviews: [makeStampMedallion("SettingsStampCompass"), button])
        row.axis = .horizontal
        row.spacing = 10
        row.alignment = .center
        row.translatesAutoresizingMaskIntoConstraints = false
        return row
    }

    // MARK: - Configure Controls

    private func configureControls() {
        // Mode toggle
        practiceModeSeg.selectedSegmentIndex = settings.useProgressionMode ? 1 : 0
        practiceModeSeg.selectedSegmentTintColor = AppColors.primaryAccent
        practiceModeSeg.addTarget(self, action: #selector(practiceModeChanged), for: .valueChanged)

        // Speed strip
        speedStrip.configure(speeds: type(of: settings).speedPresets, selected: settings.simpleSpeed)
        speedStrip.delegate = self

        // Repeats
        repeatsSlider.minimumValue = 1
        repeatsSlider.maximumValue = 100
        repeatsSlider.value = Float(settings.globalRepeats)
        repeatsSlider.minimumTrackTintColor = AppColors.primaryAccent
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
        gapSlider.minimumTrackTintColor = AppColors.primaryAccent
        gapSlider.addTarget(self, action: #selector(gapChanged), for: .valueChanged)
        gapValueLabel.text = String(format: "%.1fs", settings.gapSeconds)

        // Inter-gap
        interGapSlider.minimumValue = 0.0
        interGapSlider.maximumValue = 2.0
        interGapSlider.value = Float(settings.interSegmentGapSeconds)
        interGapSlider.minimumTrackTintColor = AppColors.primaryAccent
        interGapSlider.addTarget(self, action: #selector(interGapChanged), for: .valueChanged)
        interGapValueLabel.text = String(format: "%.1fs", settings.interSegmentGapSeconds)

        // Preroll
        let ms = settings.prerollMs
        let idx = [0, 100, 200, 300].firstIndex(of: max(0, min(ms, 300))) ?? 0
        prerollSeg.selectedSegmentIndex = idx
        prerollSeg.selectedSegmentTintColor = AppColors.primaryAccent
        prerollSeg.addTarget(self, action: #selector(prerollChanged), for: .valueChanged)

        // Duck
        duckSwitch.isOn = settings.duckOthers
        duckSwitch.onTintColor = .systemTeal
        duckSwitch.addTarget(self, action: #selector(duckToggled(_:)), for: .valueChanged)
        duckValueLabel.text = settings.duckOthers ? L10n("settings.enabled") : L10n("settings.disabled")

        // Daily news reminder
        reminderSwitch.isOn = NewsNotificationService.isEnabled
        reminderSwitch.onTintColor = AppColors.primaryAccent
        reminderSwitch.addTarget(self, action: #selector(reminderToggled(_:)), for: .valueChanged)

        reminderTimePicker.datePickerMode = .time
        reminderTimePicker.preferredDatePickerStyle = .compact
        var comps = DateComponents()
        comps.hour = NewsNotificationService.reminderHour
        comps.minute = NewsNotificationService.reminderMinute
        reminderTimePicker.date = Calendar.current.date(from: comps) ?? Date()
        reminderTimePicker.addTarget(self, action: #selector(reminderTimeChanged(_:)), for: .valueChanged)

        updateReminderRows()
    }

    private func updateReminderRows() {
        let on = NewsNotificationService.isEnabled
        reminderValueLabel.text = on ? L10n("settings.enabled") : L10n("settings.disabled")
        reminderTimeRow?.isHidden = !on
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

    private func makeSectionStack(header: String, stamp: String? = nil) -> UIStackView {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false

        let headerRow = UIStackView()
        headerRow.axis = .horizontal
        headerRow.spacing = 10
        headerRow.alignment = .center
        if let stamp {
            headerRow.addArrangedSubview(makeStampMedallion(stamp))
        }
        headerRow.addArrangedSubview(makeSectionHeaderLabel(header))
        stack.addArrangedSubview(headerRow)

        let rule = GoldRule()
        stack.addArrangedSubview(rule)
        stack.setCustomSpacing(6, after: headerRow)
        return stack
    }

    /// Parchment medallion with a plum-ink stamp — the bookplate treatment
    /// from the Add screen, at section-header scale.
    private func makeStampMedallion(_ assetName: String) -> UIView {
        let circle = UIView()
        circle.translatesAutoresizingMaskIntoConstraints = false
        circle.backgroundColor = UIColor(red: 0.93, green: 0.89, blue: 0.83, alpha: 1)
        circle.layer.cornerRadius = 16
        circle.layer.borderWidth = 1.0 / UIScreen.main.scale
        circle.layer.borderColor = AppColors.goldHairline.cgColor
        let stampView = UIImageView(image: UIImage(named: assetName))
        stampView.translatesAutoresizingMaskIntoConstraints = false
        stampView.contentMode = .scaleAspectFit
        circle.addSubview(stampView)
        NSLayoutConstraint.activate([
            circle.widthAnchor.constraint(equalToConstant: 32),
            circle.heightAnchor.constraint(equalToConstant: 32),
            stampView.centerXAnchor.constraint(equalTo: circle.centerXAnchor),
            stampView.centerYAnchor.constraint(equalTo: circle.centerYAnchor),
            stampView.widthAnchor.constraint(equalToConstant: 24),
            stampView.heightAnchor.constraint(equalToConstant: 24),
        ])
        return circle
    }

    private func makeSectionHeaderLabel(_ text: String) -> UILabel {
        let label = UILabel()
        label.attributedText = AppFont.plateCaption(text)
        return label
    }

    /// Small explanatory caption under a control.
    private func makeHelperText(_ text: String) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = .systemFont(ofSize: 13, weight: .regular)
        label.textColor = AppColors.secondaryText
        label.numberOfLines = 0
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
        slider.minimumTrackTintColor = AppColors.primaryAccent
        slider.maximumTrackTintColor = AppColors.goldHairline
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
        duckValueLabel.text = sw.isOn ? L10n("settings.enabled") : L10n("settings.disabled")
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    @objc private func reminderToggled(_ sw: UISwitch) {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        if sw.isOn {
            NewsNotificationService.enableReminder { [weak self] granted in
                // If the user declined the system prompt, reflect that back.
                self?.reminderSwitch.setOn(granted, animated: true)
                self?.updateReminderRows()
                if !granted { self?.presentPermissionDeniedHint() }
            }
        } else {
            NewsNotificationService.disableReminder()
            updateReminderRows()
        }
    }

    @objc private func reminderTimeChanged(_ picker: UIDatePicker) {
        let comps = Calendar.current.dateComponents([.hour, .minute], from: picker.date)
        NewsNotificationService.reminderHour = comps.hour ?? 8
        NewsNotificationService.reminderMinute = comps.minute ?? 0
        NewsNotificationService.refreshSchedule()
    }

    private func presentPermissionDeniedHint() {
        let alert = UIAlertController(title: L10n("settings.news_reminder.denied_title"),
                                      message: L10n("settings.news_reminder.denied_message"),
                                      preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: L10n("common.ok"), style: .default))
        present(alert, animated: true)
    }

    // The background uses AppColors.calmBackground, a dynamic UIColor that
    // resolves per-appearance automatically — no traitCollectionDidChange
    // override needed (and that API is deprecated in iOS 17).
}

// MARK: - SpeedPresetStripDelegate

extension SettingsViewController: SpeedPresetStripDelegate {
    func speedPresetStrip(_ strip: SpeedPresetStrip, didSelectSpeed speed: Float) {
        settings.simpleSpeed = speed
    }
}
