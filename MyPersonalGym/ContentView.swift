import SwiftUI
import Vision

struct ContentView: View {
    @State private var camera = CameraManager()
    @State private var detector = ExerciseDetector()

    private let isEnglish = Locale.preferredLanguages.first?.hasPrefix("en") == true

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            CameraPreview(session: camera.session)
                .ignoresSafeArea()

            if let pose = camera.currentPose {
                SkeletonOverlay(pose: pose, exercise: detector.selectedExercise, score: detector.formScore)
                    .ignoresSafeArea()
            }

            VStack(spacing: 0) {
                topBar
                Spacer()
                if camera.currentPose != nil {
                    scorePanel
                }
                exerciseSelector
                    .padding(.bottom, 8)
            }
            .safeAreaPadding()
        }
        .preferredColorScheme(.dark)
        .task { camera.start() }
        .onDisappear { camera.stop() }
        .onChange(of: camera.currentPose?.joints.count) {
            if let pose = camera.currentPose {
                detector.analyze(pose)
            }
        }
    }

    // MARK: - Top Bar

    private var topBar: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(isEnglish ? "MY PERSONAL GYM" : "マイパーソナルジム")
                    .font(.system(size: 18, weight: .bold, design: .monospaced))
                    .foregroundStyle(.orange)
                Text(isEnglish ? "AI Form Checker" : "AIフォームチェッカー")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(.orange.opacity(0.6))
            }

            Spacer()

            // Rep counter / Hold timer
            if detector.selectedExercise == .plank {
                HStack(spacing: 4) {
                    Image(systemName: "timer")
                        .font(.system(size: 10))
                    Text(formatTime(detector.formScore.holdTime))
                        .font(.system(size: 16, weight: .black, design: .monospaced))
                }
                .foregroundStyle(.orange)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(.black.opacity(0.7), in: Capsule())
            } else {
                HStack(spacing: 4) {
                    Image(systemName: "repeat")
                        .font(.system(size: 10))
                    Text("\(detector.formScore.repCount)")
                        .font(.system(size: 22, weight: .black, design: .monospaced))
                    Text("REPS")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                }
                .foregroundStyle(.orange)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(.black.opacity(0.7), in: Capsule())
            }

            // Tracking status
            if camera.currentPose != nil {
                HStack(spacing: 4) {
                    Circle().fill(.green).frame(width: 6, height: 6)
                    Text("TRACKING")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundStyle(.green)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(.black.opacity(0.6), in: Capsule())
            } else {
                HStack(spacing: 4) {
                    Circle().fill(.red).frame(width: 6, height: 6)
                    Text(isEnglish ? "NO BODY" : "未検出")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundStyle(.red)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(.black.opacity(0.6), in: Capsule())
            }
        }
    }

    // MARK: - Score Panel

    private var scorePanel: some View {
        VStack(spacing: 0) {
            // Overall
            HStack {
                Text(isEnglish ? "FORM" : "フォーム")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(.orange.opacity(0.8))
                Spacer()
                Text(gradeFor(detector.formScore.overall))
                    .font(.system(size: 14, weight: .black, design: .monospaced))
                    .foregroundStyle(colorForScore(detector.formScore.overall))
                Text(String(format: "%.0f%%", detector.formScore.overall))
                    .font(.system(size: 18, weight: .black, design: .monospaced))
                    .foregroundStyle(colorForScore(detector.formScore.overall))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(.black.opacity(0.7))

            Divider().overlay(.orange.opacity(0.3))

            // Detail rows
            VStack(spacing: 2) {
                ForEach(Array(detector.formScore.details.enumerated()), id: \.offset) { _, detail in
                    detailRow(detail)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(.black.opacity(0.6))
        }
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .overlay(RoundedRectangle(cornerRadius: 6).stroke(.orange.opacity(0.3), lineWidth: 1))
        .padding(.horizontal, 30)
        .padding(.bottom, 8)
    }

    private func detailRow(_ detail: FormDetail) -> some View {
        HStack(spacing: 4) {
            Circle().fill(colorForScore(detail.score)).frame(width: 4, height: 4)
            Text(detail.label)
                .font(.system(size: 9, weight: .medium, design: .monospaced))
                .foregroundStyle(.white.opacity(0.8))
                .frame(width: 55, alignment: .leading)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(.white.opacity(0.1))
                        .frame(height: 4)
                    RoundedRectangle(cornerRadius: 2)
                        .fill(colorForScore(detail.score))
                        .frame(width: geo.size.width * min(detail.score / 100, 1), height: 4)
                }
            }
            .frame(height: 4)

            Text(String(format: "%.0f", detail.score))
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundStyle(colorForScore(detail.score))
                .frame(width: 20, alignment: .trailing)

            Text(detail.feedback)
                .font(.system(size: 8, weight: .medium, design: .monospaced))
                .foregroundStyle(.white.opacity(0.6))
                .frame(maxWidth: .infinity, alignment: .trailing)
                .lineLimit(1)
        }
    }

    // MARK: - Exercise Selector

    private var exerciseSelector: some View {
        HStack(spacing: 12) {
            // Flip camera
            Button {
                camera.flipCamera()
            } label: {
                Image(systemName: "camera.rotate.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(.white.opacity(0.15), in: Circle())
            }

            ForEach(Exercise.allCases) { exercise in
                Button {
                    detector.selectedExercise = exercise
                    detector.reset()
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: exercise.icon)
                            .font(.system(size: 20))
                        Text(exercise.name)
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                    }
                    .foregroundStyle(detector.selectedExercise == exercise ? .orange : .white.opacity(0.6))
                    .frame(width: 72, height: 56)
                    .background(
                        detector.selectedExercise == exercise
                            ? .orange.opacity(0.2) : .white.opacity(0.08),
                        in: RoundedRectangle(cornerRadius: 10)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(detector.selectedExercise == exercise ? .orange : .clear, lineWidth: 1.5)
                    )
                }
            }

            // Reset button
            Button {
                detector.reset()
            } label: {
                Image(systemName: "arrow.counterclockwise")
                    .font(.system(size: 18))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(.white.opacity(0.15), in: Circle())
            }
        }
    }

    // MARK: - Helpers

    private func formatTime(_ seconds: TimeInterval) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", mins, secs)
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

    private func colorForScore(_ score: Double) -> Color {
        switch score {
        case 90...: return Color(red: 0.3, green: 1, blue: 0.5)
        case 80..<90: return Color(red: 0.5, green: 1, blue: 0.8)
        case 70..<80: return .yellow
        case 60..<70: return .orange
        default: return Color(red: 1, green: 0.4, blue: 0.4)
        }
    }
}

// MARK: - Skeleton Overlay

struct SkeletonOverlay: View {
    let pose: BodyPose
    let exercise: Exercise
    let score: FormScore

    private let jointColor: Color = .orange
    private let boneColor: Color = .orange.opacity(0.7)

    var body: some View {
        GeometryReader { geo in
            Canvas { ctx, size in
                // Draw bones (connections between joints)
                let connections: [(VNHumanBodyPoseObservation.JointName, VNHumanBodyPoseObservation.JointName)] = [
                    // Torso
                    (.leftShoulder, .rightShoulder),
                    (.leftShoulder, .leftHip),
                    (.rightShoulder, .rightHip),
                    (.leftHip, .rightHip),
                    // Left arm
                    (.leftShoulder, .leftElbow),
                    (.leftElbow, .leftWrist),
                    // Right arm
                    (.rightShoulder, .rightElbow),
                    (.rightElbow, .rightWrist),
                    // Left leg
                    (.leftHip, .leftKnee),
                    (.leftKnee, .leftAnkle),
                    // Right leg
                    (.rightHip, .rightKnee),
                    (.rightKnee, .rightAnkle),
                    // Neck
                    (.nose, .neck),
                    (.neck, .leftShoulder),
                    (.neck, .rightShoulder),
                ]

                for (from, to) in connections {
                    guard let p1 = pose.point(from), let p2 = pose.point(to) else { continue }
                    let sp1 = CGPoint(x: p1.x * size.width, y: p1.y * size.height)
                    let sp2 = CGPoint(x: p2.x * size.width, y: p2.y * size.height)
                    var path = Path()
                    path.move(to: sp1)
                    path.addLine(to: sp2)
                    ctx.stroke(path, with: .color(boneColor), lineWidth: 3)
                }

                // Draw joints
                for (_, point) in pose.joints {
                    let sp = CGPoint(x: point.x * size.width, y: point.y * size.height)
                    ctx.fill(
                        Path(ellipseIn: CGRect(x: sp.x - 5, y: sp.y - 5, width: 10, height: 10)),
                        with: .color(jointColor)
                    )
                    ctx.stroke(
                        Path(ellipseIn: CGRect(x: sp.x - 5, y: sp.y - 5, width: 10, height: 10)),
                        with: .color(.white), lineWidth: 1.5
                    )
                }

                // Draw angle indicators for key joints
                drawAngleIndicators(ctx: &ctx, size: size)
            }
        }
    }

    private func drawAngleIndicators(ctx: inout GraphicsContext, size: CGSize) {
        switch exercise {
        case .squat:
            drawAngleArc(ctx: &ctx, size: size, a: .leftHip, b: .leftKnee, c: .leftAnkle)
            drawAngleArc(ctx: &ctx, size: size, a: .rightHip, b: .rightKnee, c: .rightAnkle)
        case .pushup:
            drawAngleArc(ctx: &ctx, size: size, a: .leftShoulder, b: .leftElbow, c: .leftWrist)
            drawAngleArc(ctx: &ctx, size: size, a: .rightShoulder, b: .rightElbow, c: .rightWrist)
        case .plank:
            break // No angle arcs for plank
        }
    }

    private func drawAngleArc(ctx: inout GraphicsContext, size: CGSize,
                               a: VNHumanBodyPoseObservation.JointName,
                               b: VNHumanBodyPoseObservation.JointName,
                               c: VNHumanBodyPoseObservation.JointName) {
        guard let pA = pose.point(a), let pB = pose.point(b), let pC = pose.point(c),
              let angle = pose.angle(a: a, b: b, c: c) else { return }

        let center = CGPoint(x: pB.x * size.width, y: pB.y * size.height)
        let radius: CGFloat = 25

        let startAngle = atan2((pA.y * size.height) - center.y, (pA.x * size.width) - center.x)
        let endAngle = atan2((pC.y * size.height) - center.y, (pC.x * size.width) - center.x)

        var arcPath = Path()
        arcPath.addArc(center: center, radius: radius, startAngle: .radians(startAngle), endAngle: .radians(endAngle), clockwise: false)
        let arcColor: Color = angle < 100 ? .green : (angle < 140 ? .yellow : .red.opacity(0.7))
        ctx.stroke(arcPath, with: .color(arcColor), lineWidth: 2)

        // Angle text
        let textPoint = CGPoint(x: center.x + 18, y: center.y - 18)
        ctx.draw(
            Text("\(Int(angle))°")
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundStyle(arcColor),
            at: textPoint
        )
    }
}
