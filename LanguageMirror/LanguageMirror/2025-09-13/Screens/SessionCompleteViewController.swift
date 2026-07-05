//
//  SessionCompleteViewController.swift
//  LanguageMirror
//
//  Celebration sheet shown when a practice set finishes naturally. The
//  reward moment the loop engine was missing: a clear "you did it",
//  the numbers that prove it, and one obvious next action.
//

import UIKit

final class SessionCompleteViewController: UIViewController {

    var onPracticeAgain: (() -> Void)?
    var onDone: (() -> Void)?

    private let setTitle: String
    private let clipCount: Int
    private let totalPlays: Int
    /// Consecutive practice days; hidden when nil (streak ships separately).
    private let streakDays: Int?

    private let miriView = MiriView()

    init(setTitle: String, clipCount: Int, totalPlays: Int, streakDays: Int? = nil) {
        self.setTitle = setTitle
        self.clipCount = clipCount
        self.totalPlays = totalPlays
        self.streakDays = streakDays
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = AppColors.calmBackground

        // Miri celebrates with you — the reward moment gets a character,
        // not a stock checkmark.
        miriView.expression = .celebrating
        miriView.translatesAutoresizingMaskIntoConstraints = false
        miriView.alpha = 0
        miriView.transform = CGAffineTransform(scaleX: 0.4, y: 0.4)

        let titleLabel = UILabel()
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.text = L10n("session_complete.title")
        titleLabel.font = AppFont.rounded(28, weight: .bold)
        titleLabel.textColor = AppColors.primaryText
        titleLabel.textAlignment = .center

        let statsLabel = UILabel()
        statsLabel.translatesAutoresizingMaskIntoConstraints = false
        let sentencesText = clipCount == 1
            ? L10n("session_complete.sentences.one")
            : L10nf("session_complete.sentences", clipCount)
        statsLabel.text = L10nf("session_complete.stats", sentencesText, totalPlays)
        statsLabel.font = AppFont.rounded(17, weight: .medium)
        statsLabel.textColor = AppColors.secondaryText
        statsLabel.textAlignment = .center

        let setLabel = UILabel()
        setLabel.translatesAutoresizingMaskIntoConstraints = false
        setLabel.text = setTitle
        setLabel.font = .systemFont(ofSize: 14, weight: .regular)
        setLabel.textColor = AppColors.secondaryText
        setLabel.textAlignment = .center
        setLabel.numberOfLines = 1

        let streakLabel = UILabel()
        streakLabel.translatesAutoresizingMaskIntoConstraints = false
        if let streakDays, streakDays > 1 {
            streakLabel.text = L10nf("session_complete.streak", streakDays)
            streakLabel.font = .systemFont(ofSize: 16, weight: .semibold)
            streakLabel.textColor = AppColors.primaryText
            streakLabel.textAlignment = .center
        } else {
            streakLabel.isHidden = true
        }

        var againConfig = UIButton.Configuration.filled()
        againConfig.baseBackgroundColor = AppColors.primaryAccent
        againConfig.baseForegroundColor = .white
        againConfig.cornerStyle = .large
        var againAttrs = AttributeContainer()
        againAttrs.font = AppFont.rounded(18, weight: .semibold)
        againConfig.attributedTitle = AttributedString(L10n("session_complete.again"), attributes: againAttrs)
        let againButton = UIButton(configuration: againConfig)
        againButton.translatesAutoresizingMaskIntoConstraints = false
        againButton.addAction(UIAction { [weak self] _ in
            guard let self else { return }
            self.dismiss(animated: true) { self.onPracticeAgain?() }
        }, for: .touchUpInside)

        let doneButton = UIButton(type: .system)
        doneButton.translatesAutoresizingMaskIntoConstraints = false
        doneButton.setTitle(L10n("session_complete.done"), for: .normal)
        doneButton.titleLabel?.font = .systemFont(ofSize: 17, weight: .regular)
        doneButton.setTitleColor(AppColors.secondaryText, for: .normal)
        doneButton.addAction(UIAction { [weak self] _ in
            guard let self else { return }
            self.dismiss(animated: true) { self.onDone?() }
        }, for: .touchUpInside)

        [miriView, titleLabel, statsLabel, setLabel, streakLabel, againButton, doneButton]
            .forEach { view.addSubview($0) }

        NSLayoutConstraint.activate([
            miriView.topAnchor.constraint(equalTo: view.topAnchor, constant: 40),
            miriView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            miriView.widthAnchor.constraint(equalToConstant: 96),
            miriView.heightAnchor.constraint(equalToConstant: 96),

            titleLabel.topAnchor.constraint(equalTo: miriView.bottomAnchor, constant: 12),
            titleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            titleLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),

            statsLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            statsLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            statsLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),

            setLabel.topAnchor.constraint(equalTo: statsLabel.bottomAnchor, constant: 4),
            setLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            setLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),

            streakLabel.topAnchor.constraint(equalTo: setLabel.bottomAnchor, constant: 12),
            streakLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            streakLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),

            againButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 32),
            againButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -32),
            againButton.heightAnchor.constraint(equalToConstant: 54),
            againButton.bottomAnchor.constraint(equalTo: doneButton.topAnchor, constant: -8),

            doneButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 32),
            doneButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -32),
            doneButton.heightAnchor.constraint(equalToConstant: 44),
            doneButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -12),
        ])
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        UIView.animate(withDuration: 0.5, delay: 0,
                       usingSpringWithDamping: 0.55, initialSpringVelocity: 0.8) {
            self.miriView.alpha = 1
            self.miriView.transform = .identity
        } completion: { _ in
            self.miriView.bounce()
        }
    }
}
