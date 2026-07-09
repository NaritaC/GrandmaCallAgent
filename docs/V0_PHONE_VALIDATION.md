# V0 手机验证指南

本文用于验证 V0 本地自动化脚本/原型，不验证 V1 Agent 能力。测试前建议使用备用手机或测试微信号，先只配置 1 个可信家属联系人。

## 安全警示

- 不要在含有真实资金风险的微信账号上直接首测。
- 测试期间不要打开微信支付、红包、转账、银行卡、删除消息等页面。
- 白名单只填写真实微信显示名，避免使用过短或容易撞名的昵称。
- 一键拨出是 UI 自动化原型，微信版本、语言、ROM 都可能导致失败；先在旁边观察屏幕测试。
- 如果本地日志出现 `local_reject_high_risk_keyword`、`outbound_rejected` 或误触迹象，立即关闭无障碍服务。

## 安装与授权

1. 用 Android Studio 打开 `GrandmaBridge/`。
2. 连接测试手机，安装运行 `GrandmaBridge`。
3. 打开 App，进入 V0 验证面板。
4. 在白名单输入框中填写允许自动接听的微信显示名，每行一个。
5. 点击“保存本地白名单”。
6. 点击“打开无障碍服务设置”，启用 `GrandmaBridge`。
7. 点击“打开通知使用权设置”，启用 `GrandmaBridge`。

## 自动接听验证

### 白名单语音来电

1. 让白名单联系人发起微信语音通话。
2. 观察手机是否只在微信来电页点击接听。
3. 回到 App 点击“刷新本地日志”。
4. 期望日志包含 `incoming_detected`、`incoming_allowed`、`accept_success`。

### 白名单视频来电

重复语音来电步骤，期望 `callType=video` 且能接听。

### 非白名单来电

1. 让非白名单联系人发起微信语音或视频通话。
2. 期望手机不自动接听。
3. 日志应包含 `incoming_rejected reason=contact_not_in_local_whitelist`。

### 高风险页面负向测试

1. 手动打开微信支付、红包、转账或删除相关页面。
2. 不要发起真实支付或删除操作。
3. 观察日志中不应出现 `accept_success` 或 `outbound_click_final_call`。
4. 如出现高风险页面关键词，期望日志包含 `local_reject_high_risk_keyword`。

## 一键拨出验证

1. 确认目标联系人已经在本地白名单内。
2. 在“一键拨出联系人”输入框填写该联系人微信显示名。
3. 点击“一键拨出微信语音”或“一键拨出微信视频”。
4. App 会打开微信并尝试按 UI 流程搜索联系人、进入聊天、打开音视频通话菜单。
5. 全程观察屏幕；如果进入错误联系人或错误页面，立即按返回键或关闭无障碍服务。
6. 期望日志按顺序出现 `outbound_requested`、`outbound_launch_wechat`、若干 `outbound_click_*` 或 `outbound_set_search_text`，最终出现 `outbound_click_final_call`。

## 日志获取

App 内点击“刷新本地日志”即可查看最近日志。也可以通过 ADB 读取：

```powershell
adb shell run-as com.grandmacallagent.bridge cat files/v0_actions.log
```

清空日志可点击 App 内“清空本地日志”。

## 失败排查

- `accessibility_service_not_connected`：无障碍服务未启用或被系统回收。
- `accept_button_not_found`：当前微信版本的接听按钮文案或节点层级未被识别，需要记录 UI 文本后调整匹配词。
- `contact_not_in_local_whitelist`：微信显示名和白名单文本不一致。
- `outbound_waiting` 多次出现：一键拨出找不到下一步按钮，需人工记录当前页面文本和按钮文案。
- `local_reject_high_risk_keyword`：页面含高风险关键词，自动化已停止，先确认是否进入了支付/转账/删除相关页面。
