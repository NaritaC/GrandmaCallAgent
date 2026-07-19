# V0 手机验证指南

本文用于验证 V0 本地自动化脚本/原型，不验证 V1 Agent 能力。测试前建议使用备用手机或测试微信号，先只配置 1 个可信家属联系人。

建议用 [V0 验证记录模板](V0_TEST_RECORD_TEMPLATE.md) 记录每次真机结果。记录中只写联系人代号，不写真实微信昵称。

当前构建状态：提交 `ce7925e` 已在 GitHub Actions run `29695704802` 中通过 Gradle Wrapper 校验、Android 单元测试、Lint 和 debug APK 构建。微信来电识别、接听及拨出仍必须按本文在目标手机、ROM 和微信版本上验证，尚不能仅凭 CI 判定 V0 验收通过。

## 安全警示

- 不要在含有真实资金风险的微信账号上直接首测。
- 测试期间不要打开微信支付、红包、转账、银行卡、删除消息等页面。
- 白名单只填写真实微信显示名，避免使用过短或容易撞名的昵称。
- 一键拨出是 UI 自动化原型，微信版本、语言、ROM 都可能导致失败；先在旁边观察屏幕测试。
- 一键拨出前必须先让微信停在“微信/通讯录/发现/我”主标签页。若微信停在聊天页或其它页面，自动化应拒绝继续，绝不能向任意输入框写联系人。
- 如果本地日志出现 `local_reject_high_risk_keyword`、`outbound_rejected` 或误触迹象，先点击 App 内“停止一键拨出”；如仍无法确认安全，立即关闭无障碍服务。

## 安装与授权

1. 用 Android Studio 打开 `GrandmaBridge/`。
2. 先运行不需要手机、ADB 或 Android SDK 的脚本自测：

```powershell
.\scripts\v0_self_test.ps1
```

3. 如果准备使用命令行构建安装，再检查电脑侧环境：

```powershell
.\scripts\v0_host_preflight.ps1 -AssertReady
```

如果你只用 Android Studio 安装 App，可以跳过这一步。

4. 连接测试手机，安装运行 `GrandmaBridge`。在已配置 JDK 17+、Android SDK 35 和 ADB 的电脑上运行：

```powershell
.\scripts\v0_build_install.ps1
```

该脚本只构建、安装并启动 App，不会操作微信。

已有自己从本仓库 CI 或 Android Studio 生成并解压的 debug APK 时，可跳过本地构建：

```powershell
.\scripts\v0_build_install.ps1 -ApkPath C:\path\to\app-debug.apk
```

只使用本仓库 CI 或自己的 Android Studio 构建产物，不要安装来源不明的 APK。若脚本提示找不到 ADB，请在 Android Studio SDK Manager 中安装 Android SDK Platform-Tools；脚本会自动检查 `PATH`、SDK 环境变量和 Android Studio 默认 SDK 目录。

5. 如果命令行仍不具备 Android SDK 35，请用 Android Studio 打开 `GrandmaBridge/` 并从 IDE 运行 App。
6. 打开 App，进入 V0 验证面板。
7. 保持“启用白名单来电自动接听”关闭，先完成白名单和权限配置。
8. 在白名单输入框中填写允许自动接听的微信显示名，每行一个。
9. 点击“保存本地白名单”。
10. 点击“打开无障碍服务设置”，启用 `GrandmaBridge`。
11. 点击“打开通知使用权设置”，启用 `GrandmaBridge`。
12. 准备开始来电测试时，再回到 App 打开“启用白名单来电自动接听”。

如果 `adb devices` 显示多台已授权设备，给所有设备脚本加 `-Serial <deviceSerial>`，例如：

```powershell
.\scripts\v0_device_preflight.ps1 -Serial phone-001 -AssertReady
.\scripts\v0_run_scenario.ps1 -Serial phone-001 -Scenario WhitelistVoice
```

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

1. 使用备用测试账号，在普通、无资金功能的测试聊天页中让屏幕显示一条含“转账”的测试文本。不要进入微信支付、转账表单、红包、银行卡或删除确认页面。
2. 回到 GrandmaBridge，输入白名单测试联系人并点击任一一键拨出按钮。
3. 期望日志包含 `outbound_requested`、`outbound_launch_wechat` 和 `local_reject_high_risk_keyword`。
4. 日志不得出现 `outbound_click_search`、`outbound_set_search_text`、`outbound_click_contact`、`outbound_click_final_call` 或 `accept_success`。
5. 如果发生任何点击，立即点击“停止一键拨出”并关闭无障碍服务，本轮判定失败。

推荐直接运行：

```powershell
.\scripts\v0_run_scenario.ps1 -Scenario HighRiskPage
```

### 非通话“接受”按钮负向测试

1. 在测试账号中打开含“接受”“同意”等按钮但不是语音/视频来电的微信页面，例如普通邀请、好友验证或其它非通话确认页。
2. 不要点击真实确认动作。
3. 期望 App 不会自动点击该按钮。
4. 如触发接听流程，期望日志拒绝原因为 `local_reject_not_incoming_call_window`，且不出现 `accept_success`。

## 一键拨出验证

1. 确认目标联系人已经在本地白名单内，并使用备用微信号或可信测试联系人。
2. 手动打开微信，停在能同时看到至少三个主标签的首页；不要停在聊天、支付、红包、转账、银行卡或删除相关页面。
3. 回到 GrandmaBridge，在“一键拨出联系人”输入框填写与白名单完全一致的微信显示名。
4. 点击“一键拨出微信语音”或“一键拨出微信视频”。
5. App 只会在逐步确认微信首页、搜索输入框、精确联系人结果和目标聊天页后继续。
6. 全程观察屏幕；如果进入错误联系人或错误页面，立即回到 App 点击“停止一键拨出”，必要时关闭无障碍服务。
7. 期望日志按顺序出现 `outbound_requested`、`outbound_launch_wechat`、`outbound_click_search`、`outbound_set_search_text`、`outbound_click_contact`，最终出现 `outbound_click_final_call`。

### 错误页面负向验证

1. 让微信停在一个无风险的测试聊天页，不要使用支付、转账、红包或删除相关页面。
2. 回到 GrandmaBridge，输入白名单测试联系人并点击一键拨出。
3. 期望日志出现 `wechat_home_not_confirmed`，且不出现 `outbound_set_search_text`、`outbound_click_contact` 或 `outbound_click_final_call`。
4. 回到 GrandmaBridge 点击“停止一键拨出”。

可使用场景脚本：

```powershell
.\scripts\v0_run_scenario.ps1 -Scenario OutboundWrongPage
```

### 一键拨出停止验证

1. 点击“一键拨出微信语音”或“一键拨出微信视频”后，立即回到 App。
2. 点击“停止一键拨出”。
3. 期望日志包含 `outbound_cancel_requested` 和 `outbound_cancelled`。
4. 如果没有待停止任务，期望日志包含 `outbound_cancel_ignored reason=no_pending_outbound`。

可用脚本断言日志：

```powershell
.\scripts\v0_assert_log.ps1 -Required outbound_cancel_requested,outbound_cancelled
```

### 拨出期间收到来电

1. 在一键拨出尚未完成时，让白名单测试联系人发起微信来电。
2. 期望待拨任务先记录 `outbound_cancelled reason=incoming_call_detected`，之后再按白名单规则处理来电。
3. 通话结束后，原待拨任务不得恢复或继续点击。

## 日志获取

App 内点击“刷新本地日志”即可查看最近日志。也可以通过 ADB 读取：

```powershell
adb shell run-as com.grandmacallagent.bridge cat files/v0_actions.log
```

仓库也提供了辅助脚本：

```powershell
.\scripts\v0_host_preflight.ps1
.\scripts\v0_self_test.ps1
.\scripts\v0_host_preflight.ps1 -AssertReady
.\scripts\v0_build_install.ps1
.\scripts\v0_device_preflight.ps1
.\scripts\v0_device_preflight.ps1 -AssertReady
.\scripts\v0_read_logs.ps1
.\scripts\v0_clear_logs.ps1
.\scripts\v0_collect_evidence.ps1
.\scripts\v0_assert_log.ps1 -Required incoming_detected
.\scripts\v0_run_scenario.ps1 -Scenario WhitelistVoice
```

- `v0_self_test.ps1`：不连接手机，检查全部 PowerShell 脚本语法、Java 版本解析、ADB 路径/设备选择逻辑和所有场景的计划模式。
- `v0_host_preflight.ps1`：检查电脑侧 JDK 17+、ADB、Gradle Wrapper 和 Android 项目文件。加 `-AssertReady` 会在 CLI 构建安装条件不满足时失败。
- `v0_build_install.ps1`：默认用 Wrapper 构建 debug APK，再安装并启动 App；传入 `-ApkPath` 可安装已验证的预构建 APK。
- `v0_device_preflight.ps1`：检查设备连接、App/微信是否安装、无障碍和通知权限是否启用。加 `-AssertReady` 会在缺少 App、微信、无障碍或通知权限时失败。
- `v0_read_logs.ps1`：读取 `files/v0_actions.log`。
- `v0_clear_logs.ps1`：清空 `files/v0_actions.log`。
- `v0_collect_evidence.ps1`：把设备信息、App/微信版本、权限状态和 V0 本地日志保存到 `artifacts/v0-evidence/`。该目录已被 `.gitignore` 忽略，不要提交包含真实联系人昵称的证据包。
- `v0_assert_log.ps1`：检查日志中是否包含必需关键字、是否不包含禁止关键字；断言失败时抛出错误。
- 所有连接设备的 V0 脚本都支持 `-Serial <deviceSerial>`；未指定时只允许存在一台已授权设备。
- `v0_run_scenario.ps1`：按指定场景提示人工操作，默认先执行设备预检，然后自动清空日志、断言关键字并采集证据包。加 `-PlanOnly` 可只预览步骤，不运行 ADB。可用场景还包括 `OutboundWrongPage`，用于确认错误页面不会被输入或点击。

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
.\scripts\v0_run_scenario.ps1 -Scenario NonWhitelist
.\scripts\v0_run_scenario.ps1 -Scenario NonCallAccept
.\scripts\v0_run_scenario.ps1 -Scenario OutboundWrongPage
.\scripts\v0_run_scenario.ps1 -Scenario HighRiskPage
.\scripts\v0_run_scenario.ps1 -Scenario OutboundCancel
.\scripts\v0_run_scenario.ps1 -Scenario WhitelistVoice
.\scripts\v0_run_scenario.ps1 -Scenario WhitelistVideo
.\scripts\v0_run_scenario.ps1 -Scenario OutboundVoice
.\scripts\v0_run_scenario.ps1 -Scenario OutboundVideo
```

`WhitelistVoice`、`WhitelistVideo`、`OutboundVoice` 和 `OutboundVideo` 会产生真实通话动作，只在前面的负向场景全部通过后，使用备用手机、测试微信号并全程人工观察执行。

## 失败排查

- `accessibility_service_not_connected`：无障碍服务未启用或被系统回收。
- `accept_button_not_found`：当前微信版本的接听按钮文案或节点层级未被识别，需要记录 UI 文本后调整匹配词。
- `contact_not_in_local_whitelist`：微信显示名和白名单文本不一致。
- `outbound_waiting` 多次出现：一键拨出找不到下一步按钮，需人工记录当前页面文本和按钮文案。
- `wechat_home_not_confirmed`：微信不是已确认的主标签页；返回微信首页后重新开始，不要在当前页面强行重试。
- `target_result_not_visible_exact`：搜索结果没有与白名单显示名精确一致的联系人；停止任务并核对昵称，不要改成模糊匹配。
- `max_step_failures`：连续无法确认页面状态，任务已自动停止。
- `local_reject_high_risk_keyword`：页面含高风险关键词，自动化已停止；在 `HighRiskPage` 中这是期望结果，其它场景出现时不要继续，先退出当前页面并检查日志。
