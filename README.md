# CrazyAlarm

原生 SwiftUI iPhone 闹钟，面向 iOS 26+ / iPhone 17 Pro Max。参考黑色背景、蓝绿色任务卡和红色 Save 按钮的界面。

## 当前实现

- 闹钟列表、新增、编辑、删除、开关、时间滚轮、每周重复或仅一次。
- 每个闹钟设置两道自定义题目和答案；答错不推进，两题依次答对才结束 App 内循环音频。支持首尾空格、英文大小写及全角字符规范化。
- AlarmKit 系统锁屏闹钟，「答题起床」按钮通过 App Intent 打开题目。App 前台观察系统闹钟事件。
- 内置原创 Morning Spark 铃声；从「文件」导入可播放的本地音频。导入时为系统提醒生成最长 28 秒 PCM CAF，进入答题后循环完整音乐。无服务器、无网络音源依赖。
- 本地持久化题目、闹钟和答题进度；音频采用后台播放能力。首次样例闹钟默认关闭，不会在未授权时假装已启用。
- iOS 26.0 和 26.1+ 使用各自的 AlarmPresentation 初始化方式。界面遵守安全区域并可滚动。
- Swift Package 中提供 13 个实际逻辑测试，包括错误答案、第二题、重启持久化、重复日期和夏令时。

## 明确的边界

1. **无法保证整个 iOS 上只能答题停止。** Apple 的 AlarmPresentation 会自动提供系统停止入口。App 的题目页面没有关闭按钮，只有两题答对才调用停止；但锁屏的停止、用户音量、电话、强制退出、关机、权限撤销和免费签名失效由系统掌控。背景中不会自动弹出自定义答题页面；请点击系统的「答题起床」。
2. **QQ 音乐账户尚未接通。** QQ 音乐页明确显示待接入，不展示虚假的登录或歌单。腾讯官方 OpenID Demo 要求 QQ 音乐分配的应用 ID、包名和业务参数，OpenAPI 又使用另一套参数。目前没有这些凭据，也不能从 QQ 音乐 App 沙盒读取会员下载。本版可使用你拥有的未加密本地音频。
3. **当前交付是源代码，不是已验证的真机成品。** Windows 无法直接运行 Xcode；需要将文件上传到此仓库运行 Actions，或在 Mac 上打开工程编译。务必按下面的真机清单验证后再依赖它起床。

## 只有 Windows，免费装到自己手机

详见 [Windows 免费安装说明](docs/WINDOWS-INSTALL.md)。简要路线：

1. 把整个工程（含 `.github/workflows/ios.yml`）提交到 `GuangzhiSu/CrazyAlarm` 的 main 分支。
2. GitHub Actions 使用标准 macOS runner 测试及编译，下载 `CrazyAlarm-unsigned-IPA` 工件并解压，得到 `.ipa`。
3. Windows 安装 AltServer / AltStore Classic，按官方说明连接 iPhone、信任开发者并打开开发者模式。
4. 在 AltStore 中添加该 IPA，由你自己的 Apple 账户签名。**未签名 IPA 不能直接点击安装。**
5. 免费签名 7 天到期，提前通过 AltServer 刷新。此方式不用上架 App Store，不需要购买 Apple Developer 年费。

当前仓库为公开仓库：标准 GitHub Actions 托管 runner 的计算时间免费。工件仅保留 7 天以降低存储占用；如更改为私有仓库，需自行留意免费配额。

## Mac 开发

Xcode 26.1+ 打开 `CrazyAlarm.xcodeproj`，选择 CrazyAlarm target，修改唯一的 Bundle Identifier，在 Signing & Capabilities 选择自己的 Personal Team，连接 iPhone 点击 Run。最低系统 iOS 26.0。无需 CocoaPods、付费 SDK、XcodeGen 或额外依赖。

```sh
swift test
xcodebuild -project CrazyAlarm.xcodeproj -scheme CrazyAlarm -sdk iphoneos \
  -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO build
```

## 真机验收

- 在 iPhone 17 Pro Max 确认当前 iOS 为 26+，首次允许闹钟权限。
- 设置 2 分钟后的单次闹钟，锁屏并开静音 / 专注，确认系统提醒和声音；再点击「答题起床」。
- 两题中分别答错，确认音乐不停止；第一题答对仍播放，第二题答对停止。
- 答到第二题时切换 App，再返回，确认进度和循环音频；测试电话打断后播放恢复。
- 测试系统停止入口并确认这确实是可绕过的系统边界，而非声称无法绕过。
- 导入 MP3/M4A/WAV，分别测试锁屏片段和完整音乐循环；拒绝闹钟权限时保存必须失败。
- 测试每日、指定星期、单次响完状态、重启、时区切换及两个闹钟同时触发。
- 测试大字体、屏幕键盘、小屏设备以及签名刷新 / 到期行为。

## 官方参考

- [Apple AlarmKit](https://developer.apple.com/documentation/alarmkit)
- [系统自动停止按钮](https://developer.apple.com/documentation/alarmkit/alarmpresentation/alert-swift.struct)
- [Apple 免费 Personal Team：7 天有效期](https://developer.apple.com/help/account/basics/about-your-developer-account)
- [QQ 音乐官方 OpenID iOS Demo](https://github.com/tencentmusic/QQMusic_Innovation_QPlay_OpenID_Demo_iOS)
- [AltStore Windows 安装说明](https://faq.altstore.io/altstore-classic/how-to-install-altstore-windows)
- [GitHub Actions 费用说明](https://docs.github.com/en/billing/concepts/product-billing/github-actions)
