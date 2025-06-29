import Foundation

protocol SiivDownloadFromURLDelegate: AnyObject {
    func downloadFromURLDidFinish(_ fileURL: URL, name: String)
    func downloadFromURLDidCancel()
} 
