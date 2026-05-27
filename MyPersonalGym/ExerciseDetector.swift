import Foundation
import Vision

@Observable
final class ExerciseDetector {
    var selectedExercise: Exercise = .squat
    var formScore = FormScore()

    private var lastAngle: Double = 180
    private var repPhase: RepPhase = .up
    private var holdStartTime: Date?

    private enum RepPhase {
        case up, goingDown, down, goingUp
    }

    private let isEnglish = Locale.preferredLanguages.first?.hasPrefix("en") == true

    func analyze(_ pose: BodyPose) {
        let details = PoseAnalyzer.analyze(selectedExercise, pose: pose, isEnglish: isEnglish)

        if selectedExercise.isHold {
            trackHold(pose)
        } else {
            countReps(pose)
        }

        formScore.details = details
        formScore.overall = details.isEmpty ? 0 : details.map(\.score).reduce(0, +) / Double(details.count)
    }

    func reset() {
        formScore = FormScore()
        lastAngle = 180
        repPhase = .up
        holdStartTime = nil
    }

    // MARK: - Rep Counting

    private func countReps(_ pose: BodyPose) {
        let angle: Double?

        switch selectedExercise {
        case .squat, .lunge, .wallSit, .calfRaise:
            let lk = pose.angle(a: .leftHip, b: .leftKnee, c: .leftAnkle)
            let rk = pose.angle(a: .rightHip, b: .rightKnee, c: .rightAnkle)
            if let lk, let rk { angle = (lk + rk) / 2 } else { angle = nil }

        case .pushup:
            let le = pose.angle(a: .leftShoulder, b: .leftElbow, c: .leftWrist)
            let re = pose.angle(a: .rightShoulder, b: .rightElbow, c: .rightWrist)
            if let le, let re { angle = (le + re) / 2 } else { angle = nil }

        case .shoulderPress:
            let le = pose.angle(a: .leftShoulder, b: .leftElbow, c: .leftWrist)
            let re = pose.angle(a: .rightShoulder, b: .rightElbow, c: .rightWrist)
            if let le, let re { angle = (le + re) / 2 } else { angle = nil }

        case .deadlift:
            let lh = pose.angle(a: .leftShoulder, b: .leftHip, c: .leftKnee)
            let rh = pose.angle(a: .rightShoulder, b: .rightHip, c: .rightKnee)
            if let lh, let rh { angle = (lh + rh) / 2 } else { angle = nil }

        case .crunch:
            let la = pose.angle(a: .leftShoulder, b: .leftHip, c: .leftKnee)
            let ra = pose.angle(a: .rightShoulder, b: .rightHip, c: .rightKnee)
            if let la, let ra { angle = (la + ra) / 2 } else { angle = nil }

        case .hipThrust:
            let la = pose.angle(a: .leftShoulder, b: .leftHip, c: .leftKnee)
            let ra = pose.angle(a: .rightShoulder, b: .rightHip, c: .rightKnee)
            if let la, let ra { angle = (la + ra) / 2 } else { angle = nil }

        case .burpee:
            // Use hip height as proxy
            if let hip = pose.midHip, let ankle = pose.midAnkle {
                angle = Double(ankle.y - hip.y) * 500 // scale to angle-like range
            } else { angle = nil }

        case .jumpingJack:
            if let la = pose.point(.leftAnkle), let ra = pose.point(.rightAnkle) {
                angle = Double(abs(la.x - ra.x)) * 500
            } else { angle = nil }

        default:
            angle = nil
        }

        guard let currentAngle = angle else { return }
        updateRepCount(currentAngle: currentAngle, downThreshold: 110, upThreshold: 150)
    }

    private func updateRepCount(currentAngle: Double, downThreshold: Double, upThreshold: Double) {
        switch repPhase {
        case .up:
            if currentAngle < downThreshold {
                repPhase = .goingDown
                formScore.currentPhase = .down
            }
        case .goingDown:
            if currentAngle >= lastAngle {
                repPhase = .down
                formScore.currentPhase = .hold
            }
        case .down:
            if currentAngle > upThreshold {
                repPhase = .goingUp
                formScore.currentPhase = .up
            }
        case .goingUp:
            if currentAngle > upThreshold {
                repPhase = .up
                formScore.repCount += 1
                formScore.currentPhase = .completed
            }
        }
        lastAngle = currentAngle
    }

    private func trackHold(_ pose: BodyPose) {
        let hasBody = pose.point(.leftShoulder) != nil && pose.point(.leftHip) != nil
        if hasBody {
            if holdStartTime == nil { holdStartTime = Date() }
            formScore.holdTime = Date().timeIntervalSince(holdStartTime!)
            formScore.currentPhase = .hold
        } else {
            holdStartTime = nil
            formScore.currentPhase = .idle
        }
    }
}
