import Foundation
import Vision

enum Exercise: String, CaseIterable, Identifiable {
    case squat = "squat"
    case pushup = "pushup"
    case plank = "plank"

    var id: String { rawValue }

    var name: String {
        let isEnglish = Locale.preferredLanguages.first?.hasPrefix("en") == true
        switch self {
        case .squat:  return isEnglish ? "Squat" : "スクワット"
        case .pushup: return isEnglish ? "Push-Up" : "プッシュアップ"
        case .plank:  return isEnglish ? "Plank" : "プランク"
        }
    }

    var icon: String {
        switch self {
        case .squat:  return "figure.strengthtraining.traditional"
        case .pushup: return "figure.core.training"
        case .plank:  return "figure.yoga"
        }
    }
}

struct FormScore {
    var overall: Double = 0
    var details: [FormDetail] = []
    var repCount: Int = 0
    var holdTime: TimeInterval = 0
    var currentPhase: ExercisePhase = .idle
}

struct FormDetail {
    let label: String
    let score: Double
    let feedback: String
}

enum ExercisePhase {
    case idle
    case down      // squat: going down, pushup: going down
    case hold      // plank hold, bottom of squat/pushup
    case up        // returning to start
    case completed // rep completed
}

struct BodyPose {
    var joints: [VNHumanBodyPoseObservation.JointName: CGPoint] = [:]

    func point(_ joint: VNHumanBodyPoseObservation.JointName) -> CGPoint? {
        joints[joint]
    }

    func angle(a: VNHumanBodyPoseObservation.JointName,
               b: VNHumanBodyPoseObservation.JointName,
               c: VNHumanBodyPoseObservation.JointName) -> Double? {
        guard let pA = joints[a], let pB = joints[b], let pC = joints[c] else { return nil }
        let v1 = CGVector(dx: pA.x - pB.x, dy: pA.y - pB.y)
        let v2 = CGVector(dx: pC.x - pB.x, dy: pC.y - pB.y)
        let dot = v1.dx * v2.dx + v1.dy * v2.dy
        let mag1 = sqrt(v1.dx * v1.dx + v1.dy * v1.dy)
        let mag2 = sqrt(v2.dx * v2.dx + v2.dy * v2.dy)
        guard mag1 > 0, mag2 > 0 else { return nil }
        let cosAngle = max(-1, min(1, dot / (mag1 * mag2)))
        return acos(cosAngle) * 180 / Double.pi
    }
}
