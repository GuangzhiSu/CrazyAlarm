# CrazyAlarm

原生 SwiftUI iPhone 闹钟，面向 iOS 26+ / iPhone 17 Pro Max。黑色界面、蓝绿色任务卡和红色保存按钮。

## 1.1 组合起床任务

每个闹钟可自由选择并排序任务，必须按顺序完成全部任务才停止 App 内循环音乐。保留原有两题 Quiz；旧版闹钟与未完成的答题进度可迁移。

- 自定义 Quiz：两道自定义问题，答错不推进。
- 寻找家中物品：用相机拍摄指定的杯子、瓶子、书、键盘、椅子或鞋子，使用 Apple Vision 本机分类与置信度门槛验证。
- 跟着节拍说词语：普通话 / 英语本机识别，核对词语与语音时间戳，每拍最多计一次；三拍准备，可调整节拍和次数。
- 找不同色块：随机色块位置，支持 3×3、4×4、5×5 难度。
- 打字：输入自定义句子，可设置重复次数。
- 数学：随机加减、乘除题，支持三档难度；除法为整数结果。
- 填运算符：在加减乘除中选择正确符号，生成时确保答案唯一。
- 走路：从当前任务开始实时计步，需要运动与健身权限，累计进度持久化。
- 扫码：设置时扫描或填写绑定内容，响铃时用相机扫描完全相同的二维码 / 条形码。
- 摇一摇：使用去除重力的加速度与回稳、去抖条件计数。
- 拍照匹配：先拍摄参考物体，响铃后重新拍摄；通过 Vision 图像特征距离验证，可调整严格程度。
- 深蹲：前置相机本机识别髋、膝、踝，必须经历站直 → 下蹲 → 站直，连续稳定帧才计数；遮挡后重新校准。

任务进度与当前随机题持久化；相机和语音只在需要时申请权限。照片留在本机，语音不保存、不上传，不需要付费 AI 服务。识别受光线、角度、姿势及系统语音资源影响，需要先在自己的手机上试响确认。

## 闹钟与音乐

AlarmKit 提供锁屏提醒，通过「完成任务」进入 App。支持每周重复与单次闹钟。内置原创 Morning Spark；支持从「文件」导入未加密音频，系统闹钟使用前 28 秒，进入任务后循环完整文件。语音任务录音期间降低音乐音量并使用回声处理，其他任务继续播放。

iOS 系统停止入口、音量、电话、强制退出、关机、权限与签名过期不受 App 控制。后台不会自动弹出任务页；请点锁屏提醒的「完成任务」。相机、语音与动作识别需要在 App 前台进行。

QQ 音乐账户仍未接通。该能力需要平台分配的 OpenID / OpenAPI 应用凭据，个人 QQ 账号或会员资格不能代替它；此版本保留清晰的「待官方接入」提示。

## 免费安装与更新

详见 [Windows / SideStore 安装更新说明](docs/WINDOWS-INSTALL.md)。已安装 SideStore 的手机可直接导入新版 IPA 覆盖更新 CrazyAlarm，无需卸载旧版。保持同一个 Apple 账号和 Bundle ID，保留闹钟、题目与音乐。

免费签名有效期为 7 天。手机连接 Wi-Fi 与 LocalDevVPN，SideStore → My Apps → Refresh All 同时刷新 SideStore 和 CrazyAlarm；建议每 5～6 天执行。不需要电脑持续运行。系统更新或配对失效可能需要电脑重新配对。

## 构建与检查

Xcode 26.1+ 打开 `CrazyAlarm.xcodeproj`。无 CocoaPods、付费 SDK 或额外模型下载依赖。GitHub Actions 使用标准 macOS runner 测试并生成未签名 IPA，安装时由 SideStore 使用个人 Apple 账号签名。

```sh
swift test
xcodebuild -project CrazyAlarm.xcodeproj -scheme CrazyAlarm -sdk iphoneos \
  -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO build
```

Swift Package 包含 25 项逻辑测试：混合任务的完成顺序、旧数据迁移、进度与随机题恢复、条码精确匹配、题目正确性、摇动 / 深蹲去抖、语音节拍、Quiz 与日期 / 夏令时。相机、麦克风与运动识别的实际精度需要真机测试，逻辑测试不能代替它。

1.0 的安装、锁屏响铃、两题停铃和手机无线续签已由使用者在 iPhone 17 Pro Max 验证。1.1 新增传感器任务需覆盖更新后逐项验收。

## 真机验收

1. 覆盖更新后确认旧闹钟、两题答案和本地音乐仍在；先测试单个任务，再测试混合任务的顺序。
2. 每种新任务分别试响，允许所需权限；答错、扫错、拍错不能推进。拒绝权限时应显示可恢复的错误。
3. 语音核对说错、说对但离拍、重复识别结果；计步只应计算新步数，摇动只计独立动作。
4. 深蹲检查站直不动、遮挡、只蹲下不站回；相机退出 / App 进入后台后停止采集。
5. 拍照匹配检查同一物体不同角度与不同物体，按需要调整匹配严格程度。
6. 设置约两分钟后的单次闹钟，锁屏等待，点「完成任务」进入 App，确认完成全部任务才停止音乐。
7. 中途切换 App / 重启并返回，确认累计进度与当前随机题不丢失；测试录音结束后音量恢复。
8. 用 SideStore 无线刷新后再次打开 App。

## 官方参考

- [AlarmKit](https://developer.apple.com/documentation/alarmkit)
- [Vision 图像分类](https://developer.apple.com/documentation/vision/vnclassifyimagerequest)
- [Vision 姿态识别](https://developer.apple.com/documentation/vision/detecting-human-body-poses-in-images)
- [Speech 本机识别](https://developer.apple.com/documentation/speech/sfspeechrecognizer/supportsondevicerecognition)
- [SideStore 安装说明](https://docs.sidestore.io/docs/installation/install)
- [Apple 免费 Personal Team](https://developer.apple.com/help/account/basics/about-your-developer-account)
