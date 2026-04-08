//
//  TranscriptDetailViewController.swift
//  LanguageMirror
//
//  Modal sheet that displays the full transcript text for the currently
//  playing practice clip. Designed to be presented from PracticeViewController
//  without interrupting playback.
//

import UIKit

final class TranscriptDetailViewController: UIViewController {

    private let textView = UITextView()
    private let titleLabel = UILabel()
    private let copyButton = UIButton(type: .system)
    private let shareButton = UIButton(type: .system)
    private let decreaseFontButton = UIButton(type: .system)
    private let increaseFontButton = UIButton(type: .system)
    private let actionRow = UIStackView()
    private let text: String
    private let clipTitle: String?

    private static let fontSizeKey = "transcript.fontSize"
    private static let minFontSize: CGFloat = 14
    private static let maxFontSize: CGFloat = 56
    private static let defaultFontSize: CGFloat = 19

    private var fontSize: CGFloat {
        get {
            let stored = UserDefaults.standard.double(forKey: Self.fontSizeKey)
            return stored > 0 ? CGFloat(stored) : Self.defaultFontSize
        }
        set {
            let clamped = max(Self.minFontSize, min(Self.maxFontSize, newValue))
            UserDefaults.standard.set(Double(clamped), forKey: Self.fontSizeKey)
            textView.font = .systemFont(ofSize: clamped, weight: .regular)
            NotificationCenter.default.post(name: .transcriptFontSizeDidChange, object: nil)
        }
    }

    init(text: String, clipTitle: String?) {
        self.text = text
        self.clipTitle = clipTitle
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor { trait in
            trait.userInterfaceStyle == .dark
                ? UIColor(red: 0.28, green: 0.16, blue: 0.16, alpha: 1.0)
                : UIColor(red: 1.00, green: 0.96, blue: 0.94, alpha: 1.0)
        }

        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = .systemFont(ofSize: 13, weight: .semibold)
        titleLabel.textColor = AppColors.secondaryText
        titleLabel.text = (clipTitle ?? "").uppercased()
        titleLabel.numberOfLines = 1
        view.addSubview(titleLabel)

        // Action row: A− A+ ⋯ copy share
        configureActionButton(decreaseFontButton, systemName: "textformat.size.smaller", action: #selector(decreaseFontTapped))
        configureActionButton(increaseFontButton, systemName: "textformat.size.larger", action: #selector(increaseFontTapped))
        configureActionButton(copyButton, systemName: "doc.on.doc", action: #selector(copyTapped))
        configureActionButton(shareButton, systemName: "square.and.arrow.up", action: #selector(shareTapped))

        let spacer = UIView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)

        actionRow.translatesAutoresizingMaskIntoConstraints = false
        actionRow.axis = .horizontal
        actionRow.alignment = .center
        actionRow.spacing = 8
        actionRow.addArrangedSubview(decreaseFontButton)
        actionRow.addArrangedSubview(increaseFontButton)
        actionRow.addArrangedSubview(spacer)
        actionRow.addArrangedSubview(copyButton)
        actionRow.addArrangedSubview(shareButton)
        view.addSubview(actionRow)

        textView.translatesAutoresizingMaskIntoConstraints = false
        textView.isEditable = false
        textView.isSelectable = true
        textView.backgroundColor = .clear
        textView.font = .systemFont(ofSize: fontSize, weight: .regular)
        textView.textColor = AppColors.primaryText
        textView.text = text
        textView.alwaysBounceVertical = true
        textView.textContainerInset = .zero
        textView.textContainer.lineFragmentPadding = 0
        view.addSubview(textView)

        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            titleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            titleLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),

            actionRow.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            actionRow.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            actionRow.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            actionRow.heightAnchor.constraint(equalToConstant: 36),

            textView.topAnchor.constraint(equalTo: actionRow.bottomAnchor, constant: 12),
            textView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            textView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            textView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
        ])
    }

    private func configureActionButton(_ button: UIButton, systemName: String, action: Selector) {
        button.translatesAutoresizingMaskIntoConstraints = false
        let config = UIImage.SymbolConfiguration(pointSize: 18, weight: .medium)
        button.setImage(UIImage(systemName: systemName, withConfiguration: config), for: .normal)
        button.tintColor = AppColors.primaryAccent
        button.addTarget(self, action: action, for: .touchUpInside)
        button.widthAnchor.constraint(equalToConstant: 36).isActive = true
        button.heightAnchor.constraint(equalToConstant: 36).isActive = true
    }

    @objc private func copyTapped() {
        UIPasteboard.general.string = text
        UINotificationFeedbackGenerator().notificationOccurred(.success)

        // Brief visual confirmation: swap icon to checkmark for a beat
        let original = copyButton.image(for: .normal)
        let config = UIImage.SymbolConfiguration(pointSize: 18, weight: .medium)
        copyButton.setImage(UIImage(systemName: "checkmark", withConfiguration: config), for: .normal)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.copyButton.setImage(original, for: .normal)
        }
    }

    @objc private func shareTapped() {
        let activityVC = UIActivityViewController(activityItems: [text], applicationActivities: nil)
        activityVC.popoverPresentationController?.sourceView = shareButton
        activityVC.popoverPresentationController?.sourceRect = shareButton.bounds
        present(activityVC, animated: true)
    }

    @objc private func decreaseFontTapped() {
        UISelectionFeedbackGenerator().selectionChanged()
        fontSize = fontSize - 2
    }

    @objc private func increaseFontTapped() {
        UISelectionFeedbackGenerator().selectionChanged()
        fontSize = fontSize + 2
    }
}

extension Notification.Name {
    static let transcriptFontSizeDidChange = Notification.Name("transcriptFontSizeDidChange")
}
