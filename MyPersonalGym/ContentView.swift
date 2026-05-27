import SwiftUI
import Vision

struct ContentView: View {
    @State private var camera = CameraManager()
    @State private var detector = ExerciseDetector()
    @State private var composer = VideoComposer()
    @State private var showExercisePicker = false
    @State private var showSaved = false

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
                bottomBar
            }
            .safeAreaPadding()

            // Exercise picker overlay
            if showExercisePicker {
                exercisePickerOverlay
            }

            if showSaved {
                savedToast
            }
        }
        .preferredColorScheme(.dark)
        .task {
            camera.onFrame = { image, timestamp in
                DispatchQueue.main.async {
                    composer.latestPose = camera.currentPose
                    composer.latestExercise = detector.selectedExercise
                    composer.latestScore = detector.formScore
                    composer.appendFrame(cameraImage: image, timestamp: timestamp)
                }
            }
            camera.start()
        }
        .onDisappear { camera.stop() }
        .onChange(of: camera.poseUpdateCount) {
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
                    .font(.system(size: 16, weight: .bold, design: .monospaced))
                    .foregroundStyle(.orange)
                Text(isEnglish ? "AI Form Checker" : "AIフォームチェッカー")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(.orange.opacity(0.6))
            }

            Spacer()

            // Recording indicator
            if composer.isRecording {
                HStack(spacing: 4) {
                    Circle().fill(.red).frame(width: 8, height: 8)
                    Text("REC \(formatTime(composer.recordingDuration))")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundStyle(.red)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
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
            }
        }
    }

    // MARK: - Score Panel

    private var scorePanel: some View {
        VStack(spacing: 0) {
            HStack {
                Text(isEnglish ? "FORM" : "フォーム")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(.orange.opacity(0.8))
                Spacer()

                // Rep count or hold timer
                if detector.selectedExercise.isHold {
                    Text(formatTime(detector.formScore.holdTime))
                        .font(.system(size: 14, weight: .black, design: .monospaced))
                        .foregroundStyle(.orange)
                } else {
                    Text("\(detector.formScore.repCount) REPS")
                        .font(.system(size: 14, weight: .black, design: .monospaced))
                        .foregroundStyle(.orange)
                }

                Text(gradeFor(detector.formScore.overall))
                    .font(.system(size: 14, weight: .black, design: .monospaced))
                    .foregroundStyle(colorForScore(detector.formScore.overall))
                Text(String(format: "%.0f%%", detector.formScore.overall))
                    .font(.system(size: 16, weight: .black, design: .monospaced))
                    .foregroundStyle(colorForScore(detector.formScore.overall))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(.black.opacity(0.7))

            Divider().overlay(.orange.opacity(0.3))

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

    // MARK: - Bottom Bar

    private var bottomBar: some View {
        HStack(spacing: 20) {
            // Flip camera
            Button { camera.flipCamera() } label: {
                Image(systemName: "camera.rotate.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(.white.opacity(0.15), in: Circle())
            }

            // Current exercise button (opens picker)
            Button { showExercisePicker = true } label: {
                HStack(spacing: 6) {
                    Image(systemName: detector.selectedExercise.icon)
                        .font(.system(size: 16))
                    Text(detector.selectedExercise.name)
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                    Image(systemName: "chevron.up")
                        .font(.system(size: 10))
                }
                .foregroundStyle(.orange)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(.orange.opacity(0.2), in: Capsule())
                .overlay(Capsule().stroke(.orange, lineWidth: 1))
            }

            // Record button
            Button { toggleRecord() } label: {
                ZStack {
                    Circle()
                        .stroke(composer.isRecording ? .red : .white, lineWidth: 3)
                        .frame(width: 56, height: 56)
                    if composer.isRecording {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(.red)
                            .frame(width: 22, height: 22)
                    } else {
                        Circle()
                            .fill(.red)
                            .frame(width: 44, height: 44)
                    }
                }
            }

            // Reset
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
        .padding(.bottom, 8)
    }

    // MARK: - Exercise Picker Overlay

    private var exercisePickerOverlay: some View {
        ZStack {
            Color.black.opacity(0.6)
                .ignoresSafeArea()
                .onTapGesture { showExercisePicker = false }

            VStack(spacing: 0) {
                Spacer()

                VStack(spacing: 12) {
                    HStack {
                        Text(isEnglish ? "SELECT EXERCISE" : "種目を選択")
                            .font(.system(size: 14, weight: .bold, design: .monospaced))
                            .foregroundStyle(.orange)
                        Spacer()
                        Button { showExercisePicker = false } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 24))
                                .foregroundStyle(.white.opacity(0.5))
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)

                    LazyVGrid(columns: [
                        GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())
                    ], spacing: 10) {
                        ForEach(Exercise.allCases) { exercise in
                            Button {
                                detector.selectedExercise = exercise
                                detector.reset()
                                showExercisePicker = false
                            } label: {
                                VStack(spacing: 6) {
                                    Image(systemName: exercise.icon)
                                        .font(.system(size: 24))
                                    Text(exercise.name)
                                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.7)
                                }
                                .foregroundStyle(
                                    detector.selectedExercise == exercise ? .orange : .white.opacity(0.7)
                                )
                                .frame(maxWidth: .infinity)
                                .frame(height: 70)
                                .background(
                                    detector.selectedExercise == exercise
                                        ? .orange.opacity(0.2) : .white.opacity(0.08),
                                    in: RoundedRectangle(cornerRadius: 10)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(
                                            detector.selectedExercise == exercise ? .orange : .clear,
                                            lineWidth: 1.5
                                        )
                                )
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 20)
                }
                .background(.black.opacity(0.95), in: RoundedRectangle(cornerRadius: 20))
                .padding(.horizontal, 8)
                .padding(.bottom, 8)
            }
        }
        .transition(.opacity)
        .animation(.easeInOut(duration: 0.2), value: showExercisePicker)
    }

    // MARK: - Toast

    private var savedToast: some View {
        VStack {
            Spacer()
            Text(isEnglish ? "Saved to Photos" : "写真に保存しました")
                .font(.system(size: 14, weight: .bold, design: .monospaced))
                .foregroundStyle(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(.green.opacity(0.8), in: Capsule())
                .padding(.bottom, 120)
        }
        .transition(.move(edge: .bottom).combined(with: .opacity))
        .animation(.easeInOut, value: showSaved)
    }

    // MARK: - Recording

    private func toggleRecord() {
        if composer.isRecording {
            composer.stopRecording()
            showSaved = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) { showSaved = false }
        } else {
            composer.startRecording()
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

    var body: some View {
        GeometryReader { _ in
            Canvas { ctx, size in
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

                for (from, to) in connections {
                    guard let p1 = pose.point(from), let p2 = pose.point(to) else { continue }
                    var path = Path()
                    path.move(to: CGPoint(x: p1.x * size.width, y: p1.y * size.height))
                    path.addLine(to: CGPoint(x: p2.x * size.width, y: p2.y * size.height))
                    ctx.stroke(path, with: .color(.orange.opacity(0.7)), lineWidth: 3)
                }

                for (_, point) in pose.joints {
                    let sp = CGPoint(x: point.x * size.width, y: point.y * size.height)
                    ctx.fill(Path(ellipseIn: CGRect(x: sp.x - 5, y: sp.y - 5, width: 10, height: 10)), with: .color(.orange))
                    ctx.stroke(Path(ellipseIn: CGRect(x: sp.x - 5, y: sp.y - 5, width: 10, height: 10)), with: .color(.white), lineWidth: 1.5)
                }

                drawAngleIndicators(ctx: &ctx, size: size)
            }
        }
    }

    private func drawAngleIndicators(ctx: inout GraphicsContext, size: CGSize) {
        switch exercise {
        case .squat, .lunge, .wallSit, .calfRaise:
            drawAngle(ctx: &ctx, size: size, a: .leftHip, b: .leftKnee, c: .leftAnkle)
            drawAngle(ctx: &ctx, size: size, a: .rightHip, b: .rightKnee, c: .rightAnkle)
        case .pushup, .shoulderPress:
            drawAngle(ctx: &ctx, size: size, a: .leftShoulder, b: .leftElbow, c: .leftWrist)
            drawAngle(ctx: &ctx, size: size, a: .rightShoulder, b: .rightElbow, c: .rightWrist)
        case .deadlift, .hipThrust, .crunch:
            drawAngle(ctx: &ctx, size: size, a: .leftShoulder, b: .leftHip, c: .leftKnee)
            drawAngle(ctx: &ctx, size: size, a: .rightShoulder, b: .rightHip, c: .rightKnee)
        default:
            break
        }
    }

    private func drawAngle(ctx: inout GraphicsContext, size: CGSize,
                            a: VNHumanBodyPoseObservation.JointName,
                            b: VNHumanBodyPoseObservation.JointName,
                            c: VNHumanBodyPoseObservation.JointName) {
        guard let pA = pose.point(a), let pB = pose.point(b), let pC = pose.point(c),
              let angle = pose.angle(a: a, b: b, c: c) else { return }

        let center = CGPoint(x: pB.x * size.width, y: pB.y * size.height)
        let startAngle = atan2((pA.y * size.height) - center.y, (pA.x * size.width) - center.x)
        let endAngle = atan2((pC.y * size.height) - center.y, (pC.x * size.width) - center.x)

        var arcPath = Path()
        arcPath.addArc(center: center, radius: 25, startAngle: .radians(startAngle), endAngle: .radians(endAngle), clockwise: false)
        let arcColor: Color = angle < 100 ? .green : (angle < 140 ? .yellow : .red.opacity(0.7))
        ctx.stroke(arcPath, with: .color(arcColor), lineWidth: 2)

        ctx.draw(
            Text("\(Int(angle))°")
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundStyle(arcColor),
            at: CGPoint(x: center.x + 18, y: center.y - 18)
        )
    }
}
