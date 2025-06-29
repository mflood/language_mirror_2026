import UIKit

class SiivRecordingCell: UITableViewCell {
    
    // MARK: - UI Components
    @IBOutlet weak var containerView: UIView!
    @IBOutlet weak var recordingIconImageView: UIImageView!
    @IBOutlet weak var recordingNameLabel: UILabel!
    @IBOutlet weak var recordingDurationLabel: UILabel!
    @IBOutlet weak var recordingDateLabel: UILabel!
    @IBOutlet weak var recordingSizeLabel: UILabel!
    @IBOutlet weak var playButton: UIButton!
    @IBOutlet weak var deleteButton: UIButton!
    
    // MARK: - Properties
    private var recording: Recording?
    private var isPlaying = false
    
    // MARK: - Lifecycle
    override func awakeFromNib() {
        super.awakeFromNib()
        setupUI()
    }
    
    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
        updateSelectionState(selected)
    }
    
    // MARK: - UI Setup
    private func setupUI() {
        backgroundColor = .clear
        selectionStyle = .none
        
        // Container view
        containerView.backgroundColor = .white
        containerView.layer.cornerRadius = 12
        containerView.layer.shadowColor = UIColor.black.cgColor
        containerView.layer.shadowOffset = CGSize(width: 0, height: 2)
        containerView.layer.shadowRadius = 4
        containerView.layer.shadowOpacity = 0.1
        
        // Recording icon
        recordingIconImageView.image = UIImage(systemName: "waveform")
        recordingIconImageView.tintColor = UIColor(named: "PrimaryBlue")
        recordingIconImageView.contentMode = .scaleAspectFit
        
        // Labels
        recordingNameLabel.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
        recordingNameLabel.textColor = UIColor(named: "PrimaryText")
        recordingNameLabel.numberOfLines = 2
        
        recordingDurationLabel.font = UIFont.monospacedDigitSystemFont(ofSize: 14, weight: .regular)
        recordingDurationLabel.textColor = UIColor(named: "SecondaryText")
        
        recordingDateLabel.font = UIFont.systemFont(ofSize: 12, weight: .regular)
        recordingDateLabel.textColor = UIColor(named: "SecondaryText")
        
        recordingSizeLabel.font = UIFont.systemFont(ofSize: 12, weight: .regular)
        recordingSizeLabel.textColor = UIColor(named: "SecondaryText")
        
        // Play button
        playButton.backgroundColor = UIColor(named: "PrimaryBlue")
        playButton.setTitleColor(.white, for: .normal)
        playButton.titleLabel?.font = UIFont.systemFont(ofSize: 14, weight: .semibold)
        playButton.layer.cornerRadius = 16
        playButton.setTitle("▶", for: .normal)
        playButton.addTarget(self, action: #selector(playButtonTapped), for: .touchUpInside)
        
        // Delete button
        deleteButton.backgroundColor = UIColor(named: "ErrorRed")
        deleteButton.setTitleColor(.white, for: .normal)
        deleteButton.titleLabel?.font = UIFont.systemFont(ofSize: 14, weight: .semibold)
        deleteButton.layer.cornerRadius = 16
        deleteButton.setTitle("🗑", for: .normal)
        deleteButton.addTarget(self, action: #selector(deleteButtonTapped), for: .touchUpInside)
    }
    
    // MARK: - Configuration
    func configure(with recording: Recording) {
        self.recording = recording
        
        recordingNameLabel.text = recording.name
        recordingDurationLabel.text = formatDuration(recording.duration)
        recordingSizeLabel.text = recording.fileSize
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .short
        recordingDateLabel.text = dateFormatter.string(from: recording.creationDate)
    }
    
    // MARK: - Selection State
    private func updateSelectionState(_ selected: Bool) {
        if selected {
            containerView.layer.borderWidth = 2
            containerView.layer.borderColor = UIColor(named: "PrimaryBlue")?.cgColor
        } else {
            containerView.layer.borderWidth = 0
        }
    }
    
    // MARK: - Playback State
    func setPlaying(_ playing: Bool) {
        isPlaying = playing
        
        if playing {
            playButton.setTitle("⏸", for: .normal)
            playButton.backgroundColor = UIColor(named: "WarningOrange")
            recordingIconImageView.tintColor = UIColor(named: "SuccessGreen")
        } else {
            playButton.setTitle("▶", for: .normal)
            playButton.backgroundColor = UIColor(named: "PrimaryBlue")
            recordingIconImageView.tintColor = UIColor(named: "PrimaryBlue")
        }
    }
    
    // MARK: - Actions
    @objc private func playButtonTapped(_ sender: UIButton) {
        // This will be handled by the table view delegate
        // The button tap will trigger the cell selection
    }
    
    @objc private func deleteButtonTapped(_ sender: UIButton) {
        guard let recording = recording else { return }
        
        let alert = UIAlertController(
            title: "Delete Recording",
            message: "Are you sure you want to delete '\(recording.name)'?",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "Delete", style: .destructive) { _ in
            self.deleteRecording(recording)
        })
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        // Find the view controller to present the alert
        if let viewController = self.findViewController() {
            viewController.present(alert, animated: true)
        }
    }
    
    private func deleteRecording(_ recording: Recording) {
        do {
            try FileManager.default.removeItem(at: recording.url)
            
            // Notify the parent view controller to refresh the list
            if let viewController = self.findViewController() as? SiivAudioRecorderViewController {
                viewController.loadRecordings()
            }
        } catch {
            print("Failed to delete recording: \(error)")
        }
    }
    
    // MARK: - Helper Methods
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    private func findViewController() -> UIViewController? {
        var responder: UIResponder? = self
        while let nextResponder = responder?.next {
            if let viewController = nextResponder as? UIViewController {
                return viewController
            }
            responder = nextResponder
        }
        return nil
    }
} 
