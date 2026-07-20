# 可参考项目调研

首次调研：2026-07-09；路线复核：2026-07-20

调研目标：在 GitHub 上查找与 GrandmaCallAgent 相近的开源项目，重点关注 Android 无障碍自动化、微信自动化、通话自动接听、手机 Agent、WebSocket 设备桥和 Android Agent 评测框架。

## 结论

没有发现一个完整覆盖“微信语音/视频来电 + 白名单联系人 + 云端 SafetyGate + Android WebSocket Bridge + 设备心跳”的同类开源项目。可参考项目主要分为三类：

1. 系统电话自动接听项目：接近“自动接听”动作，但多为旧 Android 电话 API，不能直接用于微信通话。
2. 微信 AccessibilityService 自动化项目：接近微信 UI 自动化，但大多面向加好友、发消息、红包、营销等高风险动作，只能借鉴 UI 节点识别和无障碍服务工程结构。
3. Android Agent / UI 自动化框架：适合做测试、UI 探索、回归验证或未来 Agent 任务建模，但不适合直接放进老人手机端长期运行。

## 评分口径

评分是“对 GrandmaCallAgent 第一阶段的可复用价值”，不是项目质量评分。

| 分数 | 含义 |
| --- | --- |
| 5 星 | 可直接复用核心模块或工程结构，改造成本低 |
| 4 星 | 技术路线高度相关，可复用较多实现思路 |
| 3 星 | 可参考关键模式，但需要重写或强约束安全边界 |
| 2 星 | 只适合参考局部思路、测试方法或历史实现 |
| 1 星 | 仅作为背景材料，不建议复用代码 |

## 项目清单

| 项目 | 类型 | 主要功能 | 可复用评分 | 可复用点 | 风险/限制 |
| --- | --- | --- | --- | --- | --- |
| [gkd-kit/gkd](https://github.com/gkd-kit/gkd) | Android 无障碍规则与快照工具 | Kotlin Android App，提供 UI 快照、选择器、本地订阅和受作用域约束的自动点击规则。 | 5 星 | 可直接作为 V0 独立校准工具：先抓真实微信来电快照，再验证联系人、通话类型和接听节点的组合规则；无需先把猜测写进 GrandmaBridge。 | GPL-3.0，README 另有非商业使用说明；不直接复制或打包源码。规则仍有误触风险，必须限定 App/版本/Activity、单次动作和排除条件。 |
| [369219053/wechat-auto-apk](https://github.com/369219053/wechat-auto-apk) | 微信无障碍自动化 | 基于 Android 原生 AccessibilityService 的微信私域自动化，包含通讯录同步、好友搜索、批量文字消息、前台服务、权限管理、通知和本地存储。 | 4 星 | 近期 Android 原生无障碍工程结构、微信 UI resource-id/content-desc 定位、任务队列、前台服务、权限引导。 | 业务目标包含私信/营销，和本项目安全边界冲突；不能复用发送消息、通讯录采集等行为，只能借鉴底层 UI 定位和服务保活模式。 |
| [coder-pig/WechatHelper](https://github.com/coder-pig/WechatHelper) | 微信无障碍自动化 | Kotlin 编写，使用 AccessibilityService 自动执行微信加好友、拉群、朋友圈点赞等重复操作。 | 3 星 | Kotlin + AccessibilityService 项目结构、节点遍历、点击动作封装、微信页面状态判断。 | 已较旧，只保证作者设备可用；动作类型多为本项目禁止的社交/营销动作。 |
| [Liar1995/AccessibilityDemo](https://github.com/Liar1995/AccessibilityDemo) | 微信自动回复示例 | Android 微信自动回复消息示例。 | 2 星 | 可参考通知/窗口事件触发后的微信页面识别与输入控件定位。 | 自动回复属于本项目禁止动作；项目较小且较旧，只适合作为无障碍入门参考。 |
| [jp1017/AutoAnswerCalls](https://github.com/jp1017/AutoAnswerCalls) | 系统电话自动接听 | Android 自动接听电话、自动回复短信。 | 2 星 | 电话状态监听、自动接听的历史实现、权限声明和服务组织方式。 | 面向系统电话，不是微信 VoIP；2016 年左右的实现，现代 Android 通话权限和限制已经变化；短信自动回复不应进入本项目第一阶段。 |
| [sidd-shah/Auto-Answering-Machine-for-Android](https://github.com/sidd-shah/Auto-Answering-Machine-for-Android) | 系统电话答录机 | 来电 15 秒未接后自动接听，录音，30 秒后挂断，并通知用户查看留言。 | 2 星 | “延迟接听/自动结束/结果通知”的任务状态机概念。 | 代码很旧，只有少量提交；录音和自动挂断不在当前阶段范围；不能用于微信语音/视频通话。 |
| [steghio/auto-answer](https://github.com/steghio/auto-answer) | 系统电话自动接听 | Android Froyo+ 自动接听系统电话，README 明确标注 unsupported，且说明 Android 5+ 不工作。 | 1 星 | 仅可了解早期 Android 自动接听思路。 | 不支持现代 Android，GPL-3.0 对代码复用有限制，不建议复用。 |
| [openatx/uiautomator2](https://github.com/openatx/uiautomator2) | Android UI 自动化测试 | Python 客户端通过 HTTP 调用设备端 UiAutomator 服务，支持 XPath、设备信息、App 启动、控件点击等。 | 4 星 | 真机调试和回归测试工具；可用于分析微信来电页面节点、验证接听按钮文本和 resource-id。 | 依赖 ADB/设备端自动化服务，不适合放在老人手机端作为常驻运行方案。 |
| [appium/appium-uiautomator2-server](https://github.com/appium/appium-uiautomator2-server) | Android 自动化服务端 | Appium 的 UiAutomator2/UiObject2 设备端 server，基于 Netty 接收命令并执行 Android UI 自动化。 | 3 星 | 设备端命令服务、选择器、XPath、测试覆盖和构建方式可参考。 | 主要用于测试，不适合生产安装在老人手机上；架构比第一阶段需求重。 |
| [honeynet/droidbot](https://github.com/honeynet/droidbot) | Android UI 探索/测试 | 轻量 Android 测试输入生成器，可生成 UI Transition Graph，支持 Accessibility、脚本化输入和 UI 结构分析。 | 3 星 | 可用于探索微信来电 UI 状态机、生成测试路径、沉淀 UI 结构样本。 | 偏测试研究工具，需要 ADB 和宿主机；不适合直接作为 GrandmaBridge 的运行时。 |
| [MobileLLM/AutoDroid](https://github.com/MobileLLM/AutoDroid) | LLM 手机任务自动化 Agent | 基于 DroidBot 的 LLM 手机任务自动化系统，结合 UI 表示、记忆注入和 LLM 推理。 | 2 星 | 可参考未来“任务规划”和 UI 表示方式。 | README 明确提醒可能执行非预期动作；依赖 ADB 和 GPT API；和本项目的强 SafetyGate、窄动作空间方向不同。 |
| [google-research/android_world](https://github.com/google-research/android_world) | Android Agent 环境/基准 | Android 自主 Agent 环境和 benchmark，包含 116 个任务、20 个 App、可扩展任务和 Docker 支持。 | 2 星 | 可用于未来评测 Agent 安全策略、动作空间、任务完成判定。 | 面向模拟器 benchmark，不是老人手机端产品实现；不覆盖微信来电。 |
| [THUDM/Android-Lab](https://github.com/THUDM/Android-Lab) | Android Agent 环境/基准 | Android agent framework，提供操作环境、可复现 benchmark、138 个任务和评测流程。 | 2 星 | 可参考评测指标、任务组织和 Android Agent 实验框架。 | 偏研究和评测，不直接解决微信来电接听。 |
| [UbiquitousLearning/DroidCall](https://github.com/UbiquitousLearning/DroidCall) | Android Intent 调用数据集 | 面向 Android Intent invocation 的训练/测试数据集和函数预定义/生成流程。 | 2 星 | 可参考“工具/函数预定义 -> JSON 描述 -> 评测”的 schema 组织方式。 | 关注 Android Intent，不覆盖 Accessibility 点击和微信 VoIP 来电；更多适合未来自然语言工具调用。 |
| [K9i-0/ccpocket](https://github.com/K9i-0/ccpocket) | 手机端 Agent 控制桥 | 移动端通过自托管 Bridge Server 控制 Codex/Claude，支持 WebSocket、审批流、离线恢复、文件/Git 操作。 | 3 星 | WebSocket bridge、自托管连接、移动端审批流、断线恢复、权限审批体验。 | 不是 Android 无障碍项目；控制对象是代码 Agent，不是手机 UI。 |
| [Genymobile/scrcpy](https://github.com/Genymobile/scrcpy) | Android 屏幕镜像/远控 | 通过 USB/TCP/IP 镜像并控制 Android 设备，低延迟、无需 root、无需在设备安装 App。 | 2 星 | 可作为开发/家属远程排障和观察微信来电 UI 的辅助工具。 | 需要 ADB/调试链路，不适合老人手机的无感常驻自动接听。 |
| [clearw5/Auto.js](https://github.com/hyb1996/Auto.js) | Android 脚本自动化平台 | Android 上的 JavaScript 自动化/工作流 IDE，主题包括 automation、uiautomator、tasker。 | 1 星 | 可了解 Android 脚本自动化生态。 | 仓库已归档且源码被删除；License 有非商业限制；不适合作为代码依赖。 |

## 对 GrandmaCallAgent 的建议

### 第一阶段可借鉴

1. 优先用 GKD 或本仓库只读 ADB 脚本采集真实快照，再决定选择器；GKD 只作独立校准，不作为运行时依赖。
2. 从 `369219053/wechat-auto-apk` 和 `coder-pig/WechatHelper` 学习微信 UI 节点定位、窗口状态判断、前台服务和权限引导，但只保留通话接听相关模式。
3. 用 `openatx/uiautomator2` 或 `appium/appium-uiautomator2-server` 做真机调试和回归测试，记录不同微信版本下的接听按钮文本、content-desc、resource-id 和窗口层级。
4. 借鉴系统电话自动接听项目的“事件 -> 安全判断 -> 执行动作 -> 结果通知”状态机，不复用旧电话 API。
5. 借鉴 `ccpocket` 的 WebSocket bridge、断线恢复和审批流设计，但 GrandmaCallAgent 的动作空间必须更窄。

### 明确不应复用

1. 不复用自动发消息、自动加好友、拉群、朋友圈采集、红包、支付、营销私信等逻辑。
2. 不引入通用 LLM “任意 UI 点击”能力到第一阶段运行时。
3. 不把 uiautomator2、Appium、DroidBot 这类 ADB/测试依赖放进老人手机常驻端。
4. 不复用旧系统电话自动接听项目中的已失效或高权限通话 API。

## 优先参考顺序

| 优先级 | 项目 | 用途 |
| --- | --- | --- |
| P0 | `gkd-kit/gkd` | 固定版本微信来电快照、选择器和单动作可行性校准 |
| P0 | `369219053/wechat-auto-apk`、`coder-pig/WechatHelper` | Android 原生 AccessibilityService 和微信 UI 定位参考 |
| P0 | `openatx/uiautomator2` | 真机节点分析和自动化回归测试 |
| P1 | `K9i-0/ccpocket` | WebSocket bridge、重连和远程审批体验参考 |
| P1 | `honeynet/droidbot` | 微信来电 UI 状态探索和测试路径生成 |
| P2 | `jp1017/AutoAnswerCalls`、`sidd-shah/Auto-Answering-Machine-for-Android` | 自动接听状态机历史参考 |
| P2 | `AndroidWorld`、`Android-Lab`、`AutoDroid`、`DroidCall` | 后续 Android Agent 评测和工具 schema 参考 |

## 检索关键词记录

- `android auto answer call`
- `android AccessibilityService WeChat automation`
- `WeChat AccessibilityService Android`
- `WeChat auto reply Android accessibility`
- `android phone agent websocket`
- `Android agent benchmark`
- `Android UiAutomator2 Python wrapper`
- `mobile agent websocket bridge`
