# V0 验证记录模板

复制本模板到本地私有文件后填写。不要提交包含真实联系人昵称、手机号、聊天内容或原始 UI dump 的记录。

## 基本信息

- 日期：
- 测试人：
- GrandmaCallAgent commit：
- Android 机型/系统版本：
- 微信版本：
- 证据包目录：`artifacts/v0-evidence/<timestamp>/`
- 白名单联系人代号：如 `trusted_contact_1`
- 非白名单联系人代号：如 `unknown_contact_1`

## 测试结果

| 场景 | 期望结果 | 实际结果 | 日志关键字 | 结论 |
| --- | --- | --- | --- | --- |
| 自动接听总开关默认关闭 | 不自动接听 |  | `auto_answer_disabled` |  |
| 白名单语音来电 | 自动接听 |  | `incoming_allowed`, `accept_success` |  |
| 白名单视频来电 | 自动接听 |  | `callType=video`, `accept_success` |  |
| 非白名单来电 | 不自动接听 |  | `contact_not_in_local_whitelist` |  |
| 微信支付/红包/转账页面 | 不点击 |  | `local_reject_high_risk_keyword` 或无点击日志 |  |
| 一键拨出语音 | 只拨白名单联系人 |  | `outbound_requested`, `outbound_click_final_call` |  |
| 一键拨出视频 | 只拨白名单联系人 |  | `outbound_requested`, `outbound_click_final_call` |  |
| 错误页面/找不到按钮 | 停止并记录原因 |  | `outbound_waiting`, `outbound_failed`, `outbound_rejected` |  |

## 风险与结论

- 误触风险：
- 微信 UI 文案差异：
- 需要补充的按钮文本或页面信号：
- 是否达到 V0 完成标准：
