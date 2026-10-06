import SwiftUI
import UniformTypeIdentifiers

enum Theme {
    static let background = Color(red: 0.035, green: 0.035, blue: 0.045)
    static let card = Color(red: 0.09, green: 0.09, blue: 0.11)
    static let cyan = Color(red: 0.22, green: 0.8, blue: 0.89)
    static let coral = Color(red: 1, green: 0.18, blue: 0.31)
    static let secondary = Color(red: 0.57, green: 0.57, blue: 0.61)
}

struct Card<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        content.padding(24).frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: 30))
    }
}

struct PrimaryButton: View {
    let title: String
    var busy = false
    var action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack {
                if busy { ProgressView().tint(.white) }
                Text(title).font(.system(.headline, design: .rounded))
            }.frame(maxWidth: .infinity).padding(.vertical, 20)
        }
        .buttonStyle(.plain).foregroundStyle(.white)
        .background(Theme.coral, in: RoundedRectangle(cornerRadius: 22))
        .disabled(busy)
    }
}

struct AlarmHomeView: View {
    @Bindable var store: AppStore
    @State private var editingAlarm: AlarmRecord?
    @State private var showsSettings = false

    var body: some View {
        Group {
            if store.challenge != nil {
                QuizView(store: store)
            } else {
                NavigationStack {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 28) {
                            HStack {
                                VStack(alignment: .leading, spacing: 5) {
                                    Text("WAKE YOUR MIND").font(.system(size: 10, weight: .bold, design: .monospaced)).tracking(3).foregroundStyle(Theme.cyan)
                                    Text("CrazyAlarm").font(.system(.largeTitle, design: .rounded, weight: .bold))
                                }
                                Spacer()
                                Button { showsSettings = true } label: {
                                    Image(systemName: "slider.horizontal.3").font(.title3).frame(width: 48, height: 48)
                                        .background(Theme.card, in: Circle())
                                }.accessibilityLabel("设置和使用说明")
                            }.padding(.top, 12)

                            VStack(alignment: .leading, spacing: 12) {
                                Text("先唤醒大脑，\n再关掉闹钟。").font(.system(.title, design: .rounded, weight: .semibold))
                                Text("两道题 · 一次清醒的开始").foregroundStyle(Theme.secondary)
                            }
                            if !store.isAuthorized {
                                Label("首次启用时，请允许闹钟权限。", systemImage: "bell.badge")
                                    .font(.footnote).foregroundStyle(Theme.cyan)
                            }
                            if let notice = store.notice {
                                Text(notice).font(.callout).foregroundStyle(Theme.cyan)
                            }
                            if store.alarms.isEmpty {
                                Card {
                                    VStack(alignment: .leading, spacing: 12) {
                                        Image(systemName: "sunrise.fill").font(.largeTitle).foregroundStyle(Theme.cyan)
                                        Text("明天，从这里开始。").font(.headline)
                                        Text("添加你的第一个答题闹钟。").foregroundStyle(Theme.secondary)
                                    }.padding(.vertical, 20)
                                }
                            }
                            ForEach(store.alarms) { alarm in
                                Card {
                                    VStack(alignment: .leading, spacing: 20) {
                                        HStack(alignment: .center) {
                                            Button { editingAlarm = alarm } label: {
                                                VStack(alignment: .leading, spacing: 5) {
                                                    Text(alarm.timeText).font(.system(size: 56, weight: .light, design: .rounded)).monospacedDigit()
                                                    Text("🐤  " + alarm.title).font(.headline).lineLimit(2)
                                                }.foregroundStyle(alarm.isEnabled ? .white : Theme.secondary)
                                            }.buttonStyle(.plain).accessibilityLabel("编辑 \(alarm.title)，\(alarm.timeText)")
                                            Spacer(minLength: 8)
                                            Toggle("启用闹钟", isOn: Binding(get: { alarm.isEnabled }, set: { _ in Task { await store.toggle(alarm) } }))
                                                .labelsHidden().tint(Theme.cyan).disabled(store.isBusy)
                                        }
                                        HStack {
                                            Text(alarm.repeatText).font(.footnote).foregroundStyle(Theme.secondary)
                                            Spacer()
                                            Label("2 道 Quiz", systemImage: "brain.head.profile").font(.footnote).foregroundStyle(Theme.cyan)
                                        }
                                        Divider().overlay(.white.opacity(0.06))
                                        HStack {
                                            Label(alarm.sound.title, systemImage: "music.note").font(.caption).foregroundStyle(Theme.secondary).lineLimit(1)
                                            Spacer()
                                            Button("试响") { store.begin(alarm, preview: true) }
                                                .font(.callout.weight(.semibold)).foregroundStyle(Theme.cyan)
                                                .padding(.vertical, 8).accessibilityHint("音乐开始后需要答对两题才能停止")
                                        }
                                    }
                                }
                                .contextMenu {
                                    Button("编辑", systemImage: "pencil") { editingAlarm = alarm }
                                    Button("删除闹钟", systemImage: "trash", role: .destructive) { Task { await store.delete(alarm) } }
                                }
                            }
                            Text("锁屏提醒由 iOS 提供；进入 App 后，答对两题才结束音乐。")
                                .font(.caption).foregroundStyle(Theme.secondary).lineSpacing(4)
                        }.padding(.horizontal, 24).padding(.bottom, 20)
                    }
                    .background(Theme.background)
                    .toolbar(.hidden, for: .navigationBar)
                    .safeAreaInset(edge: .bottom) {
                        PrimaryButton(title: "＋  添加闹钟") { var next = AlarmRecord(); next.isEnabled = true; editingAlarm = next }
                            .disabled(store.isBusy).padding(.horizontal, 24).padding(.vertical, 12).background(Theme.background)
                    }
                    .sheet(item: $editingAlarm) { AlarmEditorView(store: store, draft: $0) }
                    .sheet(isPresented: $showsSettings) { SettingsView() }
                }
            }
        }
        .background(Theme.background)
        .alert("CrazyAlarm", isPresented: Binding(get: { store.errorMessage != nil }, set: { if !$0 { store.errorMessage = nil } })) {
            Button("知道了") { store.errorMessage = nil }
        } message: { Text(store.errorMessage ?? "") }
    }
}

struct AlarmEditorView: View {
    @Bindable var store: AppStore
    @State var draft: AlarmRecord
    @State private var showsQuizEditor = false
    @State private var showsMusic = false
    @State private var localError: String?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    HStack(spacing: 14) {
                        Text("🐤").font(.largeTitle)
                        TextField("闹钟名称", text: $draft.title).font(.title3).submitLabel(.done)
                        Image(systemName: "pencil").foregroundStyle(Theme.secondary)
                    }.padding(.top, 18)
                    TimelineView(.periodic(from: .now, by: 60)) { context in
                        Text(countdownText(now: context.date)).font(.callout).foregroundStyle(Theme.secondary)
                            .frame(maxWidth: .infinity).padding(.top, 12)
                    }
                    HStack(spacing: 0) {
                        Picker("小时", selection: $draft.hour) {
                            ForEach(0..<24) { Text(String(format: "%02d", $0)).font(.system(size: 44, weight: .light, design: .rounded)).tag($0) }
                        }
                        Text(":").font(.largeTitle).foregroundStyle(Theme.secondary)
                        Picker("分钟", selection: $draft.minute) {
                            ForEach(0..<60) { Text(String(format: "%02d", $0)).font(.system(size: 44, weight: .light, design: .rounded)).tag($0) }
                        }
                    }.pickerStyle(.wheel).frame(height: 190).clipped()
                    VStack(spacing: 18) {
                        HStack {
                            Text(draft.repeatText).font(.callout)
                            Spacer()
                            Button {
                                draft.weekdays = draft.weekdays.count == 7 ? [] : Set(Weekday.allCases)
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: draft.weekdays.count == 7 ? "checkmark.square.fill" : "square").foregroundStyle(Theme.cyan)
                                    Text("每天").foregroundStyle(.white)
                                }
                            }.buttonStyle(.plain).frame(minHeight: 44)
                        }
                        HStack(spacing: 8) {
                            ForEach(Weekday.allCases, id: \.rawValue) { day in
                                let selected = draft.weekdays.contains(day)
                                Button {
                                    if selected { draft.weekdays.remove(day) } else { draft.weekdays.insert(day) }
                                } label: {
                                    Text(day.shortName).font(.callout.weight(.medium)).frame(maxWidth: .infinity, minHeight: 50)
                                        .foregroundStyle(selected ? Theme.cyan : Theme.secondary)
                                        .background(selected ? Theme.cyan.opacity(0.17) : Theme.card, in: RoundedRectangle(cornerRadius: 16))
                                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(selected ? Theme.cyan.opacity(0.25) : .clear))
                                }.buttonStyle(.plain).accessibilityLabel("星期\(day.shortName)")
                                    .accessibilityAddTraits(selected ? .isSelected : [])
                            }
                        }
                    }
                    Button { showsQuizEditor = true } label: {
                        Card {
                            VStack(alignment: .leading, spacing: 22) {
                                HStack { Text("Mission").font(.title3); Spacer(); Text("2 / 2").foregroundStyle(Theme.cyan) }
                                HStack(spacing: 12) {
                                    ForEach(Array(draft.questions.enumerated()), id: \.element.id) { index, question in
                                        VStack(alignment: .leading, spacing: 12) {
                                            Image(systemName: "brain.head.profile").font(.title2)
                                            Text("Quiz \(index + 1)").font(.caption.weight(.semibold))
                                            Text(question.prompt.isEmpty ? "添加题目" : question.prompt).font(.caption).lineLimit(2)
                                        }.foregroundStyle(Theme.cyan).padding(16).frame(maxWidth: .infinity, minHeight: 125, alignment: .leading)
                                            .background(Theme.cyan.opacity(0.14), in: RoundedRectangle(cornerRadius: 22))
                                    }
                                }
                                HStack {
                                    Text("两题都答对才结束音乐").font(.caption).foregroundStyle(Theme.secondary)
                                    Spacer(); Image(systemName: "chevron.right").font(.caption)
                                }
                            }
                        }
                    }.buttonStyle(.plain).foregroundStyle(.white)
                    VStack(alignment: .leading, spacing: 12) {
                        Text("ALARM SOUND").font(.caption.weight(.medium)).tracking(2).foregroundStyle(Theme.secondary)
                        Button { showsMusic = true } label: {
                            Card {
                                HStack(spacing: 14) {
                                    Image(systemName: "waveform").font(.title2).foregroundStyle(Theme.cyan)
                                    VStack(alignment: .leading, spacing: 6) {
                                        Text(draft.sound.title).font(.callout).lineLimit(2)
                                        Text("内置铃声 / 导入本地音乐").font(.caption).foregroundStyle(Theme.secondary)
                                    }
                                    Spacer(); Image(systemName: "chevron.right").foregroundStyle(Theme.secondary)
                                }
                            }
                        }.buttonStyle(.plain).foregroundStyle(.white)
                    }
                    Toggle("保存后启用", isOn: $draft.isEnabled).tint(Theme.cyan)
                    Text("iOS 系统仍提供停止入口。答题规则适用于 App 内播放，无法阻止强制退出、关机或撤销权限。")
                        .font(.caption).foregroundStyle(Theme.secondary).lineSpacing(4)
                }.padding(.horizontal, 24).padding(.bottom, 20)
            }
            .background(Theme.background)
            .navigationTitle("Wake-up alarm").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { dismiss() } label: { Image(systemName: "xmark") }.accessibilityLabel("取消编辑")
                }
            }
            .safeAreaInset(edge: .bottom) {
                PrimaryButton(title: "Save", busy: store.isBusy) {
                    Task {
                        draft.title = draft.title.trimmingCharacters(in: .whitespacesAndNewlines)
                        if draft.title.isEmpty { draft.title = "Wake up early" }
                        if await store.save(draft) { dismiss() }
                        else { localError = store.errorMessage; store.errorMessage = nil }
                    }
                }.padding(.horizontal, 24).padding(.vertical, 12).background(Theme.background)
            }
            .sheet(isPresented: $showsQuizEditor) { QuizEditorView(questions: $draft.questions) }
            .sheet(isPresented: $showsMusic) { SoundPickerView(sound: $draft.sound) }
            .alert("未能保存", isPresented: Binding(get: { localError != nil }, set: { if !$0 { localError = nil } })) {
                Button("知道了") { localError = nil }
            } message: { Text(localError ?? "") }
        }.interactiveDismissDisabled(store.isBusy)
    }

    private func countdownText(now: Date) -> String {
        guard let date = draft.nextFireDate(after: now) else { return "选择起床时间" }
        let minutes = max(1, Int(ceil(date.timeIntervalSince(now) / 60)))
        return "将在 \(minutes / 60) 小时 \(minutes % 60) 分钟后响起"
    }
}

struct QuizEditorView: View {
    @Binding var questions: [QuizQuestion]
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Text("给刚睡醒的自己，\n留两个小挑战。").font(.title2.weight(.semibold))
                    Text("两题按顺序作答。忽略答案首尾空格、英文大小写和全角字符，其他内容须完全一致。")
                        .font(.callout).foregroundStyle(Theme.secondary)
                    ForEach(questions.indices, id: \.self) { index in
                        Card {
                            VStack(alignment: .leading, spacing: 18) {
                                Text("QUIZ \(index + 1)").font(.caption.weight(.bold)).tracking(2).foregroundStyle(Theme.cyan)
                                TextField("题目，如：12 + 9 = ?", text: $questions[index].prompt, axis: .vertical)
                                    .font(.title3).lineLimit(2...5)
                                Divider()
                                TextField("正确答案", text: $questions[index].answer)
                                    .textInputAutocapitalization(.never).autocorrectionDisabled()
                            }
                        }
                    }
                    Text("题目和答案仅保存在此 App。请不要把账户密码设为答案。")
                        .font(.caption).foregroundStyle(Theme.secondary)
                }.padding(24)
            }.background(Theme.background)
                .navigationTitle("设置两道题").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("完成") { dismiss() } } }
        }
    }
}

struct SoundPickerView: View {
    @Binding var sound: AlarmSound
    @State private var showsImporter = false
    @State private var importError: String?
    @State private var isImporting = false
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Text("醒来，也要有好音乐。").font(.title2.weight(.semibold))
                    Button { sound = .builtIn; dismiss() } label: {
                        Card {
                            HStack {
                                Label("Morning Spark", systemImage: "sunrise.fill")
                                Spacer(); if sound.fileName == nil { Image(systemName: "checkmark.circle.fill") }
                            }.foregroundStyle(Theme.cyan)
                        }
                    }.buttonStyle(.plain)
                    Button { showsImporter = true } label: {
                        Card {
                            VStack(alignment: .leading, spacing: 12) {
                                Label(isImporting ? "正在准备音乐…" : "从「文件」导入音乐", systemImage: "square.and.arrow.down")
                                    .font(.headline).foregroundStyle(.white)
                                Text("支持未加密 MP3、M4A、WAV、CAF。锁屏时播放前 28 秒，进入答题后循环完整文件。")
                                    .font(.caption).foregroundStyle(Theme.secondary).lineSpacing(4)
                            }
                        }
                    }.buttonStyle(.plain).disabled(isImporting)
                    Card {
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                Label("QQ 音乐", systemImage: "music.note.list").font(.headline)
                                Spacer(); Text("待官方接入").font(.caption).foregroundStyle(Theme.secondary)
                            }
                            Text("账户登录和歌单选曲需要 QQ 音乐提供 OpenID / OpenAPI 应用凭据。本版尚未连接 QQ 音乐账号。")
                                .font(.callout).foregroundStyle(Theme.secondary).lineSpacing(4)
                            Link("查看 QQ 音乐开放平台 ↗", destination: URL(string: "https://developer.y.qq.com")!)
                                .font(.callout).foregroundStyle(Theme.cyan)
                            Text("QQ 音乐 App 内的会员下载文件通常不能直接由其他 App 读取；此处仅支持你能通过「文件」选择的未加密音频。")
                                .font(.caption).foregroundStyle(Theme.secondary)
                        }
                    }
                    if sound.fileName != nil {
                        Label("当前：\(sound.title)", systemImage: "checkmark.circle").font(.callout).foregroundStyle(Theme.cyan)
                    }
                }.padding(24)
            }.background(Theme.background)
                .navigationTitle("Alarm sound").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("完成") { dismiss() } } }
                .fileImporter(isPresented: $showsImporter, allowedContentTypes: [.audio]) { result in
                    isImporting = true
                    defer { isImporting = false }
                    do { sound = try MusicPlayer.importAudio(result.get()); dismiss() }
                    catch { importError = error.localizedDescription }
                }
                .alert("音乐导入失败", isPresented: Binding(get: { importError != nil }, set: { if !$0 { importError = nil } })) {
                    Button("知道了") { importError = nil }
                } message: { Text(importError ?? "") }
        }
    }
}

struct QuizView: View {
    @Bindable var store: AppStore
    @State private var answer = ""
    @State private var feedback = ""
    @FocusState private var answerFocused: Bool
    var body: some View {
        ScrollView {
            if let challenge = store.challenge {
                VStack(alignment: .leading, spacing: 28) {
                    HStack {
                        Text(challenge.isPreview ? "试响 · 答题体验" : "GOOD MORNING").font(.caption.weight(.bold)).tracking(3).foregroundStyle(Theme.cyan)
                        Spacer(); Image(systemName: "waveform").foregroundStyle(Theme.cyan).symbolEffect(.variableColor.iterative)
                    }.padding(.top, 24)
                    Text(challenge.alarm.timeText).font(.system(size: 78, weight: .light, design: .rounded)).monospacedDigit()
                    VStack(alignment: .leading, spacing: 12) {
                        Text("让大脑先醒来。").font(.system(.largeTitle, design: .rounded, weight: .semibold))
                        Text("答对两道题，音乐就会停止。").font(.callout).foregroundStyle(Theme.secondary)
                    }
                    HStack(spacing: 10) {
                        ForEach(0..<2) { index in
                            Capsule().fill(index < challenge.session.correctCount ? Theme.cyan : Theme.cyan.opacity(0.15)).frame(height: 5)
                        }
                    }
                    Card {
                        VStack(alignment: .leading, spacing: 24) {
                            Text("QUIZ \(min(challenge.session.correctCount + 1, 2)) / 2").font(.caption.weight(.bold)).tracking(2).foregroundStyle(Theme.cyan)
                            if let question = challenge.session.currentQuestion {
                                Text(question.prompt).font(.system(.title, design: .rounded, weight: .medium)).fixedSize(horizontal: false, vertical: true)
                                TextField("输入答案", text: $answer)
                                    .font(.title2).padding(18).background(Theme.background, in: RoundedRectangle(cornerRadius: 16))
                                    .textInputAutocapitalization(.never).autocorrectionDisabled().submitLabel(.go)
                                    .focused($answerFocused).onSubmit { submit() }
                                    .accessibilityLabel("第 \(challenge.session.correctCount + 1) 题答案")
                                if !feedback.isEmpty { Text(feedback).font(.callout).foregroundStyle(Theme.coral).accessibilityLabel(feedback) }
                            } else {
                                Text("两题已答对").font(.title2)
                                Text("若音频尚未停止，请点击下方重试。").foregroundStyle(Theme.secondary)
                            }
                        }
                    }
                    PrimaryButton(title: challenge.session.isComplete ? "重试停止音乐" : "提交答案  →") {
                        if challenge.session.isComplete { store.finish() } else { submit() }
                    }
                    Label(challenge.alarm.sound.title, systemImage: "music.note").font(.caption).foregroundStyle(Theme.secondary)
                }.padding(.horizontal, 24).padding(.bottom, 24)
            }
        }.background(Theme.background).scrollDismissesKeyboard(.interactively)
            .onChange(of: store.challenge?.alarm.id) { _, _ in answer = ""; feedback = "" }
    }

    private func submit() {
        let result = store.submit(answer)
        switch result {
        case .incorrect: feedback = "再想一想，音乐还在陪你。"; answer = ""
        case .nextQuestion: feedback = ""; answer = ""; answerFocused = true
        case .complete, .alreadyComplete: answer = ""; feedback = ""
        }
    }
}

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Text("CrazyAlarm").font(.largeTitle.weight(.bold))
                    Card {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("先试一次，再设明天的闹钟").font(.headline)
                            Text("点击闹钟上的「试响」，输入两题答案。然后设置 2 分钟后的闹钟，锁屏等待响起，点击「答题起床」进入 App。")
                                .font(.callout).foregroundStyle(Theme.secondary)
                        }
                    }
                    Card {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("iPhone 使用说明").font(.headline)
                            Text("支持 iOS 26 及以上，适配 iPhone 17 Pro Max 的安全区域和屏幕尺寸。允许系统闹钟权限后，锁屏提醒由 AlarmKit 调度。进入答题后播放本地音乐，可在后台继续。")
                                .font(.callout).foregroundStyle(Theme.secondary)
                            Text("音量由 iPhone 控制。系统停止按钮、音量调节、电话、强制退出、关机和权限开关仍由 iOS 控制；本 App 无法禁止这些操作。")
                                .font(.caption).foregroundStyle(Theme.secondary)
                        }
                    }
                    Card {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("免费安装").font(.headline)
                            Text("Windows 可以使用 AltStore Classic 安装构建后的 IPA。免费 Apple 账户签名有效期为 7 天，请在到期前刷新。安装说明随工程提供。")
                                .font(.callout).foregroundStyle(Theme.secondary)
                            Link("AltStore 官方安装说明 ↗", destination: URL(string: "https://faq.altstore.io/altstore-classic/how-to-install-altstore-windows")!)
                                .foregroundStyle(Theme.cyan)
                        }
                    }
                    Text("数据只保存在手机上。卸载 App 会删除题目、闹钟和导入的音乐。\n版本 1.0 · 首版需完成真机验证")
                        .font(.caption).foregroundStyle(Theme.secondary)
                }.padding(24)
            }.background(Theme.background)
                .navigationTitle("使用说明").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("完成") { dismiss() } } }
        }
    }
}
