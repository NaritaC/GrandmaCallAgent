package com.grandmacallagent.bridge.accessibility

import android.accessibilityservice.AccessibilityService
import android.content.Context
import android.content.Intent
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityNodeInfo
import com.grandmacallagent.bridge.runtime.BridgeRuntime
import com.grandmacallagent.bridge.safety.SafetyGate
import com.grandmacallagent.bridge.speech.TtsSpeaker
import com.grandmacallagent.bridge.v0.LocalActionLogger
import com.grandmacallagent.bridge.v0.V0AutomationRuntime
import java.lang.ref.WeakReference

class GrandmaAccessibilityService : AccessibilityService() {
    private val mainHandler = Handler(Looper.getMainLooper())

    override fun onServiceConnected() {
        super.onServiceConnected()
        instance = WeakReference(this)
        V0AutomationRuntime.start(applicationContext)
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        if (event?.packageName?.toString() != WECHAT_PACKAGE) return
        val root = rootInActiveWindow ?: return
        processPendingOutbound(root)

        val texts = AccessibilityNodeUtils.collectTexts(root)
        if (!WeChatCallParser.looksLikeIncomingCall(texts)) return

        V0AutomationRuntime.onIncomingWeChatCall(
            context = applicationContext,
            contactName = WeChatCallParser.inferContactName(texts),
            callType = WeChatCallParser.inferCallType(texts),
            source = "accessibility",
        )
    }

    override fun onInterrupt() = Unit

    private fun acceptWeChatCallLocal(contactName: String?, source: String) {
        if (recentlyAccepted(contactName)) {
            LocalActionLogger.append(
                applicationContext,
                "accept_ignored",
                "source=$source contact=${contactName.orEmpty()} reason=recent_success_duplicate",
            )
            return
        }

        val root = rootInActiveWindow
        val packageName = root?.packageName?.toString()
        val texts = AccessibilityNodeUtils.collectTexts(root)
        val decision = SafetyGate.canClickAcceptWeChatCall(
            packageName = packageName,
            expectedContactName = contactName,
            visibleTexts = texts,
        )
        if (!decision.allowed) {
            LocalActionLogger.append(
                applicationContext,
                "accept_rejected",
                "source=$source contact=${contactName.orEmpty()} reason=${decision.reason}",
            )
            TtsSpeaker.speak("安全校验未通过，未自动接听。")
            return
        }

        val button = AccessibilityNodeUtils.findAcceptButton(root)
        if (button == null) {
            LocalActionLogger.append(applicationContext, "accept_failed", "reason=accept_button_not_found")
            return
        }

        val clicked = button.performAction(AccessibilityNodeInfo.ACTION_CLICK)
        val reason = if (clicked) "clicked_accept_call" else "click_failed"
        LocalActionLogger.append(
            applicationContext,
            if (clicked) "accept_success" else "accept_failed",
            "contact=${contactName.orEmpty()} reason=$reason",
        )
        if (clicked) {
            rememberAccepted(contactName)
            TtsSpeaker.speak("已接听微信来电。")
        }
    }

    private fun acceptWeChatCall(contactName: String?, commandId: String, taskId: String?) {
        val root = rootInActiveWindow
        val packageName = root?.packageName?.toString()
        val texts = AccessibilityNodeUtils.collectTexts(root)
        val decision = SafetyGate.canClickAcceptWeChatCall(
            packageName = packageName,
            expectedContactName = contactName,
            visibleTexts = texts,
        )
        if (!decision.allowed) {
            BridgeRuntime.reportActionResult(commandId, taskId, success = false, reason = decision.reason)
            TtsSpeaker.speak("安全校验未通过，未自动接听。")
            return
        }

        val button = AccessibilityNodeUtils.findAcceptButton(root)
        if (button == null) {
            BridgeRuntime.reportActionResult(commandId, taskId, success = false, reason = "accept_button_not_found")
            return
        }

        val clicked = button.performAction(AccessibilityNodeInfo.ACTION_CLICK)
        BridgeRuntime.reportActionResult(
            commandId = commandId,
            taskId = taskId,
            success = clicked,
            reason = if (clicked) "clicked_accept_call" else "click_failed",
        )
        if (clicked) {
            TtsSpeaker.speak("已接听微信来电。")
        }
    }

    private fun processPendingOutbound(root: AccessibilityNodeInfo) {
        val pending = pendingOutbound ?: return
        val now = SystemClock.elapsedRealtime()
        if (now - pending.startedAtMs > OUTBOUND_TIMEOUT_MS) {
            LocalActionLogger.append(
                applicationContext,
                "outbound_failed",
                "contact=${pending.contactName} callType=${pending.callType} reason=timeout",
            )
            pendingOutbound = null
            TtsSpeaker.speak("一键拨出超时，请查看本地日志。")
            return
        }
        if (now - pending.lastActionAtMs < OUTBOUND_STEP_INTERVAL_MS) return

        val packageName = root.packageName?.toString()
        val texts = AccessibilityNodeUtils.collectTexts(root)
        val decision = SafetyGate.canOperateWeChatWindow(packageName, texts)
        if (!decision.allowed) {
            LocalActionLogger.append(
                applicationContext,
                "outbound_rejected",
                "contact=${pending.contactName} reason=${decision.reason}",
            )
            pendingOutbound = null
            TtsSpeaker.speak("一键拨出已停止，原因是安全校验未通过。")
            return
        }

        pending.lastActionAtMs = now
        val acted = performOutboundStep(root, pending)
        if (!acted) {
            pending.failures += 1
            LocalActionLogger.append(
                applicationContext,
                "outbound_waiting",
                "contact=${pending.contactName} callType=${pending.callType} failures=${pending.failures}",
            )
            if (pending.failures >= MAX_OUTBOUND_FAILURES) {
                pendingOutbound = null
                TtsSpeaker.speak("一键拨出未找到下一步按钮，请查看日志并手动停止。")
            }
        }
    }

    private fun performOutboundStep(root: AccessibilityNodeInfo, pending: PendingOutboundCall): Boolean {
        val finalLabels = if (pending.callType == "video") VIDEO_CALL_LABELS else VOICE_CALL_LABELS
        val texts = AccessibilityNodeUtils.collectTexts(root)
        val targetVisible = texts.any { it.contains(pending.contactName, ignoreCase = true) }
        val joinedTexts = texts.joinToString(" ")
        val hasCallActionSignal = (finalLabels + MEDIA_CALL_MENU_LABELS).any {
            joinedTexts.contains(it, ignoreCase = true)
        }
        val hasChatScreenSignal = CHAT_SCREEN_LABELS.any {
            joinedTexts.contains(it, ignoreCase = true)
        }
        val canUseChatActions = targetVisible && (hasCallActionSignal || hasChatScreenSignal)

        if (canUseChatActions) {
            if (clickFirst(root, finalLabels, "outbound_click_final_call", pending)) {
                pendingOutbound = null
                TtsSpeaker.speak("已尝试发起微信通话。")
                return true
            }

            if (clickFirst(root, MEDIA_CALL_MENU_LABELS, "outbound_click_media_menu", pending)) return true
            if (clickFirst(root, MORE_MENU_LABELS, "outbound_click_more_menu", pending)) return true
        }

        if (targetVisible && !canUseChatActions) {
            return clickFirst(root, listOf(pending.contactName), "outbound_click_contact", pending)
        }

        val editor = AccessibilityNodeUtils.findEditableNode(root)
        if (editor != null) {
            val set = AccessibilityNodeUtils.setText(editor, pending.contactName)
            LocalActionLogger.append(
                applicationContext,
                if (set) "outbound_set_search_text" else "outbound_set_search_text_failed",
                "contact=${pending.contactName}",
            )
            return set
        }

        if (clickFirst(root, SEARCH_LABELS, "outbound_click_search", pending)) return true

        return false
    }

    private fun clickFirst(
        root: AccessibilityNodeInfo,
        labels: List<String>,
        category: String,
        pending: PendingOutboundCall,
    ): Boolean {
        val node = AccessibilityNodeUtils.findClickableByLabels(root, labels) ?: return false
        val clicked = node.performAction(AccessibilityNodeInfo.ACTION_CLICK)
        LocalActionLogger.append(
            applicationContext,
            if (clicked) category else "${category}_failed",
            "contact=${pending.contactName} callType=${pending.callType} labels=${labels.joinToString("|")}",
        )
        return clicked
    }

    companion object {
        private const val WECHAT_PACKAGE = "com.tencent.mm"
        private const val OUTBOUND_TIMEOUT_MS = 90_000L
        private const val OUTBOUND_STEP_INTERVAL_MS = 1_200L
        private const val ACCEPT_DUPLICATE_WINDOW_MS = 15_000L
        private const val MAX_OUTBOUND_FAILURES = 12
        private var instance: WeakReference<GrandmaAccessibilityService>? = null
        private var pendingOutbound: PendingOutboundCall? = null
        private var lastAcceptedContact: String? = null
        private var lastAcceptedAtMs: Long = 0L

        private val SEARCH_LABELS = listOf("搜索", "Search")
        private val MORE_MENU_LABELS = listOf("更多功能按钮", "更多功能", "更多", "+")
        private val MEDIA_CALL_MENU_LABELS = listOf("音视频通话", "语音和视频通话", "Voice/Video Call")
        private val VIDEO_CALL_LABELS = listOf("视频通话", "Video Call")
        private val VOICE_CALL_LABELS = listOf("语音通话", "Voice Call")
        private val CHAT_SCREEN_LABELS = listOf(
            "按住说话",
            "切换到键盘",
            "切换到语音",
            "发送",
            "表情",
            "更多功能按钮",
            "输入",
        )

        fun requestAcceptWeChatCall(contactName: String?, commandId: String, taskId: String?) {
            val service = instance?.get()
            if (service == null) {
                BridgeRuntime.reportActionResult(commandId, taskId, success = false, reason = "accessibility_service_not_connected")
                return
            }
            service.mainHandler.post {
                service.acceptWeChatCall(contactName, commandId, taskId)
            }
        }

        fun requestAcceptWeChatCallLocal(context: Context, contactName: String?, source: String) {
            val service = instance?.get()
            if (service == null) {
                LocalActionLogger.append(
                    context,
                    "accept_failed",
                    "source=$source contact=${contactName.orEmpty()} reason=accessibility_service_not_connected",
                )
                return
            }
            service.mainHandler.post {
                service.acceptWeChatCallLocal(contactName, source)
            }
        }

        fun requestMakeWeChatCall(context: Context, contactName: String, callType: String) {
            pendingOutbound = PendingOutboundCall(
                contactName = contactName,
                callType = callType,
                startedAtMs = SystemClock.elapsedRealtime(),
            )
            val launchIntent = context.packageManager.getLaunchIntentForPackage(WECHAT_PACKAGE)
            if (launchIntent == null) {
                LocalActionLogger.append(context, "outbound_failed", "reason=wechat_launch_intent_not_found")
                TtsSpeaker.speak("未找到微信，无法一键拨出。")
                pendingOutbound = null
                return
            }
            launchIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            context.startActivity(launchIntent)
            LocalActionLogger.append(context, "outbound_launch_wechat", "contact=$contactName callType=$callType")
        }

        fun cancelPendingOutbound(context: Context, reason: String): Boolean {
            val pending = pendingOutbound
            if (pending == null) {
                LocalActionLogger.append(context, "outbound_cancel_ignored", "reason=no_pending_outbound")
                return false
            }

            pendingOutbound = null
            LocalActionLogger.append(
                context,
                "outbound_cancelled",
                "contact=${pending.contactName} callType=${pending.callType} reason=$reason",
            )
            TtsSpeaker.speak("已停止一键拨出。")
            return true
        }

        private fun recentlyAccepted(contactName: String?): Boolean {
            val normalized = normalizeContact(contactName)
            if (normalized.isBlank()) return false
            val last = lastAcceptedContact ?: return false
            return last == normalized && SystemClock.elapsedRealtime() - lastAcceptedAtMs < ACCEPT_DUPLICATE_WINDOW_MS
        }

        private fun rememberAccepted(contactName: String?) {
            lastAcceptedContact = normalizeContact(contactName)
            lastAcceptedAtMs = SystemClock.elapsedRealtime()
        }

        private fun normalizeContact(contactName: String?): String {
            return contactName.orEmpty().filterNot { it.isWhitespace() }.lowercase()
        }
    }

    private data class PendingOutboundCall(
        val contactName: String,
        val callType: String,
        val startedAtMs: Long,
        var lastActionAtMs: Long = 0L,
        var failures: Int = 0,
    )
}
