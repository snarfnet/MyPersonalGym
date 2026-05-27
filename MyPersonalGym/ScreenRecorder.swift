import ReplayKit
import Photos
import UIKit

@Observable
final class ScreenRecorder {
    var isRecording = false
    var recordingDuration: TimeInterval = 0
    var error: String?

    private let recorder = RPScreenRecorder.shared()
    private var startTime: Date?
    private var timer: Timer?

    func startRecording() {
        guard recorder.isAvailable, !isRecording else { return }
        error = nil

        recorder.startRecording { [weak self] err in
            DispatchQueue.main.async {
                if let err {
                    self?.error = err.localizedDescription
                    return
                }
                self?.isRecording = true
                self?.startTime = Date()
                self?.timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
                    if let start = self?.startTime {
                        self?.recordingDuration = Date().timeIntervalSince(start)
                    }
                }
            }
        }
    }

    func stopRecording() {
        guard isRecording else { return }
        timer?.invalidate()
        timer = nil

        recorder.stopRecording { [weak self] previewVC, err in
            DispatchQueue.main.async {
                self?.isRecording = false
                if let err {
                    self?.error = err.localizedDescription
                    return
                }
                // Save directly to camera roll
                self?.saveToPhotos()
            }
        }
    }

    private func saveToPhotos() {
        let outputURL = FileManager.default.temporaryDirectory.appendingPathComponent("gym_\(Int(Date().timeIntervalSince1970)).mp4")

        recorder.stopRecording(withOutput: outputURL) { [weak self] err in
            DispatchQueue.main.async {
                if let err {
                    self?.error = err.localizedDescription
                    return
                }
                PHPhotoLibrary.shared().performChanges {
                    PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: outputURL)
                } completionHandler: { success, err in
                    DispatchQueue.main.async {
                        if !success {
                            self?.error = err?.localizedDescription ?? "Save failed"
                        }
                        try? FileManager.default.removeItem(at: outputURL)
                    }
                }
            }
        }
    }

    func toggleRecording() {
        if isRecording {
            stopAndSave()
        } else {
            startRecording()
        }
    }

    func stopAndSave() {
        guard isRecording else { return }
        timer?.invalidate()
        timer = nil

        let outputURL = FileManager.default.temporaryDirectory.appendingPathComponent("gym_\(Int(Date().timeIntervalSince1970)).mp4")

        recorder.stopRecording(withOutput: outputURL) { [weak self] err in
            DispatchQueue.main.async {
                self?.isRecording = false
                if let err {
                    self?.error = err.localizedDescription
                    return
                }
                PHPhotoLibrary.shared().performChanges {
                    PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: outputURL)
                } completionHandler: { success, err in
                    DispatchQueue.main.async {
                        if !success {
                            self?.error = err?.localizedDescription ?? "Save failed"
                        }
                        try? FileManager.default.removeItem(at: outputURL)
                    }
                }
            }
        }
    }
}
