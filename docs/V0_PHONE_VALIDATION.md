# V0 手机验证指南

本指南只验证 V0-A 本地自动接听。固定目标为 `HUAWEI Pura 70 Ultra / HarmonyOS 4.2.0 / WeChat 8.0.76`；其它组合必须重新采集快照，不能沿用本门禁。

当前只有构建和离线测试证据，尚无目标手机实测证据。测试结果使用 [V0 记录模板](V0_TEST_RECORD_TEMPLATE.md)，真实昵称、微信号、截图和 UI XML 不得提交到 Git。

## 先读安全警示

- 使用测试微信号或低风险备用账号，呼叫方另备一台手机并全程在场。
- 在接听方微信中给测试联系人设置唯一合成备注，如 `V0TEST01`；不要用真实姓名、短昵称或模糊匹配。
- 快照阶段必须关闭 GrandmaBridge、GKD 和其它 Accessibility 自动化服务。
- 不进入微信支付、转账、红包、银行卡、验证码、删除或消息管理页面。
- 发现错误点击时立即结束测试，并在系统设置中关闭 GrandmaBridge 无障碍服务。不要依赖脚本自行恢复。
- 锁屏熄屏是 V0-A 必测项。失败可以证明平台限制，但不能改写成通过。

### 手机装有网银时

未绑银行卡的新微信号只降低微信内风险，不能消除手机系统级权限风险。当前 V0-A APK 不具备联网权限，无障碍事件限定 `com.tencent.mm`，代码和 `SafetyGate` 还会重复检查包名；但无障碍与通知使用权本身仍是高敏感授权，原型也尚未完成正式安全审计。

推荐改用不安装网银、支付和密码管理工具的备用机。若必须使用这台手机：

1. Gate 1 只读快照期间不要启用 GrandmaBridge 或 GKD 无障碍服务。
2. 不在这台手机安装 GKD 等额外自动化工具。
3. 进入实测前退出并关闭网银 App，临时关闭其网络访问和通知；能安全卸载且不影响银行令牌时，卸载更稳妥。
4. 只安装自己从本仓库构建或本仓库 CI 生成的 APK。
5. 每次只在准备接听测试时打开 GrandmaBridge 授权，结束后立即关闭无障碍和通知使用权。
6. 全部验证结束后撤销电脑 USB 调试授权并关闭 USB 调试。

微信的联网权限属于微信自身；GrandmaBridge 不联网不会影响微信语音或视频通话。

## 1. 准备电脑

在仓库根目录运行离线自测：

```powershell
.\scripts\v0_self_test.ps1
```

需要命令行连接手机时必须有 ADB。若尚未安装，先阅读 [Android SDK License](https://developer.android.com/studio/terms)；明确接受后再运行：

```powershell
.\scripts\v0_setup_platform_tools.ps1 -AcceptAndroidSdkLicense
.\scripts\v0_host_preflight.ps1
```

该安装脚本固定官方 Platform-Tools `37.0.0` 和校验值，只写入已忽略的 `.tools/`。未接受许可时不要运行，可改用 Android Studio SDK Manager。

在手机“开发人员选项”中临时打开 USB 调试，连接后确认授权。使用仓库安装的 Platform-Tools 时运行：

```powershell
.\.tools\android-sdk\platform-tools\adb.exe devices
```

使用 Android Studio 自带的 ADB 时也可以运行 `adb devices`，但先确认命令指向可信 SDK。手机状态必须是 `device`，不能是 `unauthorized`。

多台设备同时连接时，后续命令都加 `-Serial <deviceSerial>`。

## 2. Gate 1：采集六组只读快照

1. 在手机“关于手机”和微信设置中人工确认固定目标矩阵。
2. 将接听方联系人备注设为 `V0TEST01`。
3. 关闭 GrandmaBridge、GKD 及其它自动化无障碍服务。
4. 在 PowerShell 中定义只读采集参数：

```powershell
$snapshot = @{
    ExpectedContactRemark = "V0TEST01"
    AcceptPrivateDataCapture = $true
    ConfirmAutomationDisabled = $true
    ConfirmTargetDeviceMatrix = $true
}
```

逐条执行。`ScreenState` 表示来电开始前的状态；每条命令会先要求准备该状态，再要求呼叫方发起来电。来电保持响铃，不能手动接听或拒绝，直到脚本完成。

```powershell
.\scripts\v0_capture_call_snapshot.ps1 @snapshot -CallType Voice -ScreenState Unlocked
.\scripts\v0_capture_call_snapshot.ps1 @snapshot -CallType Video -ScreenState Unlocked
.\scripts\v0_capture_call_snapshot.ps1 @snapshot -CallType Voice -ScreenState LockedScreenOn
.\scripts\v0_capture_call_snapshot.ps1 @snapshot -CallType Video -ScreenState LockedScreenOn
.\scripts\v0_capture_call_snapshot.ps1 @snapshot -CallType Voice -ScreenState LockedScreenOff
.\scripts\v0_capture_call_snapshot.ps1 @snapshot -CallType Video -ScreenState LockedScreenOff
```

脚本只读取设备状态、UI 层级和截图，不点击、不输入、不接听。每组输出位于 `artifacts/v0-call-snapshots/`。检查六个 `screen.png` 确实对应目标联系人和通话类型，同时核对 `device-info.txt` 与手机“关于手机”一致。

确认截图后生成门禁：

```powershell
$gatePath = "artifacts/v0-call-snapshots/v0-a-gate.json"
.\scripts\v0_check_snapshot_gate.ps1 `
    -ConfirmScreenshotsReviewed `
    -OutputPath $gatePath
```

只有输出 `complete: True` 和 `valid: 6/6` 才能继续。失败时保持所有自动化服务关闭；查看 `analysis.json` 的 `reasons`，不要放宽到包含匹配或任意可点击按钮。

需要用 GKD 独立验证选择器时，严格按 [GKD 校准说明](V0_GKD_VALIDATION.md) 操作。没有真实快照前不编写 GKD 规则。

## 3. 安装和配置 GrandmaBridge

提交 `443c0ec` 已在 [GitHub Actions run 29743623576](https://github.com/NaritaC/GrandmaCallAgent/actions/runs/29743623576) 通过单元测试、Lint 和 debug APK 构建。可以从该 run 下载 `GrandmaBridge-debug` artifact，解压后用仓库 ADB 安装，无需在本机安装完整 Android SDK 35：

```powershell
.\scripts\v0_build_install.ps1 -ApkPath C:\path\to\app-debug.apk
```

也可以用 Android Studio 打开 `GrandmaBridge/` 并安装，或在具备 JDK 17+、Android SDK 35 和 ADB 时本地构建：

```powershell
.\scripts\v0_build_install.ps1
```

只使用本仓库 CI 或自己的 Android Studio 构建产物。

在 App 中：

1. 保持“启用白名单来电自动接听”关闭。
2. 白名单只填写 `V0TEST01`，保存。
3. 手动授权 GrandmaBridge 无障碍服务和通知使用权。
4. 检查设备状态：

```powershell
.\scripts\v0_device_preflight.ps1 -AssertReady
```

## 4. Gate 2：负向测试

V0-A 实机场景的推荐顺序是：

```powershell
.\scripts\v0_run_scenario.ps1 -Scenario AutoAnswerOff -ScreenState Unlocked
.\scripts\v0_run_scenario.ps1 -Scenario NonCallAccept -AcceptLiveCallAction
.\scripts\v0_run_scenario.ps1 -Scenario NonWhitelist -ScreenState Unlocked -SnapshotGatePath $gatePath -AcceptLiveCallAction
.\scripts\v0_run_scenario.ps1 -Scenario WhitelistVoice -ScreenState Unlocked -SnapshotGatePath $gatePath -AcceptLiveCallAction
.\scripts\v0_run_scenario.ps1 -Scenario WhitelistVideo -ScreenState Unlocked -SnapshotGatePath $gatePath -AcceptLiveCallAction
.\scripts\v0_run_scenario.ps1 -Scenario WhitelistVoice -ScreenState LockedScreenOn -SnapshotGatePath $gatePath -AcceptLiveCallAction
.\scripts\v0_run_scenario.ps1 -Scenario WhitelistVideo -ScreenState LockedScreenOn -SnapshotGatePath $gatePath -AcceptLiveCallAction
.\scripts\v0_run_scenario.ps1 -Scenario WhitelistVoice -ScreenState LockedScreenOff -SnapshotGatePath $gatePath -AcceptLiveCallAction
.\scripts\v0_run_scenario.ps1 -Scenario WhitelistVideo -ScreenState LockedScreenOff -SnapshotGatePath $gatePath -AcceptLiveCallAction
```

前三条是负向测试：总开关关闭、非通话接受按钮、非白名单来电。三条全部无误触后，才打开自动接听开关并运行后六条白名单真实通话。`-AcceptLiveCallAction` 是对实机自动化风险的显式确认；不能写进默认配置。

期望日志：

- 总开关关闭：`auto_answer_disabled`，无 `accept_success`。
- 非白名单：`contact_not_in_local_whitelist`，无 `accept_success`。
- 白名单：`incoming_detected`、`incoming_allowed`、`accept_success`。
- 视频：额外包含 `callType=video`。

脚本默认先清日志、等待人工完成场景、断言关键字并采集证据。先用 `-PlanOnly` 可以只预览步骤，不连接手机。

## 5. V0.5 一键拨出

以下场景不属于 V0-A，只有 V0-A 全部通过后才执行。先在 App 中勾选“启用 V0.5 实验性一键拨出（仅监督测试）”；该解锁不持久化，App 进程重启后恢复关闭。始终使用测试联系人、保持微信远离资金页面，并同时提供两个脚本确认开关。

V0.5 场景的推荐顺序是：

```powershell
.\scripts\v0_run_scenario.ps1 -Scenario OutboundWrongPage -AcceptLiveCallAction -AcceptExperimentalOutbound
.\scripts\v0_run_scenario.ps1 -Scenario HighRiskPage -AcceptLiveCallAction -AcceptExperimentalOutbound
.\scripts\v0_run_scenario.ps1 -Scenario OutboundCancel -AcceptLiveCallAction -AcceptExperimentalOutbound
.\scripts\v0_run_scenario.ps1 -Scenario OutboundVoice -AcceptLiveCallAction -AcceptExperimentalOutbound
.\scripts\v0_run_scenario.ps1 -Scenario OutboundVideo -AcceptLiveCallAction -AcceptExperimentalOutbound
```

错误页面和风险词测试只能在无资金功能的普通测试页面进行。任何输入或错误点击都判定失败，并立即关闭无障碍服务。

## 日志和隐私

```powershell
.\scripts\v0_read_logs.ps1
.\scripts\v0_assert_log.ps1 -Required incoming_detected,incoming_allowed,accept_success
.\scripts\v0_collect_evidence.ps1
```

证据位于已忽略的 `artifacts/v0-evidence/`。`-IncludeUiDump` 会捕获当前可见文本，只能用于测试账号和可控页面。不要上传 `screen.png`、`ui-dump.xml`、真实白名单或原始日志。

## 常见失败

- `active_root_is_not_wechat`：锁屏来电由系统界面承载，当前安全合约不能点击；保持自动化关闭。
- `expected_contact_not_visible`：当前页面无法可靠验证联系人；不能改成昵称包含匹配。
- `clickable_accept_target_not_found`：接听标签没有可点击祖先，需要真实快照校准。
- `accessibility_service_not_connected`：服务未启用或被 HarmonyOS 回收。
- `local_reject_high_risk_keyword`：页面含风险词，停止测试并离开当前页面。
- `accept_button_not_found`：运行时节点与快照不一致，关闭自动化并重新采集，不要盲加标签。
