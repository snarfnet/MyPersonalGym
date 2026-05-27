import Foundation
import Vision

@Observable
final class ExerciseDetector {
    var selectedExercise: Exercise = .squat
    var formScore = FormScore()

    // Rep counting state
    private var lastAngle: Double = 180
    private var repPhase: RepPhase = .up
    private var plankStartTime: Date?

    private enum RepPhase {
        case up, goingDown, down, goingUp
    }

    private let isEnglish = Locale.preferredLanguages.first?.hasPrefix("en") == true

    func analyze(_ pose: BodyPose) {
        let details: [FormDetail]

        switch selectedExercise {
        case .squat:
            details = PoseAnalyzer.analyzeSquat(pose, isEnglish: isEnglish)
            countSquatReps(pose)
        case .pushup:
            details = PoseAnalyzer.analyzePushup(pose, isEnglish: isEnglish)
            countPushupReps(pose)
        case .plank:
            details = PoseAnalyzer.analyzePlank(pose, isEnglish: isEnglish)
            trackPlankHold(pose)
        }

        let overall = details.isEmpty ? 0 : details.map(\.score).reduce(0, +) / Double(details.count)

        formScore.details = details
        formScore.overall = overall
    }

    func reset() {
        formScore = FormScore()
        lastAngle = 180
        repPhase = .up
        plankStartTime = nil
    }

    // MARK: - Rep Counting

    private func countSquatReps(_ pose: BodyPose) {
        let leftKnee = pose.angle(a: .leftHip, b: .leftKnee, c: .leftAnkle)
        let rightKnee = pose.angle(a: .rightHip, b: .rightKnee, c: .rightAnkle)
        guard let lk = leftKnee, let rk = rightKnee else { return }
        let kneeAngle = (lk + rk) / 2
        updateRepCount(currentAngle: kneeAngle, downThreshold: 110, upThreshold: 150)
    }

    private func countPushupReps(_ pose: BodyPose) {
        let leftElbow = pose.angle(a: .leftShoulder, b: .leftElbow, c: .leftWrist)
        let rightElbow = pose.angle(a: .rightShoulder, b: .rightElbow, c: .rightWrist)
        guard let le = leftElbow, let re = rightElbow else { return }
        let elbowAngle = (le + re) / 2
        updateRepCount(currentAngle: elbowAngle, downThreshold: 110, upThreshold: 150)
    }

    private func updateRepCount(currentAngle: Double, downThreshold: Double, upThreshold: Double) {
        switch repPhase {
        case .up:
            if currentAngle < downThreshold {
                repPhase = .goingDown
                formScore.currentPhase = .down
            }
        case .goingDown:
            if currentAngle < lastAngle {
                // Still going down
            } else {
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

    private func trackPlankHold(_ pose: BodyPose) {
        let hasBody = pose.point(.leftShoulder) != nil && pose.point(.leftHip) != nil
        if hasBody {
            if plankStartTime == nil {
                plankStartTime = Date()
            }
            formScore.holdTime = Date().timeIntervalSince(plankStartTime!)
            formScore.currentPhase = .hold
        } else {
            plankStartTime = nil
            formScore.currentPhase = .idle
        }
    }
}
