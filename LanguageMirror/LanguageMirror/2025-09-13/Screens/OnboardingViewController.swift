//
//  OnboardingViewController.swift
//  LanguageMirror
//
//  First-launch onboarding: one decision (which language am I learning),
//  one explanation (how shadowing works), one big button that drops the
//  user straight into an auto-playing practice session. Deliberately
//  minimal — every extra choice here is a place to lose an ADHD learner.
//

import UIKit

protocol OnboardingViewControllerDelegate: AnyObject {
    /// direction is the BCP-47 base code of the language being learned ("ko"/"en").
    func onboardingDidFinish(_ vc: OnboardingViewController, learningLanguage: String)
    func onboardingDidSkip(_ vc: OnboardingViewController)
}

final class OnboardingViewController: UIViewController {

    weak var delegate: OnboardingViewControllerDelegate?

    private var learningLanguage = "ko"
    private let pageOne = UIView()
    private let pageTwo = UIView()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = AppColors.calmBackground
        buildSkipButton()
        buildPageOne()
        buildPageTwo()
        pageTwo.alpha = 0
        pageTwo.isHidden = true
    }

    // MARK: - Skip

    private func buildSkipButton() {
        let skip = UIButton(type: .system)
        skip.translatesAutoresizingMaskIntoConstraints = false
        skip.setTitle(L10n("onboarding.skip"), for: .normal)
        skip.titleLabel?.font = .systemFont(ofSize: 15, weight: .regular)
        skip.setTitleColor(AppColors.secondaryText, for: .normal)
        skip.addTarget(self, action: #selector(skipTapped), for: .touchUpInside)
        view.addSubview(skip)
        NSLayoutConstraint.activate([
            skip.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
            skip.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
        ])
    }

    // MARK: - Page 1: which language?

    private func buildPageOne() {
        pageOne.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(pageOne)
        pinPage(pageOne)

        let title = UILabel()
        title.translatesAutoresizingMaskIntoConstraints = false
        title.text = L10n("onboarding.title")
        title.font = .systemFont(ofSize: 34, weight: .bold)
        title.textColor = AppColors.primaryText
        title.textAlignment = .center
        title.numberOfLines = 0

        let tagline = UILabel()
        tagline.translatesAutoresizingMaskIntoConstraints = false
        tagline.text = L10n("onboarding.tagline")
        tagline.font = .systemFont(ofSize: 17, weight: .regular)
        tagline.textColor = AppColors.secondaryText
        tagline.textAlignment = .center
        tagline.numberOfLines = 0

        let question = UILabel()
        question.translatesAutoresizingMaskIntoConstraints = false
        question.text = L10n("onboarding.learning_question")
        question.font = .systemFont(ofSize: 20, weight: .semibold)
        question.textColor = AppColors.primaryText
        question.textAlignment = .center
        question.numberOfLines = 0

        let koreanButton = languageButton(emoji: "🇰🇷", title: L10n("onboarding.lang.korean"), lang: "ko")
        let englishButton = languageButton(emoji: "🇺🇸", title: L10n("onboarding.lang.english"), lang: "en")

        [title, tagline, question, koreanButton, englishButton].forEach { pageOne.addSubview($0) }

        NSLayoutConstraint.activate([
            title.topAnchor.constraint(equalTo: pageOne.topAnchor, constant: 80),
            title.leadingAnchor.constraint(equalTo: pageOne.leadingAnchor, constant: 24),
            title.trailingAnchor.constraint(equalTo: pageOne.trailingAnchor, constant: -24),

            tagline.topAnchor.constraint(equalTo: title.bottomAnchor, constant: 12),
            tagline.leadingAnchor.constraint(equalTo: pageOne.leadingAnchor, constant: 32),
            tagline.trailingAnchor.constraint(equalTo: pageOne.trailingAnchor, constant: -32),

            question.topAnchor.constraint(equalTo: tagline.bottomAnchor, constant: 64),
            question.leadingAnchor.constraint(equalTo: pageOne.leadingAnchor, constant: 24),
            question.trailingAnchor.constraint(equalTo: pageOne.trailingAnchor, constant: -24),

            koreanButton.topAnchor.constraint(equalTo: question.bottomAnchor, constant: 24),
            koreanButton.leadingAnchor.constraint(equalTo: pageOne.leadingAnchor, constant: 32),
            koreanButton.trailingAnchor.constraint(equalTo: pageOne.trailingAnchor, constant: -32),
            koreanButton.heightAnchor.constraint(equalToConstant: 64),

            englishButton.topAnchor.constraint(equalTo: koreanButton.bottomAnchor, constant: 16),
            englishButton.leadingAnchor.constraint(equalTo: pageOne.leadingAnchor, constant: 32),
            englishButton.trailingAnchor.constraint(equalTo: pageOne.trailingAnchor, constant: -32),
            englishButton.heightAnchor.constraint(equalToConstant: 64),
        ])
    }

    private func languageButton(emoji: String, title: String, lang: String) -> UIButton {
        var config = UIButton.Configuration.filled()
        config.title = "\(emoji)  \(title)"
        config.baseBackgroundColor = AppColors.primaryAccent
        config.baseForegroundColor = .white
        config.cornerStyle = .large
        var attrs = AttributeContainer()
        attrs.font = UIFont.systemFont(ofSize: 20, weight: .semibold)
        config.attributedTitle = AttributedString("\(emoji)  \(title)", attributes: attrs)
        let button = UIButton(configuration: config)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.accessibilityIdentifier = "onboarding.lang.\(lang)"
        button.addAction(UIAction { [weak self] _ in
            guard let self else { return }
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            self.learningLanguage = lang
            self.showPageTwo()
        }, for: .touchUpInside)
        return button
    }

    // MARK: - Page 2: how it works → CTA

    private func buildPageTwo() {
        pageTwo.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(pageTwo)
        pinPage(pageTwo)

        let title = UILabel()
        title.translatesAutoresizingMaskIntoConstraints = false
        title.text = L10n("onboarding.how.title")
        title.font = .systemFont(ofSize: 28, weight: .bold)
        title.textColor = AppColors.primaryText
        title.textAlignment = .center

        let steps = UIStackView()
        steps.translatesAutoresizingMaskIntoConstraints = false
        steps.axis = .vertical
        steps.spacing = 24
        steps.addArrangedSubview(stepRow(icon: "headphones",
                                         title: L10n("onboarding.how.step1.title"),
                                         body: L10n("onboarding.how.step1.body")))
        steps.addArrangedSubview(stepRow(icon: "repeat",
                                         title: L10n("onboarding.how.step2.title"),
                                         body: L10n("onboarding.how.step2.body")))
        steps.addArrangedSubview(stepRow(icon: "waveform.and.mic",
                                         title: L10n("onboarding.how.step3.title"),
                                         body: L10n("onboarding.how.step3.body")))

        var config = UIButton.Configuration.filled()
        config.baseBackgroundColor = AppColors.primaryAccent
        config.baseForegroundColor = .white
        config.cornerStyle = .large
        var attrs = AttributeContainer()
        attrs.font = UIFont.systemFont(ofSize: 20, weight: .semibold)
        config.attributedTitle = AttributedString("▶  " + L10n("onboarding.cta"), attributes: attrs)
        let cta = UIButton(configuration: config)
        cta.translatesAutoresizingMaskIntoConstraints = false
        cta.accessibilityIdentifier = "onboarding.cta"
        cta.addAction(UIAction { [weak self] _ in
            guard let self else { return }
            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
            self.delegate?.onboardingDidFinish(self, learningLanguage: self.learningLanguage)
        }, for: .touchUpInside)

        [title, steps, cta].forEach { pageTwo.addSubview($0) }

        NSLayoutConstraint.activate([
            title.topAnchor.constraint(equalTo: pageTwo.topAnchor, constant: 96),
            title.leadingAnchor.constraint(equalTo: pageTwo.leadingAnchor, constant: 24),
            title.trailingAnchor.constraint(equalTo: pageTwo.trailingAnchor, constant: -24),

            steps.topAnchor.constraint(equalTo: title.bottomAnchor, constant: 40),
            steps.leadingAnchor.constraint(equalTo: pageTwo.leadingAnchor, constant: 32),
            steps.trailingAnchor.constraint(equalTo: pageTwo.trailingAnchor, constant: -32),

            cta.leadingAnchor.constraint(equalTo: pageTwo.leadingAnchor, constant: 32),
            cta.trailingAnchor.constraint(equalTo: pageTwo.trailingAnchor, constant: -32),
            cta.bottomAnchor.constraint(equalTo: pageTwo.safeAreaLayoutGuide.bottomAnchor, constant: -32),
            cta.heightAnchor.constraint(equalToConstant: 60),
        ])
    }

    private func stepRow(icon: String, title: String, body: String) -> UIView {
        let row = UIView()
        row.translatesAutoresizingMaskIntoConstraints = false

        let iconView = UIImageView(image: UIImage(systemName: icon))
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.tintColor = AppColors.primaryAccent
        iconView.contentMode = .scaleAspectFit

        let titleLabel = UILabel()
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.text = title
        titleLabel.font = .systemFont(ofSize: 18, weight: .semibold)
        titleLabel.textColor = AppColors.primaryText

        let bodyLabel = UILabel()
        bodyLabel.translatesAutoresizingMaskIntoConstraints = false
        bodyLabel.text = body
        bodyLabel.font = .systemFont(ofSize: 15, weight: .regular)
        bodyLabel.textColor = AppColors.secondaryText
        bodyLabel.numberOfLines = 0

        [iconView, titleLabel, bodyLabel].forEach { row.addSubview($0) }
        NSLayoutConstraint.activate([
            iconView.leadingAnchor.constraint(equalTo: row.leadingAnchor),
            iconView.topAnchor.constraint(equalTo: row.topAnchor, constant: 2),
            iconView.widthAnchor.constraint(equalToConstant: 32),
            iconView.heightAnchor.constraint(equalToConstant: 32),

            titleLabel.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 16),
            titleLabel.topAnchor.constraint(equalTo: row.topAnchor),
            titleLabel.trailingAnchor.constraint(equalTo: row.trailingAnchor),

            bodyLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            bodyLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),
            bodyLabel.trailingAnchor.constraint(equalTo: row.trailingAnchor),
            bodyLabel.bottomAnchor.constraint(equalTo: row.bottomAnchor),
        ])
        return row
    }

    // MARK: - Helpers

    private func pinPage(_ page: UIView) {
        NSLayoutConstraint.activate([
            page.topAnchor.constraint(equalTo: view.topAnchor),
            page.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            page.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            page.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }

    private func showPageTwo() {
        pageTwo.isHidden = false
        UIView.animate(withDuration: 0.35) {
            self.pageOne.alpha = 0
            self.pageTwo.alpha = 1
        } completion: { _ in
            self.pageOne.isHidden = true
        }
    }

    @objc private func skipTapped() {
        delegate?.onboardingDidSkip(self)
    }
}
