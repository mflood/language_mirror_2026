//
//  StudyPlayerViewController.swift
//  LanguageMirror
//
//  Created by Matthew Flood on 6/28/25.
//
import UIKit

// MARK: - StudyPlayerViewController

final class StudyPlayerViewController: UIViewController {

    // MARK: - Properties

    private let track: AudioTrack
    private let slices: [Slice]
    private let player = SlicePlayer()
    private var loopCount: Int = 4

    private let transcriptLabel = UILabel()
    private let playBtn = UIButton(type: .system)
    private let slider = UISlider()

    // MARK: - Initializers

    init(track: AudioTrack, slices: [Slice]) {
        self.track = track
        self.slices = slices
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Player"
        view.backgroundColor = .systemBackground
        setupUI()
        layoutUI()
    }

    // MARK: - Setup

    private func setupUI() {
        // Transcript Label
        transcriptLabel.translatesAutoresizingMaskIntoConstraints = false
        transcriptLabel.font = UIFont.preferredFont(forTextStyle: .title2)
        transcriptLabel.textAlignment = .center
        transcriptLabel.text = slices.first?.transcript

        // Play Button
        playBtn.translatesAutoresizingMaskIntoConstraints = false
        playBtn.setTitle("Play", for: .normal)
        playBtn.addTarget(self, action: #selector(togglePlay), for: .touchUpInside)

        // Slider
        slider.translatesAutoresizingMaskIntoConstraints = false
        slider.minimumValue = 1
        slider.maximumValue = 100
        slider.value = Float(loopCount)
        slider.addTarget(self, action: #selector(sliderChanged), for: .valueChanged)

        view.addSubview(transcriptLabel)
        view.addSubview(playBtn)
        view.addSubview(slider)
    }

    private func layoutUI() {
        NSLayoutConstraint.activate([
            transcriptLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 40),
            transcriptLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            transcriptLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),

            playBtn.topAnchor.constraint(equalTo: transcriptLabel.bottomAnchor, constant: 40),
            playBtn.centerXAnchor.constraint(equalTo: view.centerXAnchor),

            slider.topAnchor.constraint(equalTo: playBtn.bottomAnchor, constant: 40),
            slider.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 32),
            slider.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -32)
        ])
    }

    // MARK: - Actions

    @objc private func togglePlay() {
        let isPlaying = playBtn.currentTitle == "Play"
        playBtn.setTitle(isPlaying ? "Pause" : "Play", for: .normal)

        if isPlaying {
            player.play(trackURL: track.fileURL, slices: slices, loops: loopCount)
        } else {
            player.pause()
        }
    }

    @objc private func sliderChanged() {
        loopCount = Int(slider.value)
    }
}
