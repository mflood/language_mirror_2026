import UIKit

class SiivRecentDownloadCell: UITableViewCell {
    
    // MARK: - UI Components
    @IBOutlet weak var containerView: UIView!
    @IBOutlet weak var fileIconImageView: UIImageView!
    @IBOutlet weak var fileNameLabel: UILabel!
    @IBOutlet weak var fileInfoLabel: UILabel!
    @IBOutlet weak var downloadDateLabel: UILabel!
    @IBOutlet weak var playButton: UIButton!
    
    // MARK: - Properties
    private var download: SiivDownloadedAudio?
    
    // MARK: - Lifecycle
    override func awakeFromNib() {
        super.awakeFromNib()
        setupUI()
    }
    
    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
    }
    
    // MARK: - UI Setup
    private func setupUI() {
        // Container
        containerView.backgroundColor = .white
        containerView.layer.cornerRadius = 12
        containerView.layer.shadowColor = UIColor.black.cgColor
        containerView.layer.shadowOffset = CGSize(width: 0, height: 2)
        containerView.layer.shadowRadius = 4
        containerView.layer.shadowOpacity = 0.1
        
        // File icon
        fileIconImageView.image = UIImage(named: "imported_audio_icon")
        fileIconImageView.contentMode = .scaleAspectFit
        fileIconImageView.tintColor = UIColor(named: "PrimaryBlue")
        
        // File name
        fileNameLabel.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
        fileNameLabel.textColor = UIColor(named: "PrimaryText")
        fileNameLabel.numberOfLines = 1
        
        // File info
        fileInfoLabel.font = UIFont.systemFont(ofSize: 14, weight: .regular)
        fileInfoLabel.textColor = UIColor(named: "SecondaryText")
        fileInfoLabel.numberOfLines = 1
        
        // Download date
        downloadDateLabel.font = UIFont.systemFont(ofSize: 12, weight: .regular)
        downloadDateLabel.textColor = UIColor(named: "SecondaryText")
        
        // Play button
        playButton.setImage(UIImage(named: "play_button_150x150"), for: .normal)
        playButton.tintColor = UIColor(named: "PrimaryBlue")
        playButton.backgroundColor = UIColor(named: "BackgroundGray")
        playButton.layer.cornerRadius = 20
        playButton.layer.shadowColor = UIColor.black.cgColor
        playButton.layer.shadowOffset = CGSize(width: 0, height: 1)
        playButton.layer.shadowRadius = 2
        playButton.layer.shadowOpacity = 0.1
    }
    
    // MARK: - Configuration
    func configure(with download: SiivDownloadedAudio) {
        self.download = download
        
        fileNameLabel.text = download.name
        fileInfoLabel.text = "\(download.fileSize) • \(formatDuration(download.duration))"
        downloadDateLabel.text = formatDate(download.downloadDate)
    }
    
    // MARK: - Helper Methods
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        
        if minutes > 0 {
            return "\(minutes)m \(seconds)s"
        } else {
            return "\(seconds)s"
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    // MARK: - Actions
    @IBAction func playButtonTapped(_ sender: UIButton) {
        // TODO: Implement play functionality
        print("Play button tapped for: \(download?.name ?? "")")
    }
} 
