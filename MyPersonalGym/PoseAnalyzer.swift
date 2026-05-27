import Foundation
import Vision

enum PoseAnalyzer {

    static func analyze(_ exercise: Exercise, pose: BodyPose, isEnglish: Bool) -> [FormDetail] {
        switch exercise {
        case .squat:         return analyzeSquat(pose, isEnglish: isEnglish)
        case .pushup:        return analyzePushup(pose, isEnglish: isEnglish)
        case .plank:         return analyzePlank(pose, isEnglish: isEnglish)
        case .lunge:         return analyzeLunge(pose, isEnglish: isEnglish)
        case .deadlift:      return analyzeDeadlift(pose, isEnglish: isEnglish)
        case .shoulderPress: return analyzeShoulderPress(pose, isEnglish: isEnglish)
        case .burpee:        return analyzeBurpee(pose, isEnglish: isEnglish)
        case .sidePlank:     return analyzeSidePlank(pose, isEnglish: isEnglish)
        case .crunch:        return analyzeCrunch(pose, isEnglish: isEnglish)
        case .jumpingJack:   return analyzeJumpingJack(pose, isEnglish: isEnglish)
        case .hipThrust:     return analyzeHipThrust(pose, isEnglish: isEnglish)
        case .calfRaise:     return analyzeCalfRaise(pose, isEnglish: isEnglish)
        case .wallSit:       return analyzeWallSit(pose, isEnglish: isEnglish)
        }
    }

    // Use whichever side is available (or average if both)
    private static func bestAngle(_ left: Double?, _ right: Double?) -> Double? {
        if let l = left, let r = right { return (l + r) / 2 }
        return left ?? right
    }

    // MARK: - Squat

    static func analyzeSquat(_ pose: BodyPose, isEnglish: Bool) -> [FormDetail] {
        var details: [FormDetail] = []

        let leftKnee = pose.angle(a: .leftHip, b: .leftKnee, c: .leftAnkle)
        let rightKnee = pose.angle(a: .rightHip, b: .rightKnee, c: .rightAnkle)
        if let avg = bestAngle(leftKnee, rightKnee) {
            let score = depthScore(avg)
            let fb = avg > 160 ? (isEnglish ? "Standing" : "立ち位置")
                : avg > 120 ? (isEnglish ? "Go deeper!" : "もっと深く!")
                : avg < 60 ? (isEnglish ? "Too deep" : "深すぎ")
                : (isEnglish ? "Good depth!" : "良い深さ!")
            details.append(FormDetail(label: isEnglish ? "Knee" : "膝角度", score: score, feedback: "\(Int(avg))° \(fb)"))

            if let lk = leftKnee, let rk = rightKnee {
                let diff = abs(lk - rk)
                let bal = max(0, min(100, (1 - diff / 30) * 100))
                details.append(FormDetail(label: isEnglish ? "Balance" : "左右", score: bal,
                                          feedback: diff < 5 ? (isEnglish ? "Even!" : "均等!") : (isEnglish ? "Uneven" : "ずれ")))
            }
        }

        if let back = backScore(pose, isEnglish: isEnglish) { details.append(back) }
        if let stance = stanceScore(pose, isEnglish: isEnglish) { details.append(stance) }

        return details
    }

    // MARK: - Push-up

    static func analyzePushup(_ pose: BodyPose, isEnglish: Bool) -> [FormDetail] {
        var details: [FormDetail] = []

        let le = pose.angle(a: .leftShoulder, b: .leftElbow, c: .leftWrist)
        let re = pose.angle(a: .rightShoulder, b: .rightElbow, c: .rightWrist)
        if let avg = bestAngle(le, re) {
            let score = depthScore(avg)
            let fb = avg > 160 ? (isEnglish ? "Arms extended" : "腕伸ばし")
                : avg > 120 ? (isEnglish ? "Go lower!" : "もっと下げて!")
                : avg < 60 ? (isEnglish ? "Too low" : "下がりすぎ")
                : (isEnglish ? "Good depth!" : "良い深さ!")
            details.append(FormDetail(label: isEnglish ? "Elbow" : "肘角度", score: score, feedback: "\(Int(avg))° \(fb)"))

            if let le, let re {
                let diff = abs(le - re)
                let bal = max(0, min(100, (1 - diff / 30) * 100))
                details.append(FormDetail(label: isEnglish ? "Arm Bal." : "腕バランス", score: bal,
                                          feedback: diff < 8 ? (isEnglish ? "Even!" : "均等!") : (isEnglish ? "Uneven" : "ずれ")))
            }
        }

        if let body = bodyLineScore(pose, isEnglish: isEnglish) { details.append(body) }

        return details
    }

    // MARK: - Plank

    static func analyzePlank(_ pose: BodyPose, isEnglish: Bool) -> [FormDetail] {
        var details: [FormDetail] = []
        if let body = bodyLineScore(pose, isEnglish: isEnglish) { details.append(body) }
        if let shoulder = shoulderOverWrists(pose, isEnglish: isEnglish) { details.append(shoulder) }
        if let level = levelScore(pose, isEnglish: isEnglish) { details.append(level) }
        return details
    }

    // MARK: - Lunge

    static func analyzeLunge(_ pose: BodyPose, isEnglish: Bool) -> [FormDetail] {
        var details: [FormDetail] = []

        let lk = pose.angle(a: .leftHip, b: .leftKnee, c: .leftAnkle)
        let rk = pose.angle(a: .rightHip, b: .rightKnee, c: .rightAnkle)
        if let avg = bestAngle(lk, rk) {
            let front = avg
            let score = front >= 80 && front <= 100 ? 100.0 : max(0, 100 - abs(front - 90) * 2)
            let fb = front > 120 ? (isEnglish ? "Go lower" : "もっと下げて")
                : front < 70 ? (isEnglish ? "Too deep" : "深すぎ")
                : (isEnglish ? "Good!" : "良い!")
            details.append(FormDetail(label: isEnglish ? "Front Knee" : "前膝", score: score, feedback: "\(Int(front))° \(fb)"))
        }

        if let back = backScore(pose, isEnglish: isEnglish) { details.append(back) }

        return details
    }

    // MARK: - Deadlift

    static func analyzeDeadlift(_ pose: BodyPose, isEnglish: Bool) -> [FormDetail] {
        var details: [FormDetail] = []

        let lHinge = pose.angle(a: .leftShoulder, b: .leftHip, c: .leftKnee)
        let rHinge = pose.angle(a: .rightShoulder, b: .rightHip, c: .rightKnee)
        if let avg = bestAngle(lHinge, rHinge) {
            let score = avg >= 70 && avg <= 120 ? 100.0 : max(0, 100 - abs(avg - 95) * 1.5)
            let fb = avg > 150 ? (isEnglish ? "Standing" : "立ち位置")
                : avg < 60 ? (isEnglish ? "Too low" : "低すぎ")
                : (isEnglish ? "Good hinge!" : "良いヒンジ!")
            details.append(FormDetail(label: isEnglish ? "Hip Hinge" : "ヒップヒンジ", score: score, feedback: "\(Int(avg))° \(fb)"))
        }

        if let back = backScore(pose, isEnglish: isEnglish) { details.append(back) }

        let lk = pose.angle(a: .leftHip, b: .leftKnee, c: .leftAnkle)
        let rk = pose.angle(a: .rightHip, b: .rightKnee, c: .rightAnkle)
        if let avg = bestAngle(lk, rk) {
            let score = avg >= 150 && avg <= 175 ? 100.0 : max(0, 100 - abs(avg - 165) * 2)
            let fb = avg < 140 ? (isEnglish ? "Knees too bent" : "膝曲がりすぎ")
                : avg > 178 ? (isEnglish ? "Don't lock knees" : "膝ロック注意")
                : (isEnglish ? "Good!" : "良い!")
            details.append(FormDetail(label: isEnglish ? "Knee" : "膝", score: score, feedback: fb))
        }

        return details
    }

    // MARK: - Shoulder Press

    static func analyzeShoulderPress(_ pose: BodyPose, isEnglish: Bool) -> [FormDetail] {
        var details: [FormDetail] = []

        let le = pose.angle(a: .leftShoulder, b: .leftElbow, c: .leftWrist)
        let re = pose.angle(a: .rightShoulder, b: .rightElbow, c: .rightWrist)
        if let avg = bestAngle(le, re) {
            let score = avg > 160 ? 100.0 : avg > 130 ? 70.0 : avg > 90 ? 50.0 : 40.0
            let fb = avg > 160 ? (isEnglish ? "Full extension!" : "完全伸展!")
                : avg > 90 ? (isEnglish ? "Push up more" : "もっと上げて")
                : (isEnglish ? "Start position" : "開始位置")
            details.append(FormDetail(label: isEnglish ? "Arms" : "腕伸展", score: score, feedback: "\(Int(avg))° \(fb)"))

            if let le, let re {
                let diff = abs(le - re)
                let bal = max(0, min(100, (1 - diff / 30) * 100))
                details.append(FormDetail(label: isEnglish ? "Balance" : "左右", score: bal,
                                          feedback: diff < 8 ? (isEnglish ? "Even!" : "均等!") : (isEnglish ? "Uneven" : "ずれ")))
            }
        }

        if let back = backScore(pose, isEnglish: isEnglish) { details.append(back) }

        return details
    }

    // MARK: - Burpee

    static func analyzeBurpee(_ pose: BodyPose, isEnglish: Bool) -> [FormDetail] {
        var details: [FormDetail] = []

        if let hip = pose.midHip, let ankle = pose.midAnkle {
            let hipHeight = ankle.y - hip.y
            let phase: String
            let score: Double
            if hipHeight > 0.3 {
                phase = isEnglish ? "Jump/Standing" : "ジャンプ/立ち"
                score = 80
            } else if hipHeight > 0.1 {
                phase = isEnglish ? "Squat phase" : "スクワット"
                score = 90
            } else {
                phase = isEnglish ? "Plank phase" : "プランク"
                score = 85
            }
            details.append(FormDetail(label: isEnglish ? "Phase" : "フェーズ", score: score, feedback: phase))
        }

        if let body = bodyLineScore(pose, isEnglish: isEnglish) { details.append(body) }

        return details
    }

    // MARK: - Side Plank

    static func analyzeSidePlank(_ pose: BodyPose, isEnglish: Bool) -> [FormDetail] {
        var details: [FormDetail] = []

        if let body = bodyLineScore(pose, isEnglish: isEnglish) { details.append(body) }

        if let shoulder = pose.midShoulder, let hip = pose.midHip, let ankle = pose.midAnkle {
            let midY = (shoulder.y + ankle.y) / 2
            let sag = abs(hip.y - midY) / (abs(ankle.y - shoulder.y) + 0.001)
            let score = max(0, min(100, (1 - sag * 4) * 100))
            let fb = score > 80 ? (isEnglish ? "Hips level!" : "腰水平!")
                : hip.y > midY ? (isEnglish ? "Hips sagging" : "腰が落ちてる")
                : (isEnglish ? "Hips too high" : "腰が高すぎ")
            details.append(FormDetail(label: isEnglish ? "Hip" : "腰位置", score: score, feedback: fb))
        }

        return details
    }

    // MARK: - Crunch

    static func analyzeCrunch(_ pose: BodyPose, isEnglish: Bool) -> [FormDetail] {
        var details: [FormDetail] = []

        let lAngle = pose.angle(a: .leftShoulder, b: .leftHip, c: .leftKnee)
        let rAngle = pose.angle(a: .rightShoulder, b: .rightHip, c: .rightKnee)
        if let avg = bestAngle(lAngle, rAngle) {
            let score = avg < 120 ? 100.0 : avg < 140 ? 75.0 : 40.0
            let fb = avg > 150 ? (isEnglish ? "Curl up more" : "もっと起こして")
                : avg < 90 ? (isEnglish ? "Good curl!" : "良いカール!")
                : (isEnglish ? "Keep going" : "もう少し")
            details.append(FormDetail(label: isEnglish ? "Curl" : "カール", score: score, feedback: "\(Int(avg))° \(fb)"))
        }

        return details
    }

    // MARK: - Jumping Jack

    static func analyzeJumpingJack(_ pose: BodyPose, isEnglish: Bool) -> [FormDetail] {
        var details: [FormDetail] = []

        // Arm spread - works with partial data too
        let lw = pose.point(.leftWrist)
        let rw = pose.point(.rightWrist)
        let ls = pose.point(.leftShoulder)
        let rs = pose.point(.rightShoulder)
        if let lw, let rw, (ls != nil || rs != nil) {
            let armSpread = abs(lw.x - rw.x)
            let shoulderW: CGFloat
            if let ls, let rs { shoulderW = abs(ls.x - rs.x) }
            else { shoulderW = 0.15 } // approximate
            let ratio = shoulderW > 0.01 ? armSpread / shoulderW : 1
            let score = ratio > 2.5 ? 100.0 : ratio > 1.5 ? 70.0 : 40.0
            let fb = ratio > 2.5 ? (isEnglish ? "Arms wide!" : "腕開いてる!")
                : (isEnglish ? "Spread arms more" : "もっと腕を広げて")
            details.append(FormDetail(label: isEnglish ? "Arms" : "腕", score: score, feedback: fb))
        }

        if let stance = stanceScore(pose, isEnglish: isEnglish) { details.append(stance) }

        return details
    }

    // MARK: - Hip Thrust

    static func analyzeHipThrust(_ pose: BodyPose, isEnglish: Bool) -> [FormDetail] {
        var details: [FormDetail] = []

        let lAngle = pose.angle(a: .leftShoulder, b: .leftHip, c: .leftKnee)
        let rAngle = pose.angle(a: .rightShoulder, b: .rightHip, c: .rightKnee)
        if let avg = bestAngle(lAngle, rAngle) {
            let score = avg >= 160 ? 100.0 : avg >= 140 ? 80.0 : avg >= 120 ? 60.0 : 40.0
            let fb = avg >= 160 ? (isEnglish ? "Full extension!" : "完全伸展!")
                : (isEnglish ? "Push hips up" : "腰をもっと上げて")
            details.append(FormDetail(label: isEnglish ? "Hip Ext." : "腰伸展", score: score, feedback: "\(Int(avg))° \(fb)"))
        }

        let lk = pose.angle(a: .leftHip, b: .leftKnee, c: .leftAnkle)
        let rk = pose.angle(a: .rightHip, b: .rightKnee, c: .rightAnkle)
        if let avg = bestAngle(lk, rk) {
            let score = avg >= 80 && avg <= 100 ? 100.0 : max(0, 100 - abs(avg - 90) * 2)
            details.append(FormDetail(label: isEnglish ? "Knee" : "膝", score: score, feedback: "\(Int(avg))°"))
        }

        return details
    }

    // MARK: - Calf Raise

    static func analyzeCalfRaise(_ pose: BodyPose, isEnglish: Bool) -> [FormDetail] {
        var details: [FormDetail] = []

        if let ankle = pose.midAnkle, let knee = pose.midKnee {
            let rise = knee.y - ankle.y
            let score = rise > 0.15 ? 100.0 : rise > 0.1 ? 75.0 : 50.0
            let fb = score > 80 ? (isEnglish ? "Good height!" : "良い高さ!")
                : (isEnglish ? "Rise higher" : "もっと上げて")
            details.append(FormDetail(label: isEnglish ? "Rise" : "高さ", score: score, feedback: fb))
        }

        if let back = backScore(pose, isEnglish: isEnglish) { details.append(back) }

        return details
    }

    // MARK: - Wall Sit

    static func analyzeWallSit(_ pose: BodyPose, isEnglish: Bool) -> [FormDetail] {
        var details: [FormDetail] = []

        let lk = pose.angle(a: .leftHip, b: .leftKnee, c: .leftAnkle)
        let rk = pose.angle(a: .rightHip, b: .rightKnee, c: .rightAnkle)
        if let avg = bestAngle(lk, rk) {
            let score = avg >= 80 && avg <= 100 ? 100.0 : max(0, 100 - abs(avg - 90) * 2)
            let fb = avg > 120 ? (isEnglish ? "Go lower" : "もっと下げて")
                : avg < 70 ? (isEnglish ? "Too low" : "低すぎ")
                : (isEnglish ? "Perfect 90°!" : "完璧な90°!")
            details.append(FormDetail(label: isEnglish ? "Knee" : "膝角度", score: score, feedback: "\(Int(avg))° \(fb)"))
        }

        if let back = backScore(pose, isEnglish: isEnglish) { details.append(back) }

        return details
    }

    // MARK: - Shared Helpers

    private static func depthScore(_ angle: Double) -> Double {
        if angle > 150 { return 40 }
        if angle > 120 { return 55 }
        if angle > 100 { return 75 }
        if angle >= 70 { return 100 }
        if angle >= 50 { return 80 }
        return 60
    }

    static func backScore(_ pose: BodyPose, isEnglish: Bool) -> FormDetail? {
        // Try midpoints first, fallback to single side
        let shoulderPt: CGPoint?
        let hipPt: CGPoint?
        if let ms = pose.midShoulder { shoulderPt = ms }
        else { shoulderPt = pose.point(.leftShoulder) ?? pose.point(.rightShoulder) }
        if let mh = pose.midHip { hipPt = mh }
        else { hipPt = pose.point(.leftHip) ?? pose.point(.rightHip) }

        guard let shoulder = shoulderPt, let hip = hipPt else { return nil }
        let dx = abs(shoulder.x - hip.x)
        let dy = abs(shoulder.y - hip.y) + 0.001
        let lean = dx / dy
        let score = max(0, min(100, (1 - lean * 3) * 100))
        let fb = lean < 0.1 ? (isEnglish ? "Back straight!" : "背筋OK!")
            : shoulder.x < hip.x ? (isEnglish ? "Leaning forward" : "前傾")
            : (isEnglish ? "Leaning back" : "後傾")
        return FormDetail(label: isEnglish ? "Back" : "背中", score: score, feedback: fb)
    }

    static func stanceScore(_ pose: BodyPose, isEnglish: Bool) -> FormDetail? {
        let la = pose.point(.leftAnkle)
        let ra = pose.point(.rightAnkle)
        let ls = pose.point(.leftShoulder)
        let rs = pose.point(.rightShoulder)
        guard let la, let ra, (ls != nil || rs != nil) else { return nil }
        let feet = abs(la.x - ra.x)
        let shoulders: CGFloat
        if let ls, let rs { shoulders = abs(ls.x - rs.x) }
        else { shoulders = 0.15 }
        let ratio = shoulders > 0.01 ? feet / shoulders : 1
        let score = max(0, min(100, (1 - abs(ratio - 1) * 2) * 100))
        let fb = ratio < 0.7 ? (isEnglish ? "Wider" : "もっと広く")
            : ratio > 1.5 ? (isEnglish ? "Narrower" : "狭めて")
            : (isEnglish ? "Good!" : "良い!")
        return FormDetail(label: isEnglish ? "Stance" : "スタンス", score: score, feedback: fb)
    }

    static func bodyLineScore(_ pose: BodyPose, isEnglish: Bool) -> FormDetail? {
        let shoulderPt = pose.midShoulder ?? pose.point(.leftShoulder) ?? pose.point(.rightShoulder)
        let hipPt = pose.midHip ?? pose.point(.leftHip) ?? pose.point(.rightHip)
        let anklePt = pose.midAnkle ?? pose.point(.leftAnkle) ?? pose.point(.rightAnkle)
        guard let shoulder = shoulderPt, let hip = hipPt, let ankle = anklePt else { return nil }
        let midY = (shoulder.y + ankle.y) / 2
        let deviation = abs(hip.y - midY) / (abs(ankle.y - shoulder.y) + 0.001)
        let score = Double(max(0, min(100, (1 - deviation * 4) * 100)))
        let hipHigh = hip.y < midY
        let fb = score > 80 ? (isEnglish ? "Body straight!" : "体まっすぐ!")
            : hipHigh ? (isEnglish ? "Lower hips" : "腰を下げて")
            : (isEnglish ? "Raise hips" : "腰を上げて")
        return FormDetail(label: isEnglish ? "Body Line" : "体ライン", score: score, feedback: fb)
    }

    static func shoulderOverWrists(_ pose: BodyPose, isEnglish: Bool) -> FormDetail? {
        let ls = pose.point(.leftShoulder)
        let lw = pose.point(.leftWrist)
        let rs = pose.point(.rightShoulder)
        let rw = pose.point(.rightWrist)
        // Need at least one shoulder and one wrist
        guard let sPt = ls ?? rs, let wPt = lw ?? rw else { return nil }
        let sMidX: CGFloat
        let wMidX: CGFloat
        if let ls, let rs { sMidX = (ls.x + rs.x) / 2 } else { sMidX = sPt.x }
        if let lw, let rw { wMidX = (lw.x + rw.x) / 2 } else { wMidX = wPt.x }
        let offset = abs(sMidX - wMidX)
        let score = max(0, min(100, (1 - offset * 5) * 100))
        let fb = offset < 0.05 ? (isEnglish ? "Aligned!" : "OK!")
            : sMidX < wMidX ? (isEnglish ? "Shift forward" : "前へ")
            : (isEnglish ? "Shift back" : "後ろへ")
        return FormDetail(label: isEnglish ? "Shoulder" : "肩位置", score: score, feedback: fb)
    }

    static func levelScore(_ pose: BodyPose, isEnglish: Bool) -> FormDetail? {
        guard let ls = pose.point(.leftShoulder), let rs = pose.point(.rightShoulder),
              let lh = pose.point(.leftHip), let rh = pose.point(.rightHip) else { return nil }
        let diff = abs((ls.y - lh.y) - (rs.y - rh.y))
        let score = max(0, min(100, (1 - diff * 10) * 100))
        let fb = diff < 0.03 ? (isEnglish ? "Level!" : "水平!") : (isEnglish ? "Tilting" : "傾き")
        return FormDetail(label: isEnglish ? "Level" : "水平", score: score, feedback: fb)
    }
}
