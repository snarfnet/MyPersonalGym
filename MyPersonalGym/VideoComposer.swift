import AVFoundation
import UIKit
import Photos
import Vision

@Observable
final class VideoComposer {
    var isRecording = false
    var recordingDuration: TimeInterval = 0
    var savedMessage: String?

    private var assetWriter: AVAssetWriter?
    private var videoInput: AVAssetWriterInput?
    private var adaptor: AVAssetWriterInputPixelBufferAdaptor?
    private var startTime: CMTime?
    private var frameCount: Int = 0
    private var timer: Timer?
    private var recordStart: Date?

    // Output size: landscape-ish, report left + camera right
    private let outputWidth = 1920
    private let outputHeight = 1080

    private let isEnglish = Locale.preferredLanguages.first?.hasPrefix("en") == true

    func startRecording() {
        guard !isRecording else { return }

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("gym_\(Int(Date().timeIntervalSince1970)).mp4")

        guard let writer = try? AVAssetWriter(outputURL: url, fileType: .mp4) else { return }

        let settings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: outputWidth,
            AVVideoHeightKey: outputHeight,
            AVVideoCompressionPropertiesKey: [
                AVVideoAverageBitRateKey: 5_000_000,
                AVVideoMaxKeyFrameIntervalKey: 30,
            ]
        ]

        let input = AVAssetWriterInput(mediaType: .video, outputSettings: settings)
        input.expectsMediaDataInRealTime = true

        let attrs: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey as String: outputWidth,
            kCVPixelBufferHeightKey as String: outputHeight,
        ]
        let adapt = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: attrs)

        writer.add(input)
        writer.startWriting()
        writer.startSession(atSourceTime: .zero)

        assetWriter = writer
        videoInput = input
        adaptor = adapt
        startTime = nil
        frameCount = 0
        isRecording = true
        recordStart = Date()

        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            if let start = self?.recordStart {
                self?.recordingDuration = Date().timeIntervalSince(start)
            }
        }
    }

    func appendFrame(cameraImage: UIImage, pose: BodyPose?, exercise: Exercise, score: FormScore, timestamp: CMTime) {
        guard isRecording, let input = videoInput, let adapt = adaptor, input.isReadyForMoreMediaData else { return }

        if startTime == nil { startTime = timestamp }
        let presentationTime = CMTimeSubtract(timestamp, startTime!)

        let composed = composeFrame(camera: cameraImage, pose: pose, exercise: exercise, score: score)
        guard let pixelBuffer = pixelBufferFrom(image: composed) else { return }

        adapt.append(pixelBuffer, withPresentationTime: presentationTime)
        frameCount += 1
    }

    func stopRecording() {
        guard isRecording else { return }
        isRecording = false
        timer?.invalidate()
        timer = nil

        guard let writer = assetWriter else { return }
        videoInput?.markAsFinished()

        let url = writer.outputURL
        writer.finishWriting { [weak self] in
            guard writer.status == .completed else {
                DispatchQueue.main.async {
                    self?.savedMessage = "Recording failed"
                }
                return
            }
            PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: url)
            } completionHandler: { success, _ in
                DispatchQueue.main.async {
                    self?.savedMessage = success
                        ? (self?.isEnglish == true ? "Saved to Photos" : "写真に保存しました")
                        : "Save failed"
                }
                try? FileManager.default.removeItem(at: url)
            }
        }
    }

    // MARK: - Frame Composition

    private func composeFrame(camera: UIImage, pose: BodyPose?, exercise: Exercise, score: FormScore) -> UIImage {
        let size = CGSize(width: outputWidth, height: outputHeight)
        let reportW = CGFloat(outputWidth) * 0.55
        let cameraW = CGFloat(outputWidth) - reportW
        let h = CGFloat(outputHeight)

        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            let gc = ctx.cgContext

            // --- Left: Report panel ---
            gc.setFillColor(UIColor(red: 0.04, green: 0.04, blue: 0.08, alpha: 1).cgColor)
            gc.fill(CGRect(x: 0, y: 0, width: reportW, height: h))

            drawReport(gc: gc, exercise: exercise, score: score, width: reportW, height: h)

            // --- Right: Camera + skeleton ---
            let cameraRect = CGRect(x: reportW, y: 0, width: cameraW, height: h)

            // Draw camera image scaled to fill
            let imgRatio = camera.size.width / camera.size.height
            let rectRatio = cameraW / h
            var drawRect: CGRect
            if imgRatio > rectRatio {
                let drawH = h
                let drawW = drawH * imgRatio
                drawRect = CGRect(x: reportW + (cameraW - drawW) / 2, y: 0, width: drawW, height: drawH)
            } else {
                let drawW = cameraW
                let drawH = drawW / imgRatio
                drawRect = CGRect(x: reportW, y: (h - drawH) / 2, width: drawW, height: drawH)
            }

            gc.saveGState()
            gc.clip(to: cameraRect)
            camera.draw(in: drawRect)
            gc.restoreGState()

            // Draw skeleton overlay
            if let pose = pose {
                drawSkeleton(gc: gc, pose: pose, rect: cameraRect)
            }

            // Divider line
            gc.setStrokeColor(UIColor.orange.withAlphaComponent(0.5).cgColor)
            gc.setLineWidth(2)
            gc.move(to: CGPoint(x: reportW, y: 0))
            gc.addLine(to: CGPoint(x: reportW, y: h))
            gc.strokePath()
        }
    }

    private func drawReport(gc: CGContext, exercise: Exercise, score: FormScore, width: CGFloat, height: CGFloat) {
        let pad: CGFloat = 30
        var y: CGFloat = 30

        // Title
        let titleFont = UIFont.monospacedSystemFont(ofSize: 28, weight: .bold)
        draw("MY PERSONAL GYM", at: CGPoint(x: pad, y: y), font: titleFont, color: .orange, gc: gc)
        y += 40

        let subFont = UIFont.monospacedSystemFont(ofSize: 16, weight: .medium)
        draw(isEnglish ? "AI Form Checker" : "AIフォームチェッカー", at: CGPoint(x: pad, y: y), font: subFont, color: UIColor.orange.withAlphaComponent(0.5), gc: gc)
        y += 30

        drawDivider(gc: gc, y: y, x1: pad, x2: width - pad)
        y += 16

        // Exercise name
        let exFont = UIFont.monospacedSystemFont(ofSize: 36, weight: .black)
        draw(exercise.name.uppercased(), at: CGPoint(x: pad, y: y), font: exFont, color: .white, gc: gc)
        y += 50

        // Rep count or hold time
        let repFont = UIFont.monospacedSystemFont(ofSize: 48, weight: .black)
        if exercise.isHold {
            let mins = Int(score.holdTime) / 60
            let secs = Int(score.holdTime) % 60
            draw(String(format: "%d:%02d", mins, secs), at: CGPoint(x: pad, y: y), font: repFont, color: .orange, gc: gc)
            let holdLabel = UIFont.monospacedSystemFont(ofSize: 20, weight: .medium)
            draw(isEnglish ? "HOLD TIME" : "ホールド時間", at: CGPoint(x: pad + 160, y: y + 20), font: holdLabel, color: UIColor.orange.withAlphaComponent(0.6), gc: gc)
        } else {
            draw("\(score.repCount)", at: CGPoint(x: pad, y: y), font: repFont, color: .orange, gc: gc)
            let repLabel = UIFont.monospacedSystemFont(ofSize: 20, weight: .medium)
            draw("REPS", at: CGPoint(x: pad + 80, y: y + 20), font: repLabel, color: UIColor.orange.withAlphaComponent(0.6), gc: gc)
        }
        y += 70

        // Overall score
        let gradeFont = UIFont.monospacedSystemFont(ofSize: 72, weight: .black)
        let grade = gradeFor(score.overall)
        let gradeColor = colorForScore(score.overall)
        draw(grade, at: CGPoint(x: pad, y: y), font: gradeFont, color: gradeColor, gc: gc)

        let scoreFont = UIFont.monospacedSystemFont(ofSize: 48, weight: .black)
        let gradeSize = (grade as NSString).size(withAttributes: [.font: gradeFont])
        draw(String(format: "%.0f%%", score.overall), at: CGPoint(x: pad + gradeSize.width + 12, y: y + 18), font: scoreFont, color: gradeColor, gc: gc)
        y += 90

        drawDivider(gc: gc, y: y, x1: pad, x2: width - pad)
        y += 16

        // Detail rows
        let labelFont = UIFont.monospacedSystemFont(ofSize: 22, weight: .bold)
        let valueFont = UIFont.monospacedSystemFont(ofSize: 26, weight: .black)
        let feedbackFont = UIFont.monospacedSystemFont(ofSize: 20, weight: .medium)
        let barHeight: CGFloat = 8

        let maxDetails = min(score.details.count, 5)
        let remainingH = height - y - 30
        let rowH = remainingH / CGFloat(max(maxDetails, 1))

        for i in 0..<maxDetails {
            let detail = score.details[i]
            let dColor = colorForScore(detail.score)

            // Label
            draw(detail.label, at: CGPoint(x: pad, y: y), font: labelFont, color: dColor.withAlphaComponent(0.9), gc: gc)

            // Score on right
            let valText = String(format: "%.0f%%", detail.score)
            let valSize = (valText as NSString).size(withAttributes: [.font: valueFont])
            draw(valText, at: CGPoint(x: width - pad - valSize.width, y: y), font: valueFont, color: dColor, gc: gc)

            // Bar
            let barY = y + 30
            let barW = width - pad * 2
            gc.setFillColor(UIColor.white.withAlphaComponent(0.1).cgColor)
            gc.fill(CGRect(x: pad, y: barY, width: barW, height: barHeight))
            gc.setFillColor(dColor.cgColor)
            gc.fill(CGRect(x: pad, y: barY, width: barW * min(CGFloat(detail.score) / 100, 1), height: barHeight))

            // Feedback
            draw(detail.feedback, at: CGPoint(x: pad, y: barY + barHeight + 6), font: feedbackFont, color: dColor.withAlphaComponent(0.7), gc: gc)

            y += rowH
        }
    }

    private func drawSkeleton(gc: CGContext, pose: BodyPose, rect: CGRect) {
        let connections: [(VNHumanBodyPoseObservation.JointName, VNHumanBodyPoseObservation.JointName)] = [
            (.leftShoulder, .rightShoulder),
            (.leftShoulder, .leftHip), (.rightShoulder, .rightHip),
            (.leftHip, .rightHip),
            (.leftShoulder, .leftElbow), (.leftElbow, .leftWrist),
            (.rightShoulder, .rightElbow), (.rightElbow, .rightWrist),
            (.leftHip, .leftKnee), (.leftKnee, .leftAnkle),
            (.rightHip, .rightKnee), (.rightKnee, .rightAnkle),
            (.nose, .neck), (.neck, .leftShoulder), (.neck, .rightShoulder),
        ]

        // Bones
        gc.setStrokeColor(UIColor.orange.withAlphaComponent(0.8).cgColor)
        gc.setLineWidth(4)

        for (from, to) in connections {
            guard let p1 = pose.point(from), let p2 = pose.point(to) else { continue }
            let sp1 = CGPoint(x: rect.minX + p1.x * rect.width, y: rect.minY + p1.y * rect.height)
            let sp2 = CGPoint(x: rect.minX + p2.x * rect.width, y: rect.minY + p2.y * rect.height)
            gc.move(to: sp1)
            gc.addLine(to: sp2)
        }
        gc.strokePath()

        // Joints
        for (_, point) in pose.joints {
            let sp = CGPoint(x: rect.minX + point.x * rect.width, y: rect.minY + point.y * rect.height)
            gc.setFillColor(UIColor.orange.cgColor)
            gc.fillEllipse(in: CGRect(x: sp.x - 6, y: sp.y - 6, width: 12, height: 12))
            gc.setStrokeColor(UIColor.white.cgColor)
            gc.setLineWidth(2)
            gc.strokeEllipse(in: CGRect(x: sp.x - 6, y: sp.y - 6, width: 12, height: 12))
        }
    }

    // MARK: - Pixel Buffer

    private func pixelBufferFrom(image: UIImage) -> CVPixelBuffer? {
        guard let cgImage = image.cgImage else { return nil }

        var buffer: CVPixelBuffer?
        let attrs: [String: Any] = [
            kCVPixelBufferCGImageCompatibilityKey as String: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey as String: true,
        ]

        let status = CVPixelBufferCreate(kCFAllocatorDefault, outputWidth, outputHeight,
                                          kCVPixelFormatType_32BGRA, attrs as CFDictionary, &buffer)
        guard status == kCVReturnSuccess, let pb = buffer else { return nil }

        CVPixelBufferLockBaseAddress(pb, [])
        let context = CGContext(
            data: CVPixelBufferGetBaseAddress(pb),
            width: outputWidth, height: outputHeight,
            bitsPerComponent: 8,
            bytesPerRow: CVPixelBufferGetBytesPerRow(pb),
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
        )
        context?.draw(cgImage, in: CGRect(x: 0, y: 0, width: outputWidth, height: outputHeight))
        CVPixelBufferUnlockBaseAddress(pb, [])

        return pb
    }

    // MARK: - Drawing Helpers

    private func draw(_ text: String, at point: CGPoint, font: UIFont, color: UIColor, gc: CGContext) {
        let attr: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color]
        (text as NSString).draw(at: point, withAttributes: attr)
    }

    private func drawDivider(gc: CGContext, y: CGFloat, x1: CGFloat, x2: CGFloat) {
        gc.setStrokeColor(UIColor.orange.withAlphaComponent(0.3).cgColor)
        gc.setLineWidth(1)
        gc.move(to: CGPoint(x: x1, y: y))
        gc.addLine(to: CGPoint(x: x2, y: y))
        gc.strokePath()
    }

    private func gradeFor(_ score: Double) -> String {
        switch score {
        case 90...: return "S"
        case 80..<90: return "A"
        case 70..<80: return "B"
        case 60..<70: return "C"
        default: return "D"
        }
    }

    private func colorForScore(_ score: Double) -> UIColor {
        switch score {
        case 90...: return UIColor(red: 0.3, green: 1, blue: 0.5, alpha: 1)
        case 80..<90: return UIColor(red: 0.5, green: 1, blue: 0.8, alpha: 1)
        case 70..<80: return .yellow
        case 60..<70: return .orange
        default: return UIColor(red: 1, green: 0.4, blue: 0.4, alpha: 1)
        }
    }
}
