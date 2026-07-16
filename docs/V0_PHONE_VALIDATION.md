# V0 手机验证指南

本文用于验证 V0 本地自动化脚本/原型，不验证 V1 Agent 能力。测试前建议使用备用手机或测试微信号，先只配置 1 个可信家属联系人。

建议用 [V0 验证记录模板](V0_TEST_RECORD_TEMPLATE.md) 记录每次真机结果。记录中只写联系人代号，不写真实微信昵称。

## 安全警示

- 不要在含有真实资金风险的微信账号上直接首测。
- 测试期间不要打开微信支付、红包、转账、银行卡、删除消息等页面。
- 白名单只填写真实微信显示名，避免使用过短或容易撞名的昵称。
- 一键拨出是 UI 自动化原型，微信版本、语言、ROM 都可能导致失败；先在旁边观察屏幕测试。
- 如果本地日志出现 `local_reject_high_risk_keyword`、`outbound_rejected` 或误触迹象，先点击 App 内“停止一键拨出”；如仍无法确认安全，立即关闭无障碍服务。

## 安装与授权

1. 用 Android Studio 打开 `GrandmaBridge/`。
2. 连接测试手机，安装运行 `GrandmaBridge`。也可以在已配置 Gradle 和 ADB 的电脑上运行：

```powershell
.\scripts\v0_build_install.ps1
```

该脚本只构建、安装并启动 App，不会操作微信。

3. 如果脚本提示没有 Gradle wrapper 或全局 `gradle`，请先用 Android Studio 打开 `GrandmaBridge/` 并从 IDE 运行 App。
4. 打开 App，进入 V0 验证面板。
5. 保持“启用白名单来电自动接听”关闭，先完成白名单和权限配置。
6. 在白名单输入框中填写允许自动接听的微信显示名，每行一个。
7. 点击“保存本地白名单”。
8. 点击“打开无障碍服务设置”，启用 `GrandmaBridge`。
9. 点击“打开通知使用权设置”，启用 `GrandmaBridge`。
10. 准备开始来电测试时，再回到 App 打开“启用白名单来电自动接听”。

## 自动接听验证

### 白名单语音来电

1. 确认 App 内“启用白名单来电自动接听”已经打开。
2. 让白名单联系人发起微信语音通话。
3. 观察手机是否只在微信来电页点击接听。
4. 回到 App 点击“刷新本地日志”。
5. 期望日志包含 `incoming_detected`、`incoming_allowed`、`accept_success`。

可用脚本断言日志：

```powershell
.\scripts\v0_assert_log.ps1 -Required incoming_detected,incoming_allowed,accept_success
```

也可以用场景化脚本完成清日志、人工步骤提示、断言和证据采集：

```powershell
.\scripts\v0_run_scenario.ps1 -Scenario WhitelistVoice
```

### 自动接听总开关

1. 关闭“启用白名单来电自动接听”。
2. 让白名单联系人发起微信语音或视频通话。
3. 期望手机不自动接听。
4. 日志应包含 `incoming_rejected reason=auto_answer_disabled`。

可用脚本断言日志：

```powershell
.\scripts\v0_assert_log.ps1 -Required auto_answer_disabled -Forbidden accept_success
```

### 白名单视频来电

重复语音来电步骤，期望 `callType=video` 且能接听。

### 非白名单来电

1. 让非白名单联系人发起微信语音或视频通话。
2. 期望手机不自动接听。
3. 日志应包含 `incoming_rejected reason=contact_not_in_local_whitelist`。

可用脚本断言日志：

```powershell
.\scripts\v0_assert_log.ps1 -Required contact_not_in_local_whitelist -Forbidden accept_success
```

### 高风险页面负向测试

1. 手动打开微信支付、红包、转账或删除相关页面。
2. 不要发起真实支付或删除操作。
3. 观察日志中不应出现 `accept_success` 或 `outbound_click_final_call`。
4. 如出现高风险页面关键词，期望日志包含 `local_reject_high_risk_keyword`。

### 非通话“接受”按钮负向测试

1. 在测试账号中打开含“接受”“同意”等按钮但不是语音/视频来电的微信页面，例如普通邀请、好友验证或其它非通话确认页。
2. 不要点击真实确认动作。
3. 期望 App 不会自动点击该按钮。
4. 如触发接听流程，期望日志拒绝原因为 `local_reject_not_incoming_call_window`，且不出现 `accept_success`。

## 一键拨出验证

1. 确认目标联系人已经在本地白名单内。
2. 在“一键拨出联系人”输入框填写该联系人微信显示名。
3. 点击“一键拨出微信语音”或“一键拨出微信视频”。
4. App 会打开微信并尝试按 UI 流程搜索联系人、进入聊天、打开音视频通话菜单。
5. 全程观察屏幕；如果进入错误联系人或错误页面，立即回到 App 点击“停止一键拨出”，必要时按返回键或关闭无障碍服务。
6. 期望日志按顺序出现 `outbound_requested`、`outbound_launch_wechat`、若干 `outbound_click_*` 或 `outbound_set_search_text`，最终出现 `outbound_click_final_call`。

### 一键拨出停止验证

1. 点击“一键拨出微信语音”或“一键拨出微信视频”后，立即回到 App。
2. 点击“停止一键拨出”。
3. 期望日志包含 `outbound_cancel_requested` 和 `outbound_cancelled`。
4. 如果没有待停止任务，期望日志包含 `outbound_cancel_ignored reason=no_pending_outbound`。

可用脚本断言日志：

```powershell
.\scripts\v0_assert_log.ps1 -Required outbound_cancel_requested,outbound_cancelled
```

## 日志获取

App 内点击“刷新本地日志”即可查看最近日志。也可以通过 ADB 读取：

```powershell
adb shell run-as com.grandmacallagent.bridge cat files/v0_actions.log
```

仓库也提供了辅助脚本：

```powershell
.\scripts\v0_build_install.ps1
.\scripts\v0_device_preflight.ps1
.\scripts\v0_read_logs.ps1
.\scripts\v0_clear_logs.ps1
.\scripts\v0_collect_evidence.ps1
.\scripts\v0_assert_log.ps1 -Required incoming_detected
.\scripts\v0_run_scenario.ps1 -Scenario WhitelistVoice
```

- `v0_build_install.ps1`：构建 debug APK、安装到连接的 Android 设备并启动 App。
- `v0_device_preflight.ps1`：检查设备连接、App 是否安装、无障碍和通知权限是否启用。
- `v0_read_logs.ps1`：读取 `files/v0_actions.log`。
- `v0_clear_logs.ps1`：清空 `files/v0_actions.log`。
- `v0_collect_evidence.ps1`：把设备信息、App/微信版本、权限状态和 V0 本地日志保存到 `artifacts/v0-evidence/`。该目录已被 `.gitignore` 忽略，不要提交包含真实联系人昵称的证据包。
- `v0_assert_log.ps1`：检查日志中是否包含必需关键字、是否不包含禁止关键字；断言失败时抛出错误。
- `v0_run_scenario.ps1`：按指定场景提示人工操作，自动清空日志、断言关键字并采集证据包。加 `-PlanOnly` 可只预览步骤，不运行 ADB。可用场景包括 `AutoAnswerOff`、`WhitelistVoice`、`WhitelistVideo`、`NonWhitelist`、`HighRiskPage`、`NonCallAccept`、`OutboundVoice`、`OutboundVideo`、`OutboundCancel`。

如果需要校准微信 UI 文本，可以在安全页面上额外运行：

```powershell
.\scripts\v0_collect_evidence.ps1 -IncludeUiDump
```

`-IncludeUiDump` 会导出当前屏幕可见文本，可能包含聊天内容或联系人昵称，只能在测试账号和可控页面使用。

清空日志可点击 App 内“清空本地日志”。

## 建议验证节奏

1. 每个关键场景前先清空 V0 日志。
2. 执行一个场景后先在 App 内刷新日志，确认关键字是否出现。
3. 再运行 `.\scripts\v0_collect_evidence.ps1` 采集证据包。
4. 将证据包目录名写入本地验证记录，不要把真实日志内容写入 `docs/PROJECT_LOG.md`。

如果使用场景化脚本，推荐顺序是：

```powershell
.\scripts\v0_run_scenario.ps1 -Scenario AutoAnswerOff
.\scripts\v0_run_scenario.ps1 -Scenario WhitelistVoice
.\scripts\v0_run_scenario.ps1 -Scenario WhitelistVideo
.\scripts\v0_run_scenario.ps1 -Scenario NonWhitelist
.\scripts\v0_run_scenario.ps1 -Scenario NonCallAccept
.\scripts\v0_run_scenario.ps1 -Scenario OutboundCancel
```

`HighRiskPage`、`OutboundVoice`、`OutboundVideo` 风险更高，只在备用手机、测试微信号和人工观察下执行。

## 失败排查

- `accessibility_service_not_connected`：无障碍服务未启用或被系统回收。
- `accept_button_not_found`：当前微信版本的接听按钮文案或节点层级未被识别，需要记录 UI 文本后调整匹配词。
- `contact_not_in_local_whitelist`：微信显示名和白名单文本不一致。
- `outbound_waiting` 多次出现：一键拨出找不到下一步按钮，需人工记录当前页面文本和按钮文案。
- `local_reject_high_risk_keyword`：页面含高风险关键词，自动化已停止，先确认是否进入了支付/转账/删除相关页面。
