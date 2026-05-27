import Foundation
import Vision

enum Exercise: String, CaseIterable, Identifiable {
    case squat = "squat"
    case pushup = "pushup"
    case plank = "plank"
    case lunge = "lunge"
    case deadlift = "deadlift"
    case shoulderPress = "shoulderPress"
    case burpee = "burpee"
    case sidePlank = "sidePlank"
    case crunch = "crunch"
    case jumpingJack = "jumpingJack"
    case hipThrust = "hipThrust"
    case calfRaise = "calfRaise"
    case wallSit = "wallSit"

    var id: String { rawValue }

    var name: String {
        let en = Locale.preferredLanguages.first?.hasPrefix("en") == true
        switch self {
        case .squat:         return en ? "Squat" : "スクワット"
        case .pushup:        return en ? "Push-Up" : "プッシュアップ"
        case .plank:         return en ? "Plank" : "プランク"
        case .lunge:         return en ? "Lunge" : "ランジ"
        case .deadlift:      return en ? "Deadlift" : "デッドリフト"
        case .shoulderPress: return en ? "Shoulder Press" : "ショルダープレス"
        case .burpee:        return en ? "Burpee" : "バーピー"
        case .sidePlank:     return en ? "Side Plank" : "サイドプランク"
        case .crunch:        return en ? "Crunch" : "クランチ"
        case .jumpingJack:   return en ? "Jumping Jack" : "ジャンピングジャック"
        case .hipThrust:     return en ? "Hip Thrust" : "ヒップスラスト"
        case .calfRaise:     return en ? "Calf Raise" : "カーフレイズ"
        case .wallSit:       return en ? "Wall Sit" : "ウォールシット"
        }
    }

    var icon: String {
        switch self {
        case .squat:         return "figure.strengthtraining.traditional"
        case .pushup:        return "figure.core.training"
        case .plank:         return "figure.yoga"
        case .lunge:         return "figure.walk"
        case .deadlift:      return "figure.strengthtraining.functional"
        case .shoulderPress: return "figure.arms.open"
        case .burpee:        return "figure.jumprope"
        case .sidePlank:     return "figure.pilates"
        case .crunch:        return "figure.core.training"
        case .jumpingJack:   return "figure.jumprope"
        case .hipThrust:     return "figure.flexibility"
        case .calfRaise:     return "figure.step.training"
        case .wallSit:       return "figure.stand"
        }
    }

    var isHold: Bool {
        switch self {
        case .plank, .sidePlank, .wallSit: return true
        default: return false
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
    case down
    case hold
    case up
    case completed
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

    var midShoulder: CGPoint? {
        guard let ls = point(.leftShoulder), let rs = point(.rightShoulder) else { return nil }
        return CGPoint(x: (ls.x + rs.x) / 2, y: (ls.y + rs.y) / 2)
    }

    var midHip: CGPoint? {
        guard let lh = point(.leftHip), let rh = point(.rightHip) else { return nil }
        return CGPoint(x: (lh.x + rh.x) / 2, y: (lh.y + rh.y) / 2)
    }

    var midAnkle: CGPoint? {
        guard let la = point(.leftAnkle), let ra = point(.rightAnkle) else { return nil }
        return CGPoint(x: (la.x + ra.x) / 2, y: (la.y + ra.y) / 2)
    }

    var midKnee: CGPoint? {
        guard let lk = point(.leftKnee), let rk = point(.rightKnee) else { return nil }
        return CGPoint(x: (lk.x + rk.x) / 2, y: (lk.y + rk.y) / 2)
    }
}
