# Windows / SideStore 免费安装与更新

适用于自己的 iPhone、iOS 26+、Windows 10/11。使用免费 Apple 账号，无需购买开发者会员或上架 App Store。

## 已安装 SideStore：更新 CrazyAlarm

1. 从本次交付文件或仓库 Actions 中下载新版 CrazyAlarm IPA，保存到 iPhone「文件」。
2. 保持 Wi-Fi 和 LocalDevVPN 连接。打开 SideStore → My Apps → ＋，选择新版 IPA。
3. 使用与旧版相同的 Apple 账号覆盖安装 CrazyAlarm。无需删除旧版；保留原 Bundle ID `com.guangzhisu.CrazyAlarm` 才能保留数据。
4. 打开 App，进入闹钟编辑 → Mission，选择、排序和设置任务。旧闹钟默认保留原来的两题 Quiz。
5. 逐种任务试响并授权，然后设置两分钟后的单次闹钟进行锁屏测试。

## 第一次安装 SideStore

以 [SideStore 官方安装文档](https://docs.sidestore.io/docs/installation/install) 和 [准备工作](https://docs.sidestore.io/docs/installation/prerequisites) 为准。

1. Windows 安装 Apple iTunes 及 [官方 iLoader](https://iloader.app/)。
2. USB 连接并解锁 iPhone，信任此电脑。用户自行在 iLoader 输入 Apple 账号并完成双重验证，不向聊天发送凭据。
3. iLoader 选择手机，点击 SideStore (Stable)，等待安装和配对文件写入完成。
4. 手机设置 → 通用 → VPN 与设备管理，信任开发者；在隐私与安全性中开启开发者模式并按提示重启。
5. 手机安装 [LocalDevVPN](https://apps.apple.com/app/localdevvpn/id6755608044)，允许配置并连接，同时连接 Wi-Fi。
6. SideStore 登录相同的 Apple 账号，先在 My Apps 刷新 SideStore 自身，再导入 CrazyAlarm IPA。

2026-10-22 实测：默认 Anisette 服务曾返回 502，切换官方列表内的 `https://mac-ani.jkcoxson.com` 后 iLoader 登录成功。手机 SideStore 若遇到 -80045，关闭 Settings → User Customizations → On-Device Anisette，重启，再在 Anisette Servers 选择相同的 jkcoxson 地址并关闭自动切换，用户已成功登录。此为临时兼容办法，服务器状态可能变化；不要把服务故障理解为必须购买证书。

## 无线续签

已在用户的 iPhone 上验证：拔掉 USB 后，Wi-Fi + LocalDevVPN → SideStore → My Apps → Refresh All，SideStore 和 CrazyAlarm 都刷新成功。电脑不必开机。建议每 5～6 天刷新一次，务必在免费 7 天有效期内操作。若系统更新或配对文件失效，可能需要电脑重新配对。免费账号最多同时运行三个侧载 App，SideStore 自身占一个名额。

## 获取新构建

仓库 Actions → Build CrazyAlarm iOS，等待对应提交全部成功，再下载 CrazyAlarm-unsigned-IPA 工件并解压。GitHub 下载工件可能要求登录。未签名 IPA 不能直接点击安装，需要 SideStore 重新签名。标准公开仓库 runner 的构建计算时间免费，工件保留 7 天；私有仓库或额外存储应留意账号配额。

QQ 音乐账号尚未接入，当前可使用内置铃声或导入自己可读取的未加密 MP3 / M4A / WAV / CAF。新任务不需要付费 AI 服务；本机语音识别需要相应系统语言资源。
