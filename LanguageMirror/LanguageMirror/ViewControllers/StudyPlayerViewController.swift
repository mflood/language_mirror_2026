import UIKit

import UIKit
import AVFoundation

final class StudyPlayerViewController: UIViewController {

    // MARK: - Dependencies
    private let track: AudioTrack
    private let arrangement: Arrangement
    private let slices: [Slice]

    // MARK: - AVAudio
    private var audioPlayer: AVAudioPlayer?

    // MARK: - Progress
    private var currentSliceIndex: Int = 0
    private var loopsRemaining: Int = 0
    private var loopCount: Int {
        currentProgress.customLoopCount ?? UserDataManager.shared.profile.defaultLoopCount
    }

    private var currentProgress: TrackProgress {
        get {
            UserDataManager.shared.progress(for: track.id)
                ?? TrackProgress(trackId: track.id, arrangementId: arrangement.id, currentSliceIndex: 0, loopsCompleted: 0, customLoopCount: nil, lastUpdated: Date())
        }
    }

    // MARK: - UI
    private let sliceLabel = UILabel()
    private let playButton = UIButton(type: .system)

    // MARK: - Init
    init(track: AudioTrack, arrangement: Arrangement, slices: [Slice]) {
        self.track = track
        self.arrangement = arrangement
        self.slices = slices
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        title = "Study Mode"
        setupUI()
        loadProgress()
    }

    // MARK: - UI Setup
    private func setupUI() {
        sliceLabel.font = .monospacedSystemFont(ofSize: 20, weight: .medium)
        sliceLabel.textAlignment = .center
        sliceLabel.text = "Ready"

        playButton.setTitle("Play", for: .normal)
        playButton.addTarget(self, action: #selector(playCurrentSlice), for: .touchUpInside)

        view.addSubview(sliceLabel)
        view.addSubview(playButton)
        sliceLabel.translatesAutoresizingMaskIntoConstraints = false
        playButton.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            sliceLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            sliceLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -40),
            playButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            playButton.topAnchor.constraint(equalTo: sliceLabel.bottomAnchor, constant: 20)
        ])
    }

    private func loadProgress() {
        let progress = currentProgress
        currentSliceIndex = progress.currentSliceIndex
        loopsRemaining = loopCount - progress.loopsCompleted
        updateUI()
    }

    private func updateUI() {
        let slice = slices[currentSliceIndex]
        sliceLabel.text = String(format: "Slice %d (%.2f–%.2f)", currentSliceIndex + 1, slice.start, slice.end)
    }

    // MARK: - Audio
    @objc private func playCurrentSlice() {
        let slice = slices[currentSliceIndex]
        let url = DataManager.shared.url(for: track)

        do {
            let data = try Data(contentsOf: url)
            audioPlayer = try AVAudioPlayer(data: data)
            audioPlayer?.currentTime = slice.start
            audioPlayer?.play()

            DispatchQueue.main.asyncAfter(deadline: .now() + (slice.end - slice.start)) { [weak self] in
                self?.audioPlayer?.stop()
                self?.handlePlaybackEnd()
            }

        } catch {
            print("Audio error: \(error)")
        }
    }

    private func handlePlaybackEnd() {
        loopsRemaining -= 1

        if loopsRemaining > 0 {
            playCurrentSlice()
        } else {
            advanceToNextSlice()
        }
    }

    private func advanceToNextSlice() {
        currentSliceIndex += 1
        if currentSliceIndex >= slices.count {
            sliceLabel.text = "Done!"
            saveProgress(final: true)
            return
        }
        loopsRemaining = loopCount
        saveProgress()
        updateUI()
    }

    private func saveProgress(final: Bool = false) {
        var progress = currentProgress
        progress.arrangementId = arrangement.id
        progress.currentSliceIndex = final ? 0 : currentSliceIndex
        progress.loopsCompleted = final ? 0 : loopCount - loopsRemaining
        progress.lastUpdated = Date()
        UserDataManager.shared.save(progress)
    }
}
