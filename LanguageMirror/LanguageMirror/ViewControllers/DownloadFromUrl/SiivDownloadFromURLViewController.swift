import UIKit
import AVFoundation
import UniformTypeIdentifiers

class SiivDownloadFromURLViewController: UIViewController {
    
    // MARK: - UI Components
    
    // Header
    @IBOutlet weak var headerTitleLabel: UILabel!
    // @IBOutlet weak var cancelButton: UIButton!
    
    // URL Input Section
    @IBOutlet weak var urlInputContainerView: UIView!
    @IBOutlet weak var urlTextField: UITextField!
    @IBOutlet weak var urlValidationLabel: UILabel!
    @IBOutlet weak var downloadButton: UIButton!
    
    // Download Progress Section
    @IBOutlet weak var downloadProgressView: UIView!
    @IBOutlet weak var downloadProgressBar: UIProgressView!
    @IBOutlet weak var downloadProgressLabel: UILabel!
    @IBOutlet weak var downloadSpeedLabel: UILabel!
    @IBOutlet weak var downloadTimeRemainingLabel: UILabel!
    @IBOutlet weak var cancelDownloadButton: UIButton!
    
    // File Info Section
    @IBOutlet weak var fileInfoView: UIView!
    @IBOutlet weak var fileNameLabel: UILabel!
    @IBOutlet weak var fileSizeLabel: UILabel!
    @IBOutlet weak var fileDurationLabel: UILabel!
    @IBOutlet weak var fileFormatLabel: UILabel!
    
    // Recent Downloads Section
    @IBOutlet weak var recentDownloadsTitleLabel: UILabel!
    @IBOutlet weak var recentDownloadsTableView: UITableView!
    @IBOutlet weak var noRecentDownloadsLabel: UILabel!
    
    // Loading Overlay
    @IBOutlet weak var loadingOverlayView: UIView!
    @IBOutlet weak var loadingActivityIndicator: UIActivityIndicatorView!
    @IBOutlet weak var loadingLabel: UILabel!
    
    // MARK: - Properties
    weak var delegate: SiivDownloadFromURLDelegate?
    private var downloadTask: URLSessionDownloadTask?
    private var downloadSession: URLSession?
    private var downloadStartTime: Date?
    private var downloadURL: URL?
    private var recentDownloads: [SiivDownloadedAudio] = []
    private var isDownloading = false
    private var isAnalyzing = false
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupURLSession()
        loadRecentDownloads()
        setupTableView()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        urlTextField.becomeFirstResponder()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if isDownloading {
            cancelDownload()
        }
    }
    
    // MARK: - UI Setup
    private func setupUI() {
        setupHeader()
        setupURLInputSection()
        setupDownloadProgressSection()
        setupFileInfoSection()
        setupRecentDownloadsSection()
        setupLoadingOverlay()
    }
    
    private func setupHeader() {
        headerTitleLabel.text = "Download from URL"
        headerTitleLabel.font = UIFont.systemFont(ofSize: 24, weight: .bold)
        headerTitleLabel.textColor = UIColor(named: "PrimaryText")
        
        //cancelButton.setTitle("Cancel", for: .normal)
        //cancelButton.setTitleColor(UIColor(named: "PrimaryBlue"), for: .normal)
        //cancelButton.titleLabel?.font = UIFont.systemFont(ofSize: 17, weight: .semibold)
    }
    
    private func setupURLInputSection() {
        urlInputContainerView.backgroundColor = .white
        urlInputContainerView.layer.cornerRadius = 12
        urlInputContainerView.layer.shadowColor = UIColor.black.cgColor
        urlInputContainerView.layer.shadowOffset = CGSize(width: 0, height: 2)
        urlInputContainerView.layer.shadowRadius = 4
        urlInputContainerView.layer.shadowOpacity = 0.1
        
        urlTextField.placeholder = "Enter audio file URL (e.g., https://example.com/audio.mp3)"
        urlTextField.font = UIFont.systemFont(ofSize: 16, weight: .regular)
        urlTextField.borderStyle = .none
        urlTextField.backgroundColor = UIColor(named: "BackgroundGray")
        urlTextField.layer.cornerRadius = 8
        urlTextField.leftView = UIView(frame: CGRect(x: 0, y: 0, width: 12, height: 0))
        urlTextField.leftViewMode = .always
        urlTextField.rightView = UIView(frame: CGRect(x: 0, y: 0, width: 12, height: 0))
        urlTextField.rightViewMode = .always
        urlTextField.addTarget(self, action: #selector(urlTextFieldDidChange), for: .editingChanged)
        
        urlValidationLabel.font = UIFont.systemFont(ofSize: 14, weight: .regular)
        urlValidationLabel.textColor = UIColor(named: "SecondaryText")
        urlValidationLabel.isHidden = true
        
        // downloadButton.backgroundColor = UIColor(named: "PrimaryBlue")
        // downloadButton.setTitleColor(.white, for: .normal)
        // downloadButton.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
        downloadButton.layer.cornerRadius = 8
        downloadButton.isEnabled = false
    }
    
    private func setupDownloadProgressSection() {
        downloadProgressView.backgroundColor = .white
        downloadProgressView.layer.cornerRadius = 12
        downloadProgressView.layer.shadowColor = UIColor.black.cgColor
        downloadProgressView.layer.shadowOffset = CGSize(width: 0, height: 2)
        downloadProgressView.layer.shadowRadius = 4
        downloadProgressView.layer.shadowOpacity = 0.1
        downloadProgressView.isHidden = true
        
        downloadProgressBar.progressTintColor = UIColor(named: "SuccessGreen")
        downloadProgressBar.trackTintColor = UIColor(named: "BackgroundGray")
        downloadProgressBar.layer.cornerRadius = 2
        downloadProgressBar.clipsToBounds = true
        
        downloadProgressLabel.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
        downloadProgressLabel.textColor = UIColor(named: "PrimaryText")
        
        downloadSpeedLabel.font = UIFont.systemFont(ofSize: 14, weight: .regular)
        downloadSpeedLabel.textColor = UIColor(named: "SecondaryText")
        
        downloadTimeRemainingLabel.font = UIFont.systemFont(ofSize: 14, weight: .regular)
        downloadTimeRemainingLabel.textColor = UIColor(named: "SecondaryText")
        
        cancelDownloadButton.setTitle("Cancel Download", for: .normal)
        cancelDownloadButton.setTitleColor(UIColor(named: "WarningOrange"), for: .normal)
        cancelDownloadButton.titleLabel?.font = UIFont.systemFont(ofSize: 14, weight: .semibold)
    }
    
    private func setupFileInfoSection() {
        fileInfoView.backgroundColor = .white
        fileInfoView.layer.cornerRadius = 12
        fileInfoView.layer.shadowColor = UIColor.black.cgColor
        fileInfoView.layer.shadowOffset = CGSize(width: 0, height: 2)
        fileInfoView.layer.shadowRadius = 4
        fileInfoView.layer.shadowOpacity = 0.1
        fileInfoView.isHidden = true
        
        [fileNameLabel, fileSizeLabel, fileDurationLabel, fileFormatLabel].forEach { label in
            label?.font = UIFont.systemFont(ofSize: 14, weight: .regular)
            label?.textColor = UIColor(named: "SecondaryText")
        }
        
        fileNameLabel.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
        fileNameLabel.textColor = UIColor(named: "PrimaryText")
    }
    
    private func setupRecentDownloadsSection() {
        recentDownloadsTitleLabel.text = "Recent Downloads"
        recentDownloadsTitleLabel.font = UIFont.systemFont(ofSize: 20, weight: .bold)
        recentDownloadsTitleLabel.textColor = UIColor(named: "PrimaryText")
        
        noRecentDownloadsLabel.text = "No recent downloads"
        noRecentDownloadsLabel.font = UIFont.systemFont(ofSize: 16, weight: .regular)
        noRecentDownloadsLabel.textColor = UIColor(named: "SecondaryText")
        noRecentDownloadsLabel.textAlignment = .center
        noRecentDownloadsLabel.isHidden = true
    }
    
    private func setupLoadingOverlay() {
        loadingOverlayView.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        loadingOverlayView.isHidden = true
        
        loadingLabel.text = "Analyzing file..."
        loadingLabel.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
        loadingLabel.textColor = .white
        loadingLabel.textAlignment = .center
    }
    
    private func setupURLSession() {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 300 // 5 minutes
        downloadSession = URLSession(configuration: configuration, delegate: self, delegateQueue: .main)
    }
    
    private func setupTableView() {
        recentDownloadsTableView.delegate = self
        recentDownloadsTableView.dataSource = self
        recentDownloadsTableView.backgroundColor = .clear
        recentDownloadsTableView.separatorStyle = .none
        recentDownloadsTableView.showsVerticalScrollIndicator = false
        
        let nib = UINib(nibName: "SiivRecentDownloadCell", bundle: nil)
        recentDownloadsTableView.register(nib, forCellReuseIdentifier: "SiivRecentDownloadCell")
    }
    
    // MARK: - Data Loading
    private func loadRecentDownloads() {
        // TODO: Load from Core Data
        recentDownloads = [
            SiivDownloadedAudio(
                id: "1",
                name: "Korean Lesson Audio",
                url: "https://example.com/korean.mp3",
                downloadDate: Date(),
                fileSize: "2.4 MB",
                duration: 180
            ),
            SiivDownloadedAudio(
                id: "2",
                name: "Chinese HSK Audio",
                url: "https://example.com/chinese.mp3",
                downloadDate: Date().addingTimeInterval(-3600),
                fileSize: "5.1 MB",
                duration: 420
            )
        ]
        
        updateRecentDownloadsUI()
    }
    
    private func updateRecentDownloadsUI() {
        noRecentDownloadsLabel.isHidden = !recentDownloads.isEmpty
        recentDownloadsTableView.reloadData()
    }
    
    // MARK: - URL Validation
    @objc private func urlTextFieldDidChange() {
        guard let urlString = urlTextField.text, !urlString.isEmpty else {
            urlValidationLabel.isHidden = true
            downloadButton.isEnabled = false
            return
        }
        
        if isValidURL(urlString) {
            urlValidationLabel.text = "✓ Valid URL"
            urlValidationLabel.textColor = UIColor(named: "SuccessGreen")
            urlValidationLabel.isHidden = false
            downloadButton.isEnabled = true
        } else {
            urlValidationLabel.text = "✗ Invalid URL format"
            urlValidationLabel.textColor = UIColor(named: "WarningOrange")
            urlValidationLabel.isHidden = false
            downloadButton.isEnabled = false
        }
    }
    
    private func isValidURL(_ urlString: String) -> Bool {
        guard let url = URL(string: urlString) else { return false }
        return UIApplication.shared.canOpenURL(url)
    }
    
    private func isAudioURL(_ url: URL) -> Bool {
        let audioExtensions = ["mp3", "m4a", "wav", "aac", "flac", "ogg"]
        let pathExtension = url.pathExtension.lowercased()
        return audioExtensions.contains(pathExtension)
    }
    
    // MARK: - Download Methods
    private func startDownload() {
        guard let urlString = urlTextField.text, let url = URL(string: urlString) else {
            showError("Invalid URL")
            return
        }
        
        if !isAudioURL(url) {
            showError("URL doesn't appear to be an audio file")
            return
        }
        
        isDownloading = true
        downloadURL = url
        downloadStartTime = Date()
        
        // Show progress UI
        downloadProgressView.isHidden = false
        downloadProgressBar.progress = 0
        downloadProgressLabel.text = "Starting download..."
        downloadSpeedLabel.text = ""
        downloadTimeRemainingLabel.text = ""
        
        // Start download
        downloadTask = downloadSession?.downloadTask(with: url)
        downloadTask?.resume()
    }
    
    private func cancelDownload() {
        downloadTask?.cancel()
        downloadTask = nil
        isDownloading = false
        
        // Hide progress UI
        downloadProgressView.isHidden = true
        fileInfoView.isHidden = true
    }
    
    private func processDownloadedFile(at localURL: URL, originalURL: URL?) {
        // Do file operations on background queue

            // Validate that the temporary file exists
            guard FileManager.default.fileExists(atPath: localURL.path) else {
                DispatchQueue.main.async {
                    self.hideLoading()
                    self.showError("Downloaded file not found. Please try downloading again.")
                }
                return
            }
            
            // Get the documents directory and ensure it exists
            guard let documentsPath = self.ensureDocumentsDirectoryExists() else {
                DispatchQueue.main.async {
                    self.hideLoading()
                    self.showError("Could not access or create Documents directory")
                }
                return
            }
            
            // Create a unique filename to avoid conflicts
            let originalFileName = localURL.lastPathComponent
        let fileExtension = self.getFileExtension(from: localURL, originalURL: originalURL)
            let baseFileName = originalFileName.replacingOccurrences(of: ".\(fileExtension)", with: "")
            let uniqueFileName = "\(baseFileName)_\(Int(Date().timeIntervalSince1970)).\(fileExtension)"
            let destinationURL = documentsPath.appendingPathComponent(uniqueFileName)
            
            print("Moving file from: \(localURL.path)")
            print("Moving file to: \(destinationURL.path)")
            
            do {
                // Check if destination already exists and remove it
                if FileManager.default.fileExists(atPath: destinationURL.path) {
                    try FileManager.default.removeItem(at: destinationURL)
                }
                
                // Move the file
                try FileManager.default.moveItem(at: localURL, to: destinationURL)
                
                print("File successfully moved to: \(destinationURL.path)")
                
                // Verify the file was moved successfully
                guard FileManager.default.fileExists(atPath: destinationURL.path) else {
                    DispatchQueue.main.async {
                        self.hideLoading()
                        self.showError("File was not saved correctly. Please try again.")
                    }
                    return
                }
                
                // Move to main queue for UI updates and audio analysis
                DispatchQueue.main.async {
                    self.hideLoading()
                    self.analyzeAudioFile(at: destinationURL, originalURL: originalURL)
                }
                
            } catch {
                DispatchQueue.main.async {
                    self.hideLoading()
                    print("Error moving file: \(error)")
                    print("Source URL: \(localURL)")
                    print("Destination URL: \(destinationURL)")
                    self.showError("Failed to save file: \(error.localizedDescription)")
                }
            }
        
        // Show loading immediately on main queue
        DispatchQueue.main.async {
            self.showLoading(message: "Analyzing audio file...")
        }
    }
    
    private func analyzeAudioFile(at url: URL, originalURL: URL?) {
        Task {
            do {
                let asset = AVAsset(url: url)
                
                // Use the new async API for iOS 16+
                let duration = try await asset.load(.duration)
                let tracks = try await asset.loadTracks(withMediaType: .audio)
                
                let durationSeconds = CMTimeGetSeconds(duration)
                var format = "Unknown"
                
                // Get format from the first audio track
                if let track = tracks.first {
                    let formatDescriptions = try await track.load(.formatDescriptions)
                    if let formatDescription = formatDescriptions.first {
                        let audioFormat = CMAudioFormatDescriptionGetStreamBasicDescription(formatDescription)
                        if let audioFormat = audioFormat {
                            let formatID = audioFormat.pointee.mFormatID
                            switch formatID {
                            case kAudioFormatLinearPCM:
                                format = "Linear PCM"
                            case kAudioFormatMPEG4AAC:
                                format = "AAC"
                            case kAudioFormatMPEGLayer3:
                                format = "MP3"
                            case kAudioFormatAppleLossless:
                                format = "Apple Lossless"
                            case kAudioFormatFLAC:
                                format = "FLAC"
                            default:
                                format = String(describing: formatID)
                            }
                        }
                    }
                }
                
                // Get file size
                let fileSize = getFileSize(url: url)
                
                // Update UI on main queue
                await MainActor.run {
                    self.hideLoading()
                    
                    // Show file info
                    self.showFileInfo(
                        name: originalURL?.lastPathComponent ?? url.lastPathComponent,
                        size: fileSize,
                        duration: durationSeconds,
                        format: format
                    )
                    
                    // Save to recent downloads
                    let downloadedAudio = SiivDownloadedAudio(
                        id: UUID().uuidString,
                        name: originalURL?.lastPathComponent ?? url.lastPathComponent,
                        url: self.downloadURL?.absoluteString ?? "",
                        downloadDate: Date(),
                        fileSize: fileSize,
                        duration: durationSeconds
                    )
                    
                    self.recentDownloads.insert(downloadedAudio, at: 0)
                    self.updateRecentDownloadsUI()
                    
                    // Notify delegate
                    self.delegate?.downloadFromURLDidFinish(url, name: url.lastPathComponent)
                }
                
            } catch {
                await MainActor.run {
                    self.hideLoading()
                    self.showError("Failed to analyze audio file: \(error.localizedDescription)")
                }
            }
        }
    }
    
    private func getFileSize(url: URL) -> String {
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            if let fileSize = attributes[.size] as? Int64 {
                return ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file)
            }
        } catch {
            print("Error getting file size: \(error)")
        }
        return "Unknown"
    }
    
    private func showFileInfo(name: String, size: String, duration: TimeInterval, format: String) {
        fileInfoView.isHidden = false
        
        fileNameLabel.text = name
        fileSizeLabel.text = "Size: \(size)"
        fileDurationLabel.text = "Duration: \(formatDuration(duration))"
        fileFormatLabel.text = "Format: \(format)"
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        
        if minutes > 0 {
            return "\(minutes)m \(seconds)s"
        } else {
            return "\(seconds)s"
        }
    }
    
    // MARK: - Loading State
    private func showLoading(message: String) {
        isAnalyzing = true
        loadingLabel.text = message
        loadingOverlayView.isHidden = false
        loadingActivityIndicator.startAnimating()
    }
    
    private func hideLoading() {
        isAnalyzing = false
        loadingOverlayView.isHidden = true
        loadingActivityIndicator.stopAnimating()
    }
    
    // MARK: - Actions
    @IBAction func cancelButtonTapped(_ sender: UIButton) {
        if isDownloading {
            cancelDownload()
        }
        delegate?.downloadFromURLDidCancel()
        dismiss(animated: true)
    }
    
    @IBAction func downloadButtonTapped(_ sender: UIButton) {
        startDownload()
    }
    
    @IBAction func cancelDownloadButtonTapped(_ sender: UIButton) {
        cancelDownload()
    }
    
    // MARK: - Helper Methods
    private func showError(_ message: String) {
        let alert = UIAlertController(title: "Error", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
    
    private func ensureDocumentsDirectoryExists() -> URL? {
        guard let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return nil
        }

        // Create the directory if it doesn't exist
        if !FileManager.default.fileExists(atPath: documentsPath.path) {
            do {
                try FileManager.default.createDirectory(at: documentsPath, withIntermediateDirectories: true, attributes: nil)
                print("Created Documents directory at: \(documentsPath.path)")
            } catch {
                print("Failed to create Documents directory: \(error)")
                return nil
            }
        }

        return documentsPath
    }

    private func getFileExtension(from url: URL, originalURL: URL?) -> String {
        // First try to get extension from the original download URL
        if let originalURL = originalURL, !originalURL.pathExtension.isEmpty {
            return originalURL.pathExtension.lowercased()
        }
        
        // Fall back to the temporary file extension
        if !url.pathExtension.isEmpty {
            return url.pathExtension.lowercased()
        }
        
        // Default to mp3 if no extension found
        return "mp3"
    }
}




// MARK: - URLSessionDownloadDelegate
extension SiivDownloadFromURLViewController: URLSessionDownloadDelegate {
    
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        isDownloading = false

        let originalURL = downloadTask.originalRequest?.url
        print("Download completed. Temporary file location: \(location.path)")
        print("Original URL: \(originalURL?.absoluteString ?? "unknown")")
        
        // Validate the temporary file exists and has content
        guard FileManager.default.fileExists(atPath: location.path) else {
            DispatchQueue.main.async {
                self.downloadProgressView.isHidden = true
                self.showError("Downloaded file not found. The file may have been corrupted during download.")
            }
            return
        }

        // Check file size to ensure it's not empty
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: location.path)
            if let fileSize = attributes[.size] as? Int64, fileSize == 0 {
                DispatchQueue.main.async {
                    self.downloadProgressView.isHidden = true
                    self.showError("Downloaded file is empty. Please try downloading again.")
                }
                return
            }
        } catch {
            DispatchQueue.main.async {
                self.downloadProgressView.isHidden = true
                self.showError("Could not verify downloaded file. Please try again.")
            }
            return
        }
    
        // Process the file immediately (no async dispatch)
        self.downloadProgressView.isHidden = true
        self.processDownloadedFile(at: location, originalURL: originalURL)
    }
    
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        let progress = Float(totalBytesWritten) / Float(totalBytesExpectedToWrite)
    
        DispatchQueue.main.async {
            self.downloadProgressBar.setProgress(progress, animated: true)
    
            let percentage = Int(progress * 100)
            self.downloadProgressLabel.text = "Downloading... \(percentage)%"
    
            // Calculate speed
            if let startTime = self.downloadStartTime {
                let elapsed = Date().timeIntervalSince(startTime)
                if elapsed > 0 {
                    let speed = Double(totalBytesWritten) / elapsed
                    self.downloadSpeedLabel.text = "Speed: \(ByteCountFormatter.string(fromByteCount: Int64(speed), countStyle: .file))/s"
    
                    // Calculate time remaining
                    if progress > 0 && speed > 0 {
                        let remainingBytes = totalBytesExpectedToWrite - totalBytesWritten
                        let timeRemaining = Double(remainingBytes) / speed
                        self.downloadTimeRemainingLabel.text = "Time remaining: \(Int(timeRemaining))s"
                    }
                }
            }
        }
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        isDownloading = false
        
        DispatchQueue.main.async {
            self.downloadProgressView.isHidden = true
            
            if let error = error {
                self.showError("Download failed: \(error.localizedDescription)")
            }
        }
    }
}

// MARK: - UITableViewDataSource
extension SiivDownloadFromURLViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return min(recentDownloads.count, 5)
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "SiivRecentDownloadCell", for: indexPath) as! SiivRecentDownloadCell
        let download = recentDownloads[indexPath.row]
        cell.configure(with: download)
        return cell
    }
}

// MARK: - UITableViewDelegate
extension SiivDownloadFromURLViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 70
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        let download = recentDownloads[indexPath.row]
        // TODO: Navigate to audio details or start learning session
        print("Selected recent download: \(download.name)")
    }
}

