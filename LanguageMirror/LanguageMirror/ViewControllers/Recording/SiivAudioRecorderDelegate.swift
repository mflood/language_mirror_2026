import Foundation

protocol SiivAudioRecorderDelegate: AnyObject {
    /// Called when audio recording is completed successfully
    /// - Parameters:
    ///   - recordingURL: The URL of the recorded audio file
    ///   - name: The name of the recording
    func audioRecorderDidFinish(_ recordingURL: URL, name: String)
    
    /// Called when the user cancels the recording process
    func audioRecorderDidCancel()
    
    /// Called when a recording operation fails
    /// - Parameter error: The error that occurred during recording
    func audioRecorderDidFail(_ error: Error)
}

// MARK: - Default Implementation
extension SiivAudioRecorderDelegate {
    func audioRecorderDidFinish(_ recordingURL: URL, name: String) {
        // Default implementation does nothing
    }
    
    func audioRecorderDidCancel() {
        // Default implementation does nothing
    }
    
    func audioRecorderDidFail(_ error: Error) {
        // Default implementation does nothing
    }
} 
