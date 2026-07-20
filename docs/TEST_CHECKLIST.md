# 测试清单

## V0-A 离线与构建

- [x] `scripts/v0_self_test.ps1` 覆盖脚本语法、ADB 设备选择、快照分析、六场景门禁和场景拒绝路径。
- [x] Android 单元测试覆盖 `SafetyGate`、来电解析和拨出页面策略。
- [x] GitHub Actions run `29695704802` 使用 JDK 17、Android SDK 35 和 Gradle 8.9 通过单元测试、Lint 和 debug 构建。
- [ ] CI 使用 AAPT2 审计最终 debug APK：没有任何 `uses-permission`，编译后的无障碍配置只包含 `com.tencent.mm`。
- [ ] 本地或 CI 生成的可信 debug APK 已安装到目标手机。

## V0-A 目标与快照门禁

- [ ] 人工确认 `HUAWEI Pura 70 Ultra / HarmonyOS 4.2.0 / WeChat 8.0.76`。
- [ ] 测试联系人使用唯一合成微信备注，如 `V0TEST01`；未记录真实昵称或微信号。
- [ ] 快照采集时 GrandmaBridge、GKD 和其它自动化 Accessibility 服务均关闭。
- [ ] 未锁屏语音和视频快照通过。
- [ ] 锁屏亮屏语音和视频快照通过。
- [ ] 锁屏熄屏语音和视频快照通过。
- [ ] 六张截图已人工核对联系人、通话类型和页面状态。
- [ ] `scripts/v0_check_snapshot_gate.ps1 -ConfirmScreenshotsReviewed` 输出 `complete: True`、`valid: 6/6`。
- [ ] 快照和 UI XML 只保存在已忽略的本地目录，未上传 GitHub。

## V0-A 负向实测

- [ ] 自动接听总开关默认关闭。
- [ ] 总开关关闭时，白名单来电不接听并记录 `auto_answer_disabled`。
- [ ] 非白名单来电不接听并记录 `contact_not_in_local_whitelist`。
- [ ] 相似但不完全一致的备注不通过白名单。
- [ ] 非通话页面即使出现“接受/同意”也不点击。
- [ ] 非微信包名、未知通话类型、联系人不可见或页面歧义时默认拒绝。
- [ ] 普通测试页面出现“转账”等风险词时本地 `SafetyGate` 拒绝；不进入真实资金页面测试。

## V0-A 白名单实测

- [ ] 未锁屏语音来电自动接听并记录 `accept_success`。
- [ ] 未锁屏视频来电自动接听并记录 `callType=video`、`accept_success`。
- [ ] 锁屏亮屏语音和视频均自动接听。
- [ ] 锁屏熄屏语音和视频均自动接听。
- [ ] 每个场景都通过 `v0_run_scenario.ps1` 的必需/禁止日志断言。
- [ ] 多设备连接时未传 `-Serial` 会失败；指定序列号后只操作目标手机。
- [ ] 证据能追溯 commit、设备矩阵、屏幕状态和结果，但不包含私密联系人信息。

## V0.5 一键拨出

- [ ] 仅在 V0-A 通过后开始，并显式传入 `-AcceptExperimentalOutbound`。
- [ ] App 启动时 V0.5 外呼默认锁定；未勾选临时解锁时运行时记录 `experimental_outbound_disabled` 并拒绝。
- [ ] 只允许用户主动触发和本地白名单联系人。
- [ ] `OutboundWrongPage` 不输入、不点击。
- [ ] `HighRiskPage` 在无风险测试页面触发拒绝，且无搜索、输入、联系人或通话点击日志。
- [ ] `OutboundCancel` 能停止待拨任务。
- [ ] 一键拨出期间收到来电会取消待拨任务，之后不会恢复。
- [ ] `OutboundVoice` 和 `OutboundVideo` 只在逐页精确确认后执行。

## V1 服务端与联网（预留）

- [ ] 白名单、工具注册、任务日志和云端 `SafetyGate` 单元测试通过。
- [ ] 未注册工具、非通话工具和高风险 payload 默认拒绝。
- [ ] Bridge 只接受窄类型通话命令，不暴露通用点击或输入。
- [ ] 手机本地 `SafetyGate` 可否决任何云端允许结果。
- [ ] WebSocket 断线重连和设备心跳恢复。
- [ ] 心跳不包含聊天内容、联系人原文或凭据。

## 永久回归边界

- [ ] 微信支付、红包、转账、银行卡和验证码页面不会被点击。
- [ ] 消息发送、好友管理、聊天抓取和删除能力不存在。
- [ ] 普通聊天通知和系统电话不会触发微信接听。
- [ ] 微信、HarmonyOS 或设备版本变化后旧快照门禁不再复用。
