# V0 验证记录模板

复制到本地私有文件后填写。不要提交真实昵称、微信号、手机号、截图、UI XML、通知内容或原始日志。

## 基本信息

- 日期与时区：
- 测试人：
- GrandmaCallAgent commit：
- 设备：`HUAWEI Pura 70 Ultra`
- 系统：`HarmonyOS 4.2.0`
- 微信：`8.0.76`
- 白名单代号：`trusted_test_1`
- 非白名单代号：`untrusted_test_1`
- 快照门禁路径：`artifacts/v0-call-snapshots/v0-a-gate.json`
- 证据目录：`artifacts/v0-evidence/<timestamp>/`

## Gate 1：只读快照

| 来电前状态 | 类型 | XML 分析 | 截图人工复核 | 失败原因 |
| --- | --- | --- | --- | --- |
| 未锁屏 | 语音 |  |  |  |
| 未锁屏 | 视频 |  |  |  |
| 锁屏亮屏 | 语音 |  |  |  |
| 锁屏亮屏 | 视频 |  |  |  |
| 锁屏熄屏 | 语音 |  |  |  |
| 锁屏熄屏 | 视频 |  |  |  |

- 门禁是否为 `complete: True / valid: 6/6`：
- `device-info.txt` 是否与“关于手机”一致：

## Gate 2：负向实测

| 场景 | 期望 | 实际 | 日志/结论 |
| --- | --- | --- | --- |
| 总开关关闭 | 不接听 |  | `auto_answer_disabled`，无 `accept_success` |
| 非白名单来电 | 不接听 |  | `contact_not_in_local_whitelist` |
| 非通话接受按钮 | 不点击 |  | 无 `accept_success` |

## Gate 3：白名单实测

| 来电前状态 | 类型 | 是否接听 | 关键日志 | 重复次数 |
| --- | --- | --- | --- | --- |
| 未锁屏 | 语音 |  |  |  |
| 未锁屏 | 视频 |  |  |  |
| 锁屏亮屏 | 语音 |  |  |  |
| 锁屏亮屏 | 视频 |  |  |  |
| 锁屏熄屏 | 语音 |  |  |  |
| 锁屏熄屏 | 视频 |  |  |  |

## 风险与结论

- 是否有误触或跨 App 行为：
- 是否发现网银/其它敏感 App 风险：
- HarmonyOS 后台限制或权限回收：
- 微信 UI 与分析器不一致之处：
- 是否达到 V0-A 完成标准：
- 若未达到，下一次只验证什么：

## V0.5（不计入 V0-A）

- `OutboundWrongPage`：
- `HighRiskPage`：
- `OutboundCancel`：
- `OutboundVoice`：
- `OutboundVideo`：
