import AVFoundation
import SwiftUI

struct MissionChallengeView: View {
    @Bindable var store: AppStore
    var body: some View {
        if let challenge = store.challenge {
            ScrollView {
                VStack(alignment: .leading, spacing: 26) {
                    HStack {
                        Text(challenge.isPreview ? "试响 · 任务体验" : "GOOD MORNING")
                            .font(.caption.weight(.bold)).tracking(3).foregroundStyle(Theme.cyan)
                        Spacer()
                        Text("\(min(challenge.session.index + 1, challenge.session.missions.count)) / \(challenge.session.missions.count) 任务")
                            .font(.caption.monospacedDigit()).foregroundStyle(Theme.secondary)
                    }.padding(.top, 24)
                    Text(challenge.alarm.timeText).font(.system(size: 68, weight: .light, design: .rounded)).monospacedDigit()
                    Text("唤醒大脑，\n也唤醒身体。").font(.system(.largeTitle, design: .rounded, weight: .semibold))
                    ProgressView(value: Double(challenge.session.index), total: Double(challenge.session.missions.count)).tint(Theme.cyan)
                    if let mission = challenge.session.current {
                        MissionActivePanel(store: store, mission: mission).id(mission.id)
                    } else {
                        PrimaryButton(title: "完成全部任务 · 停止音乐") { store.finish() }
                    }
                    Text("全部任务完成后停止音乐。任务进度会自动保存。")
                        .font(.caption).foregroundStyle(Theme.secondary)
                }.padding(24)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Theme.background).preferredColorScheme(.dark)
        }
    }
}

private struct MissionActivePanel: View {
    @Bindable var store: AppStore
    let mission: WakeMission
    @Environment(\.scenePhase) private var scenePhase
    @State private var answer = ""
    @State private var feedback = ""
    @State private var working = false
    @State private var showPhoto = false
    @State private var showBarcode = false
    @State private var poseCamera = false
    @State private var squatCounter = SquatCounter()
    @State private var motion = MotionMissionController()
    @State private var speech = SpeechMissionController()
    @State private var wantsTracking = false
    @State private var attempt = UUID()

    private var session: MissionSession? { store.challenge?.session }
    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack(spacing: 14) {
                Image(systemName: mission.kind.icon).font(.title).foregroundStyle(mission.kind.tint)
                VStack(alignment: .leading, spacing: 5) {
                    Text(mission.kind.title).font(.title2.weight(.semibold))
                    Text("\(session?.units ?? 0) / \(mission.target)").font(.headline.monospacedDigit()).foregroundStyle(Theme.cyan)
                }
            }
            switch mission.kind {
            case .quiz, .typing, .math:
                Card {
                    VStack(alignment: .leading, spacing: 18) {
                        Text(prompt).font(.title2).fixedSize(horizontal: false, vertical: true)
                        TextField("输入答案", text: $answer, axis: .vertical)
                            .font(.title3).padding(16).background(.black.opacity(0.25), in: RoundedRectangle(cornerRadius: 16))
                            .textInputAutocapitalization(.never).autocorrectionDisabled()
                        PrimaryButton(title: "提交答案  →") { handle(store.submit(answer)) }
                    }
                }
            case .missingSymbol:
                Text(session?.puzzle?.prompt ?? "").font(.largeTitle.monospacedDigit()).minimumScaleFactor(0.6)
                HStack {
                    ForEach(["+", "−", "×", "÷"], id: \.self) { symbol in
                        Button { handle(store.submit(symbol)) } label: {
                            Text(symbol).font(.largeTitle).frame(maxWidth: .infinity, minHeight: 72)
                                .background(Theme.card, in: RoundedRectangle(cornerRadius: 18))
                        }.foregroundStyle(Theme.cyan)
                    }
                }
            case .colorTiles:
                Text("点出颜色不同的一格").font(.headline)
                if let puzzle = session?.puzzle {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: mission.difficulty + 2), spacing: 10) {
                        ForEach(0..<puzzle.tileCount, id: \.self) { tile in
                            Button { handle(store.selectTile(tile)) } label: {
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color(hue: puzzle.hue, saturation: 0.65,
                                                brightness: tile == puzzle.differentTile ? 0.7 + [0.2, 0.12, 0.07][mission.difficulty - 1] : 0.7))
                                    .aspectRatio(1, contentMode: .fit)
                            }.accessibilityLabel("色块 \(tile + 1)")
                        }
                    }
                }
            case .steps, .shake:
                Text(motion.message).foregroundStyle(Theme.secondary)
                PrimaryButton(title: motion.isRunning ? "重新开始传感器（保留进度）" : "开始\(mission.kind.title)") { startMotion() }
            case .speech:
                speechPanel
            case .household, .photo:
                if mission.kind == .household { Text("请找到并拍摄：\(mission.householdItem.title)").font(.title2) }
                else if let image = MissionImages.load(mission.referencePhoto) {
                    Image(uiImage: image).resizable().scaledToFit().frame(maxHeight: 240).clipShape(RoundedRectangle(cornerRadius: 20))
                    Text("请重新拍摄参考照片中的物品。").foregroundStyle(Theme.secondary)
                }
                PrimaryButton(title: working ? "正在本机验证…" : "打开相机 · 拍照验证", busy: working) { requestCamera(.photo) }
            case .barcode:
                Text("前往你放置条码的位置，扫描绑定的二维码或条形码。").foregroundStyle(Theme.secondary)
                PrimaryButton(title: "打开相机 · 扫码") { requestCamera(.barcode) }
            case .squat:
                Text("手机放稳、全身入镜，身体稍向侧面。先站直，再下蹲并站回。").foregroundStyle(Theme.secondary)
                if poseCamera && scenePhase == .active {
                    LiveMissionCamera(mode: .squat, onSample: { _, angle in
                        if squatCounter.sample(angle: angle, time: ProcessInfo.processInfo.systemUptime) {
                            store.recordEvidence(missionID: mission.id, kind: .squat)
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        }
                        feedback = angle == nil ? "请让髋、膝和脚踝全部入镜" : "站直 → 下蹲 → 站直"
                    }, onError: { feedback = $0; poseCamera = false })
                    .frame(height: 380).clipShape(RoundedRectangle(cornerRadius: 22))
                }
                PrimaryButton(title: poseCamera ? "重置姿势识别（保留进度）" : "开始深蹲识别") {
                    squatCounter = SquatCounter(); requestCamera(.squat)
                }
            }
            if !feedback.isEmpty { Text(feedback).font(.callout).foregroundStyle(Theme.coral).accessibilityAddTraits(.updatesFrequently) }
        }
        .sheet(isPresented: $showPhoto) { TakeMissionPhoto { analyze($0) }.ignoresSafeArea() }
        .sheet(isPresented: $showBarcode) {
            NavigationStack {
                LiveMissionCamera(mode: .barcode, onSample: { code, _ in
                    guard let code, store.challenge?.session.current?.id == mission.id else { return }
                    showBarcode = false; handle(store.submit(code))
                }, onError: { feedback = $0; showBarcode = false })
                .navigationTitle("扫描绑定的条码")
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("返回任务") { showBarcode = false } } }
            }
        }
        .onDisappear { attempt = UUID(); motion.stop(); speech.stop(); poseCamera = false }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { motion.stop(); speech.stop(); squatCounter = SquatCounter() }
            else if wantsTracking && (mission.kind == .steps || mission.kind == .shake) { startMotion() }
        }
    }

    private var prompt: String {
        if mission.kind == .typing { return mission.text }
        if mission.kind == .math { return session?.puzzle?.prompt ?? "" }
        let index = session?.units ?? 0
        let questions = store.challenge?.alarm.questions ?? []
        return questions.indices.contains(index) ? questions[index].prompt : ""
    }
    private var speechPanel: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("“\(mission.text)”").font(.largeTitle.weight(.bold))
            if speech.isRunning {
                TimelineView(.animation(minimumInterval: 0.05)) { context in
                    let period = 60 / Double(mission.beatsPerMinute)
                    let elapsed = max(0, context.date.timeIntervalSince(speech.startedAt))
                    let beat = Int(elapsed / period)
                    let lit = elapsed.truncatingRemainder(dividingBy: period) < period * 0.3
                    Text(beat < 3 ? "准备 \(3 - beat)" : "说！")
                        .font(.system(size: 40, weight: .bold, design: .rounded)).frame(maxWidth: .infinity, minHeight: 120)
                        .background(lit ? Theme.cyan : Theme.card, in: RoundedRectangle(cornerRadius: 26))
                        .foregroundStyle(lit ? .black : .white)
                }
            }
            Text(speech.message).font(.callout).foregroundStyle(Theme.secondary)
            if !speech.transcript.isEmpty { Text("听到：\(speech.transcript)").font(.caption) }
            PrimaryButton(title: speech.isRunning ? "重新开始节拍（保留进度）" : "开始跟拍说词语") {
                Task {
                    await speech.start(mission, prepareAudio: { try store.setListening(true) },
                                       restoreAudio: { try? store.setListening(false) },
                                       onWord: { store.recordEvidence(missionID: mission.id, kind: .speech) },
                                       onBeat: { UIImpactFeedbackGenerator(style: .light).impactOccurred() })
                }
            }
        }
    }
    private func handle(_ result: MissionSession.Result) {
        if result == .incorrect { feedback = mission.kind == .barcode ? "条码不匹配，请扫描绑定的条码。" : "还不正确，再试一次。" }
        else { answer = ""; feedback = "完成了一次，继续！"; UIImpactFeedbackGenerator(style: .light).impactOccurred() }
    }
    private func startMotion() {
        wantsTracking = true
        motion.start(mission) { count in store.recordEvidence(missionID: mission.id, kind: mission.kind, count: count) }
    }
    private func requestCamera(_ kind: MissionKind) {
        let token = attempt
        Task { @MainActor in
            guard UIImagePickerController.isSourceTypeAvailable(.camera), await AVCaptureDevice.requestAccess(for: .video) else {
                feedback = "请在设置 → App → CrazyAlarm 中允许相机。"; return
            }
            guard attempt == token, store.challenge?.session.current?.id == mission.id else { return }
            if kind == .squat { poseCamera = true }
            else if kind == .barcode { showBarcode = true }
            else { showPhoto = true }
        }
    }
    private func analyze(_ image: UIImage) {
        working = true
        let token = attempt
        Task { @MainActor in
            let result = await Task.detached(priority: .userInitiated) {
                Result { () -> (Bool, String) in
                    if mission.kind == .household { return try MissionImages.find(mission.householdItem, in: image) }
                    guard let reference = mission.referencePhoto else { throw MissionError.missingReference }
                    return try MissionImages.match(image, reference: reference, difficulty: mission.difficulty)
                }
            }.value
            guard attempt == token, store.challenge?.session.current?.id == mission.id else { return }
            working = false
            switch result {
            case .success(let (passed, message)):
                feedback = message
                if passed { store.recordEvidence(missionID: mission.id, kind: mission.kind) }
            case .failure(let error): feedback = error.localizedDescription
            }
        }
    }
}
