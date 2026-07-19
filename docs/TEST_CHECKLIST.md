# 测试清单

## V1 服务端单元测试（预留）

- [ ] 白名单联系人允许 `accept_call`。
- [ ] 非白名单联系人拒绝 `accept_call`。
- [ ] 非微信包名拒绝。
- [ ] 非 `voice`/`video` 通话类型拒绝。
- [ ] `payment`、`transfer`、`delete_message` 等高风险动作拒绝。
- [ ] payload 中出现“支付/转账/红包/删除”等关键词时拒绝。
- [ ] 任务日志能记录允许、拒绝和执行结果。

## V1 Android 联网测试（预留）

- [ ] App 能保存 WebSocket 地址。
- [ ] App 能打开无障碍服务设置页。
- [ ] App 能打开通知使用权设置页。
- [ ] 启动后能向服务端发送 `heartbeat`。
- [ ] 通知监听能识别微信语音来电通知。
- [ ] 通知监听能识别微信视频来电通知。
- [ ] 无障碍服务能识别微信来电窗口。
- [ ] 收到云端 `accept_call` 命令后，当前窗口是白名单联系人来电时能点击接听。
- [ ] 当前窗口不是微信时不点击。
- [ ] 当前窗口包含支付/转账/删除等关键词时不点击。

## V0 本地自动化验证

- [ ] App 能保存本地白名单。
- [ ] 自动接听总开关默认关闭。
- [x] `scripts/v0_self_test.ps1` 通过，确认脚本语法、ADB 设备选择和全部场景计划可执行。
- [x] Android 单元测试通过，覆盖 `SafetyGate`、来电解析和拨出页面策略（GitHub Actions run `29694600893`）。
- [x] CI 使用 JDK 17、Android SDK 35 和 Gradle 8.9 成功执行 debug APK 构建，并上传测试报告与未签名 APK（GitHub Actions run `29694600893`）。
- [ ] 自动接听总开关关闭时，白名单来电也不会自动接听，并记录 `auto_answer_disabled`。
- [ ] 如使用命令行安装，`scripts/v0_host_preflight.ps1 -AssertReady` 通过，确认 JDK 17+、ADB 和仓库 Gradle Wrapper 就绪。
- [ ] `scripts/v0_build_install.ps1` 能构建、安装并启动 App，或使用 `-ApkPath` 安装本仓库 CI/Android Studio 生成的可信 APK。
- [ ] `scripts/v0_device_preflight.ps1 -AssertReady` 通过，确认 App、微信、无障碍服务和通知监听权限均就绪。
- [ ] App 能显示和清空本地日志。
- [ ] 白名单联系人微信语音来电能自动接听，并记录 `accept_success`。
- [ ] 白名单联系人微信视频来电能自动接听，并记录 `callType=video`。
- [ ] 非白名单联系人来电不会自动接听，并记录拒绝原因。
- [ ] 一键拨出只允许白名单联系人。
- [ ] 相似但不完全一致的联系人显示名不会通过精确联系人校验。
- [ ] 微信不在主标签页时，一键拨出记录 `wechat_home_not_confirmed`，且不输入文字、不点击联系人或通话按钮。
- [ ] 一键拨出启动后，App 内“停止一键拨出”能取消 pending outbound 并记录 `outbound_cancelled`。
- [ ] 一键拨出期间收到微信来电会先取消待拨任务，通话结束后不会恢复旧任务。
- [ ] 一键拨出错误页面时能停止并记录失败原因。
- [ ] `HighRiskPage` 在普通测试聊天显示“转账”文本时触发 `local_reject_high_risk_keyword`，且搜索、输入、联系人及通话点击日志全部不存在；不要进入真实资金或删除页面测试。
- [ ] 非通话页面即使出现“接受”按钮，也不会被当成微信来电接听页。
- [ ] 使用 `scripts/v0_assert_log.ps1` 对关键场景执行必需/禁止日志关键字断言。
- [ ] 使用 `scripts/v0_run_scenario.ps1` 跑至少 `AutoAnswerOff`、`WhitelistVoice`、`WhitelistVideo`、`NonWhitelist`、`NonCallAccept`、`OutboundCancel` 六个场景。
- [ ] 使用 `scripts/v0_run_scenario.ps1 -Scenario OutboundWrongPage` 验证错误页面负向边界。
- [ ] 多设备连接时，未传 `-Serial` 会失败；传入目标序列号后只操作指定手机。
- [ ] 使用 `scripts/v0_collect_evidence.ps1` 采集验证证据包，确认权限状态、微信版本和 V0 日志可追溯。

## V1 端到端测试（预留）

- [ ] 白名单联系人微信语音来电：自动接听，服务端记录 `command_sent` 和 `action_result`。
- [ ] 白名单联系人微信视频来电：自动接听，服务端记录成功。
- [ ] 非白名单联系人来电：不接听，服务端记录 `blocked`。
- [ ] 断网后恢复：WebSocket 自动重连，心跳恢复。
- [ ] 服务端重启后：Android 端自动重连。

## 回归边界

- [ ] 微信支付页不会被点击。
- [ ] 微信红包页不会被点击。
- [ ] 聊天消息删除弹窗不会被点击。
- [ ] 普通聊天通知不会触发接听。
- [ ] 系统电话来电不会触发微信接听工具。
