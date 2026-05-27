import Foundation
import Vision

enum PoseAnalyzer {

    // MARK: - Squat Analysis

    static func analyzeSquat(_ pose: BodyPose, isEnglish: Bool) -> [FormDetail] {
        var details: [FormDetail] = []

        // 1. Knee angle (hip-knee-ankle) — target: 70-100° at bottom
        let leftKneeAngle = pose.angle(a: .leftHip, b: .leftKnee, c: .leftAnkle)
        let rightKneeAngle = pose.angle(a: .rightHip, b: .rightKnee, c: .rightAnkle)
        if let lk = leftKneeAngle, let rk = rightKneeAngle {
            let avgKnee = (lk + rk) / 2
            let kneeScore = kneeAngleScore(avgKnee)
            let feedback: String
            if avgKnee > 160 {
                feedback = isEnglish ? "Stand up position" : "立ち位置"
            } else if avgKnee > 120 {
                feedback = isEnglish ? "Go deeper!" : "もっと深く!"
            } else if avgKnee < 60 {
                feedback = isEnglish ? "Too deep" : "深すぎ"
            } else {
                feedback = isEnglish ? "Good depth!" : "良い深さ!"
            }
            details.append(FormDetail(
                label: isEnglish ? "Knee Angle" : "膝角度",
                score: kneeScore,
                feedback: "\(Int(avgKnee))° \(feedback)"
            ))
        }

        // 2. Back straightness (shoulder-hip vertical alignment)
        if let ls = pose.point(.leftShoulder), let lh = pose.point(.leftHip),
           let rs = pose.point(.rightShoulder), let rh = pose.point(.rightHip) {
            let shoulderMid = CGPoint(x: (ls.x + rs.x) / 2, y: (ls.y + rs.y) / 2)
            let hipMid = CGPoint(x: (lh.x + rh.x) / 2, y: (lh.y + rh.y) / 2)
            let dx = abs(shoulderMid.x - hipMid.x)
            let dy = abs(shoulderMid.y - hipMid.y) + 0.001
            let lean = dx / dy
            let backScore = max(0, min(100, (1 - lean * 3) * 100))
            let feedback: String
            if lean < 0.1 {
                feedback = isEnglish ? "Back straight!" : "背筋まっすぐ!"
            } else if shoulderMid.x < hipMid.x {
                feedback = isEnglish ? "Leaning forward" : "前傾しすぎ"
            } else {
                feedback = isEnglish ? "Leaning back" : "後傾しすぎ"
            }
            details.append(FormDetail(
                label: isEnglish ? "Back" : "背中",
                score: backScore,
                feedback: feedback
            ))
        }

        // 3. Knee balance (left vs right symmetry)
        if let lk = leftKneeAngle, let rk = rightKneeAngle {
            let diff = abs(lk - rk)
            let balanceScore = max(0, min(100, (1 - diff / 30) * 100))
            let feedback: String
            if diff < 5 {
                feedback = isEnglish ? "Even!" : "均等!"
            } else if lk < rk {
                feedback = isEnglish ? "Left knee deeper" : "左膝が深い"
            } else {
                feedback = isEnglish ? "Right knee deeper" : "右膝が深い"
            }
            details.append(FormDetail(
                label: isEnglish ? "Balance" : "左右バランス",
                score: balanceScore,
                feedback: feedback
            ))
        }

        // 4. Stance width (feet should be shoulder-width)
        if let la = pose.point(.leftAnkle), let ra = pose.point(.rightAnkle),
           let ls = pose.point(.leftShoulder), let rs = pose.point(.rightShoulder) {
            let feetWidth = abs(la.x - ra.x)
            let shoulderWidth = abs(ls.x - rs.x)
            let ratio = shoulderWidth > 0.01 ? feetWidth / shoulderWidth : 1
            let stanceScore = max(0, min(100, (1 - abs(ratio - 1) * 2) * 100))
            let feedback: String
            if ratio < 0.7 {
                feedback = isEnglish ? "Wider stance" : "もっと足を広げて"
            } else if ratio > 1.5 {
                feedback = isEnglish ? "Narrower stance" : "足を少し狭めて"
            } else {
                feedback = isEnglish ? "Good width!" : "良い幅!"
            }
            details.append(FormDetail(
                label: isEnglish ? "Stance" : "スタンス幅",
                score: stanceScore,
                feedback: feedback
            ))
        }

        return details
    }

    // MARK: - Push-up Analysis

    static func analyzePushup(_ pose: BodyPose, isEnglish: Bool) -> [FormDetail] {
        var details: [FormDetail] = []

        // 1. Elbow angle (shoulder-elbow-wrist)
        let leftElbow = pose.angle(a: .leftShoulder, b: .leftElbow, c: .leftWrist)
        let rightElbow = pose.angle(a: .rightShoulder, b: .rightElbow, c: .rightWrist)
        if let le = leftElbow, let re = rightElbow {
            let avgElbow = (le + re) / 2
            let elbowScore = elbowAngleScore(avgElbow)
            let feedback: String
            if avgElbow > 160 {
                feedback = isEnglish ? "Arms extended" : "腕伸ばし位置"
            } else if avgElbow > 120 {
                feedback = isEnglish ? "Go lower!" : "もっと下げて!"
            } else if avgElbow < 60 {
                feedback = isEnglish ? "Too low" : "下がりすぎ"
            } else {
                feedback = isEnglish ? "Good depth!" : "良い深さ!"
            }
            details.append(FormDetail(
                label: isEnglish ? "Elbow" : "肘角度",
                score: elbowScore,
                feedback: "\(Int(avgElbow))° \(feedback)"
            ))
        }

        // 2. Body alignment (shoulder-hip-ankle should be straight)
        let bodyLine = bodyAlignmentScore(pose)
        if let alignment = bodyLine {
            let feedback: String
            if alignment.score > 80 {
                feedback = isEnglish ? "Body straight!" : "体まっすぐ!"
            } else if alignment.hipHigh {
                feedback = isEnglish ? "Lower your hips" : "腰を下げて"
            } else {
                feedback = isEnglish ? "Raise your hips" : "腰を上げて"
            }
            details.append(FormDetail(
                label: isEnglish ? "Body Line" : "体のライン",
                score: alignment.score,
                feedback: feedback
            ))
        }

        // 3. Arm balance
        if let le = leftElbow, let re = rightElbow {
            let diff = abs(le - re)
            let balanceScore = max(0, min(100, (1 - diff / 30) * 100))
            let feedback = diff < 8
                ? (isEnglish ? "Even!" : "均等!")
                : (isEnglish ? "Uneven arms" : "左右ずれ")
            details.append(FormDetail(
                label: isEnglish ? "Arm Balance" : "腕バランス",
                score: balanceScore,
                feedback: feedback
            ))
        }

        return details
    }

    // MARK: - Plank Analysis

    static func analyzePlank(_ pose: BodyPose, isEnglish: Bool) -> [FormDetail] {
        var details: [FormDetail] = []

        // 1. Body alignment
        let bodyLine = bodyAlignmentScore(pose)
        if let alignment = bodyLine {
            let feedback: String
            if alignment.score > 85 {
                feedback = isEnglish ? "Perfect line!" : "完璧なライン!"
            } else if alignment.hipHigh {
                feedback = isEnglish ? "Lower your hips" : "腰を下げて"
            } else {
                feedback = isEnglish ? "Raise your hips" : "腰を上げて"
            }
            details.append(FormDetail(
                label: isEnglish ? "Body Line" : "体のライン",
                score: alignment.score,
                feedback: feedback
            ))
        }

        // 2. Shoulder position (shoulders over wrists)
        if let ls = pose.point(.leftShoulder), let lw = pose.point(.leftWrist),
           let rs = pose.point(.rightShoulder), let rw = pose.point(.rightWrist) {
            let shoulderMidX = (ls.x + rs.x) / 2
            let wristMidX = (lw.x + rw.x) / 2
            let offset = abs(shoulderMidX - wristMidX)
            let score = max(0, min(100, (1 - offset * 5) * 100))
            let feedback: String
            if offset < 0.05 {
                feedback = isEnglish ? "Shoulders aligned!" : "肩の位置OK!"
            } else if shoulderMidX < wristMidX {
                feedback = isEnglish ? "Shift forward" : "もう少し前へ"
            } else {
                feedback = isEnglish ? "Shift back" : "もう少し後ろへ"
            }
            details.append(FormDetail(
                label: isEnglish ? "Shoulder" : "肩位置",
                score: score,
                feedback: feedback
            ))
        }

        // 3. Left-right balance
        if let ls = pose.point(.leftShoulder), let rs = pose.point(.rightShoulder),
           let lh = pose.point(.leftHip), let rh = pose.point(.rightHip) {
            let leftDrop = ls.y - lh.y
            let rightDrop = rs.y - rh.y
            let diff = abs(leftDrop - rightDrop)
            let score = max(0, min(100, (1 - diff * 10) * 100))
            let feedback = diff < 0.03
                ? (isEnglish ? "Level!" : "水平!")
                : (isEnglish ? "Tilting" : "傾いてる")
            details.append(FormDetail(
                label: isEnglish ? "Level" : "水平度",
                score: score,
                feedback: feedback
            ))
        }

        return details
    }

    // MARK: - Helpers

    private static func kneeAngleScore(_ angle: Double) -> Double {
        // Standing (170°) = neutral, good squat depth (80-100°) = high score
        if angle > 150 { return 40 }  // standing, not squatting yet
        if angle > 120 { return 55 }  // quarter squat
        if angle > 100 { return 75 }  // half squat
        if angle >= 70 { return 100 } // parallel or below — perfect
        if angle >= 50 { return 80 }  // very deep, still ok
        return 60 // too deep, risky
    }

    private static func elbowAngleScore(_ angle: Double) -> Double {
        if angle > 160 { return 40 }  // arms straight, top position
        if angle > 130 { return 55 }  // barely bending
        if angle > 100 { return 75 }  // halfway
        if angle >= 70 { return 100 } // good depth
        if angle >= 45 { return 85 }  // very deep
        return 60 // too deep
    }

    private static func bodyAlignmentScore(_ pose: BodyPose) -> (score: Double, hipHigh: Bool)? {
        guard let ls = pose.point(.leftShoulder), let rs = pose.point(.rightShoulder),
              let lh = pose.point(.leftHip), let rh = pose.point(.rightHip),
              let la = pose.point(.leftAnkle), let ra = pose.point(.rightAnkle) else { return nil }

        let shoulder = CGPoint(x: (ls.x + rs.x) / 2, y: (ls.y + rs.y) / 2)
        let hip = CGPoint(x: (lh.x + rh.x) / 2, y: (lh.y + rh.y) / 2)
        let ankle = CGPoint(x: (la.x + ra.x) / 2, y: (la.y + ra.y) / 2)

        // Perfect alignment: hip should be on the line from shoulder to ankle
        let expectedHipY = shoulder.y + (ankle.y - shoulder.y) * ((hip.x - shoulder.x) / (ankle.x - shoulder.x + 0.001))
        let deviation = abs(hip.y - expectedHipY)

        // Simpler: check if hip deviates from shoulder-ankle midline
        let midY = (shoulder.y + ankle.y) / 2
        let hipDeviation = abs(hip.y - midY) / abs(ankle.y - shoulder.y + 0.001)
        let score = Double(max(0, min(100, (1 - hipDeviation * 4) * 100)))
        let hipHigh = hip.y < midY // In screen coords, lower y = higher position

        return (score, hipHigh)
    }
}
