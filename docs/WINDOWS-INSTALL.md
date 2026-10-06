# Windows 免费安装 CrazyAlarm

适用于自己的 iPhone 17 Pro Max、iOS 26+、Windows 10/11。无需 App Store 上架，也不需要付费开发者会员。免费签名每 7 天需要刷新。

## 第一步：生成 IPA

本交付包是 Xcode 源码工程，不能直接在 iPhone 上安装。已附 GitHub Actions 构建流程。

1. 解压 CrazyAlarm 源码包。在 Windows 文件资源管理器打开「显示隐藏的项目」，确认能看到 `.github` 文件夹。
2. 登录你自己的 GitHub，打开 `https://github.com/GuangzhiSu/CrazyAlarm`。将解压后的文件和文件夹上传至仓库根目录，直接提交到 main。应在根目录看到 `CrazyAlarm.xcodeproj`、`CrazyAlarm`、`Package.swift`、`Tests`、`.github`，不要多套一层 CrazyAlarm 文件夹。
3. 浏览器上传可将这些文件夹拖到 GitHub 的 Upload files 页面。若 `.github` 隐藏文件夹未成功上传，在仓库中使用 Add file → Create new file，文件名填写 `.github/workflows/ios.yml`，粘贴源码包中同名文件的全部内容并提交。
4. 打开仓库 Actions → Build CrazyAlarm iOS。提交会触发构建，也可在 main 分支点击 Run workflow。
5. 等待测试和编译成功（绿色），打开运行详情，在 Artifacts 下载 `CrazyAlarm-unsigned-IPA`。下载可能要求你登录 GitHub。解压 ZIP 后获得 `CrazyAlarm-unsigned.ipa`。
6. 若变红，请打开失败步骤的日志；不要把失败构建当作已可用安装包。首次编译尚未在交付环境执行，可能需要针对 Xcode SDK 报错调整源代码。

使用公开仓库和标准 runner 的构建计算时间免费；不要选择付费 larger runner。安装文件工件保留 7 天。如改为私有仓库，请检查账户免费配额。

## 第二步：安装 AltStore Classic

从官方来源安装：[AltStore Windows 逐步说明](https://faq.altstore.io/altstore-classic/how-to-install-altstore-windows)。后续版本要求可能变化，应以官方页面为准。

1. 按官方说明安装 Apple 的 iTunes、iCloud 以及 Windows AltServer。官方默认路径要求 Apple 官网版本的 iTunes / iCloud；微软商店版本需按其故障指南处理。
2. USB 连接 iPhone，手机上点「信任此电脑」，按官方说明在 iTunes 打开 Wi-Fi 同步。
3. 启动 AltServer，在 Windows 系统托盘中选择 Install AltStore → 你的 iPhone。只在官方 AltServer 界面输入你自己的 Apple 账户；无需把账户密码交给开发者。
4. iPhone 上根据提示在「设置 → 通用 → VPN 与设备管理」信任你的开发者账户，并在「设置 → 隐私与安全性 → 开发者模式」开启开发者模式、按提示重启。
5. 按 AltStore 的联网或本地网络访问提示完成安装。

## 第三步：安装 CrazyAlarm

1. 把 `CrazyAlarm-unsigned.ipa` 转移到 iPhone 的「文件」，例如使用 iCloud Drive。
2. 打开 AltStore Classic → My Apps → `+`，选择 IPA。AltStore 会使用你的 Apple 账户重新签名后安装。
3. 安装完成后打开 CrazyAlarm，点击「试响」，先答完两题验证音频。
4. 添加 2 分钟后的闹钟，启用并允许系统闹钟权限；锁屏等待它响起，点击「答题起床」。默认示例题答案是 **21** 和 **56**，可随时编辑。

## 每周刷新

免费 Apple 账户的安装签名 7 天到期。让 Windows 的 AltServer 可用，在同一网络按官方说明打开 AltStore → My Apps → Refresh All，建议到期前操作。免费账户最多同时安装 3 个侧载 App，AltStore 自己通常占一个位置。签名失效后无法打开 App，闹钟不能作为可靠起床保证。

## QQ 音乐为何暂不可选歌

QQ 音乐官方的 OpenID / OpenAPI 接入要求平台分配的应用参数。个人 QQ 账号或会员账号本身不能替代开发者应用凭据。获得官方接入后还要确认音乐播放和闹钟用途的授权、缓存限制以及登录刷新。本版直接显示「待官方接入」。你可以导入自己有权使用的未加密 MP3/M4A/WAV/CAF；会员离线下载并不等于可被其他 App 导入的普通文件。

## 不需要付费，但有两个条件

必须能生成 IPA，并按时刷新签名。无需买 Mac 的路径是 GitHub 标准 macOS 构建 + Windows AltServer；它不代表 Windows 本机能直接编译 iOS App。添加到主屏幕的网页虽然不需要签名，但 iOS 锁屏后的定时和音频受后台限制，不适合承诺这个答题闹钟用途。
