import AVFoundation
import SwiftUI

extension MissionKind {
    var tint: Color { group == 0 ? Theme.coral : group == 1 ? Theme.cyan : .purple }
}

struct MissionEditorView: View {
    @Binding var missions: [WakeMission]
    @Binding var questions: [QuizQuestion]
    @State private var selectedID: UUID?
    @State private var message: String?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section(header: Text("已选 \(missions.count) 种 · 按此顺序完成"),
                        footer: Text("全部完成后音乐才会停止。点右上角「编辑」可拖动顺序或删除任务。")) {
                    ForEach(missions) { mission in
                        Button { selectedID = mission.id } label: {
                            HStack(spacing: 16) {
                                icon(mission.kind)
                                VStack(alignment: .leading, spacing: 5) {
                                    Text(mission.kind.title).foregroundStyle(.white)
                                    Text(summary(mission)).font(.caption).foregroundStyle(Theme.secondary)
                                }
                                Spacer(); Image(systemName: "slider.horizontal.3").foregroundStyle(Theme.secondary)
                            }.padding(.vertical, 5)
                        }.listRowBackground(Theme.card)
                    }
                    .onMove { missions.move(fromOffsets: $0, toOffset: $1) }
                    .onDelete { offsets in
                        if missions.count > offsets.count { missions.remove(atOffsets: offsets) }
                        else { message = "至少保留一种任务。" }
                    }
                }

                ForEach(0..<3) { group in
                    Section(["热门任务", "唤醒大脑", "活动身体"][group]) {
                        ForEach(MissionKind.allCases.filter { $0.group == group }, id: \.rawValue) { kind in
                            Button {
                                if let existing = missions.first(where: { $0.kind == kind }) { selectedID = existing.id }
                                else { let next = WakeMission(kind: kind); missions.append(next); selectedID = next.id }
                            } label: {
                                HStack(spacing: 16) {
                                    icon(kind)
                                    VStack(alignment: .leading, spacing: 5) {
                                        Text(kind.title).foregroundStyle(.white)
                                        Text(kind.detail).font(.caption).foregroundStyle(Theme.secondary)
                                    }
                                    Spacer()
                                    Image(systemName: missions.contains(where: { $0.kind == kind }) ? "checkmark.circle.fill" : "plus.circle")
                                        .foregroundStyle(kind.tint)
                                }.padding(.vertical, 8)
                            }.listRowBackground(Theme.card)
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden).background(Theme.background)
            .navigationTitle("Mission").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("完成") { dismiss() } }
                ToolbarItem(placement: .topBarTrailing) { EditButton().labelStyle(.titleOnly) }
            }
            .sheet(item: Binding(get: { selectedID.map(MissionSelection.init) }, set: { selectedID = $0?.id })) { selection in
                if let index = missions.firstIndex(where: { $0.id == selection.id }) {
                    MissionConfigurationView(mission: $missions[index], questions: $questions)
                }
            }
            .alert("任务设置", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) {
                Button("知道了") { message = nil }
            } message: { Text(message ?? "") }
        }
        .preferredColorScheme(.dark)
    }
    private func icon(_ kind: MissionKind) -> some View {
        Image(systemName: kind.icon).font(.title2).foregroundStyle(kind.tint)
            .frame(width: 56, height: 56).background(kind.tint.opacity(0.17), in: RoundedRectangle(cornerRadius: 18))
    }
    private func summary(_ mission: WakeMission) -> String {
        switch mission.kind {
        case .quiz: "两道自定义题"
        case .household: "寻找\(mission.householdItem.title)"
        case .speech: "“\(mission.text)” · \(mission.target) 次 · \(mission.beatsPerMinute) BPM"
        case .barcode: mission.barcode.isEmpty ? "尚未绑定条码" : "已绑定条码"
        case .photo: mission.referencePhoto == nil ? "尚未拍摄参考照片" : "已拍摄参考照片"
        default: "\(mission.target) 次"
        }
    }
}

private struct MissionSelection: Identifiable { var id: UUID }

struct MissionConfigurationView: View {
    @Binding var mission: WakeMission
    @Binding var questions: [QuizQuestion]
    @Environment(\.dismiss) private var dismiss
    @State private var cameraPhoto = false
    @State private var cameraBarcode = false
    @State private var error: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Label(mission.kind.detail, systemImage: mission.kind.icon).foregroundStyle(mission.kind.tint)
                    if mission.kind.countRange.lowerBound != mission.kind.countRange.upperBound {
                        Stepper("完成次数：\(mission.target)", value: $mission.target, in: mission.kind.countRange)
                    }
                }
                switch mission.kind {
                case .quiz:
                    ForEach(questions.indices, id: \.self) { index in
                        Section("Quiz \(index + 1)") {
                            TextField("题目", text: $questions[index].prompt, axis: .vertical)
                            TextField("正确答案", text: $questions[index].answer).textInputAutocapitalization(.never).autocorrectionDisabled()
                        }
                    }
                case .typing:
                    Section("需要输入的句子") { TextEditor(text: $mission.text).frame(minHeight: 100) }
                case .speech:
                    Section("词语与节拍") {
                        TextField("要说的短词", text: $mission.text)
                        Picker("识别语言", selection: $mission.speechLocale) {
                            Text("普通话").tag("zh-CN"); Text("English").tag("en-US")
                        }
                        Stepper("节拍：\(mission.beatsPerMinute) BPM", value: $mission.beatsPerMinute, in: 40...100, step: 5)
                        Text("使用本机语音识别。先准备三拍，再在节拍亮起时说词语；每拍最多计一次。音乐会降低音量并继续循环。").font(.caption)
                    }
                case .math, .missingSymbol, .colorTiles:
                    difficulty
                case .household:
                    Section("要寻找的物品") {
                        Picker("目标", selection: $mission.householdItem) {
                            ForEach(HouseholdItem.allCases, id: \.rawValue) { Text($0.title).tag($0) }
                        }
                        Text("使用 iPhone 本机图像分类，支持上面的六类物品。光线、角度和遮挡会影响识别，设置后请先试响验证。").font(.caption)
                    }
                case .barcode:
                    Section("绑定二维码或条形码") {
                        TextField("条码内容", text: $mission.barcode, axis: .vertical)
                            .textInputAutocapitalization(.never).autocorrectionDisabled()
                        Button("用相机扫描绑定", systemImage: "qrcode.viewfinder") { requestCamera(photo: false) }
                        Text("把条码放在需要起床才能到达的位置；响铃时必须扫描相同内容。").font(.caption)
                    }
                case .photo:
                    Section("参考照片") {
                        if let image = MissionImages.load(mission.referencePhoto) {
                            Image(uiImage: image).resizable().scaledToFit().frame(maxHeight: 230).clipShape(RoundedRectangle(cornerRadius: 16))
                        }
                        Button("拍摄参考照片", systemImage: "camera") { requestCamera(photo: true) }
                        Text("选择稳定、特征明显的物体。响铃后用相机重新拍摄；尽量保持相近的距离、角度与光线。照片只保存在本机。").font(.caption)
                    }
                    difficulty
                case .steps:
                    Section { Text("从任务开始后计步，拿着手机走动。需要运动与健身权限；步数可能延迟几秒更新。进度会保存。").font(.callout) }
                case .shake:
                    Section { Text("握稳手机，适度来回摇动；持续保持一个方向的加速度只计一次。").font(.callout) }
                case .squat:
                    Section { Text("把手机竖直放稳，让全身入镜；身体稍向侧面以便看清膝盖弯曲。先站直，再下蹲并站回，才计一次。请量力设置次数。").font(.callout) }
                }
                Section { MissionPermissionPanel(missions: [mission], includeAlarms: false) }
            }
            .navigationTitle(mission.kind.title).navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) {
                Button("完成") {
                    do {
                        try mission.validate()
                        if mission.kind == .quiz { _ = try QuizSession(alarmID: UUID(), questions: questions) }
                        dismiss()
                    } catch { self.error = error.localizedDescription }
                }
            } }
            .sheet(isPresented: $cameraPhoto) {
                TakeMissionPhoto { image in
                    do { mission.referencePhoto = try MissionImages.save(image) }
                    catch { self.error = error.localizedDescription }
                }.ignoresSafeArea()
            }
            .sheet(isPresented: $cameraBarcode) {
                NavigationStack {
                    LiveMissionCamera(mode: .barcode, onSample: { code, _ in
                        if let code { mission.barcode = code; cameraBarcode = false }
                    }, onError: { error = $0; cameraBarcode = false })
                    .navigationTitle("扫描要绑定的条码")
                    .toolbar { ToolbarItem(placement: .cancellationAction) { Button("取消") { cameraBarcode = false } } }
                }
            }
            .alert("任务设置", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) {
                Button("知道了") { error = nil }
            } message: { Text(error ?? "") }
        }.preferredColorScheme(.dark)
    }
    private var difficulty: some View {
        Section {
            Picker(mission.kind == .photo ? "匹配严格程度" : "难度", selection: $mission.difficulty) {
                Text("简单").tag(1); Text("中等").tag(2); Text("严格 / 困难").tag(3)
            }
        }
    }
    private func requestCamera(photo: Bool) {
        Task { @MainActor in
            do { try await DevicePermissionCenter.shared.ensurePermissions([.camera]) }
            catch { self.error = error.localizedDescription; return }
            if photo { cameraPhoto = true } else { cameraBarcode = true }
        }
    }
}
