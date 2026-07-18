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
import com.grandmacallagent.bridge.v0.LocalWhitelistStore
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
        val texts = AccessibilityNodeUtils.collectTexts(root)
        if (WeChatCallParser.looksLikeIncomingCall(texts)) {
            cancelPendingOutboundSilently("incoming_call_detected")
            V0AutomationRuntime.onIncomingWeChatCall(
                context = applicationContext,
                contactName = WeChatCallParser.inferContactName(texts),
                callType = WeChatCallParser.inferCallType(texts),
                source = "accessibility",
            )
            return
        }

        processPendingOutbound(root)
    }

    override fun onInterrupt() {
        cancelPendingOutboundSilently("accessibility_service_interrupted")
    }

    override fun onDestroy() {
        cancelPendingOutboundSilently("accessibility_service_destroyed")
        if (instance?.get() === this) {
            instance = null
        }
        super.onDestroy()
    }

    private fun cancelPendingOutboundSilently(reason: String) {
        val pending = pendingOutbound ?: return
        pendingOutbound = null
        LocalActionLogger.append(
            applicationContext,
            "outbound_cancelled",
            "contact=${pending.contactName} callType=${pending.callType} reason=$reason",
        )
    }

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
        val result = performOutboundStep(root, pending)
        if (result.acted) {
            pending.failures = 0
            return
        }

        pending.failures += 1
        LocalActionLogger.append(
            applicationContext,
            "outbound_waiting",
            "contact=${pending.contactName} callType=${pending.callType} stage=${pending.stage} " +
                "failures=${pending.failures} reason=${result.reason}",
        )
        if (pending.failures >= MAX_OUTBOUND_FAILURES) {
            LocalActionLogger.append(
                applicationContext,
                "outbound_failed",
                "contact=${pending.contactName} callType=${pending.callType} stage=${pending.stage} " +
                    "reason=max_step_failures lastReason=${result.reason}",
            )
            pendingOutbound = null
            TtsSpeaker.speak("一键拨出未确认下一步，已自动停止。")
        }
    }

    private fun performOutboundStep(
        root: AccessibilityNodeInfo,
        pending: PendingOutboundCall,
    ): OutboundStepResult {
        return when (pending.stage) {
            OutboundStage.OPEN_SEARCH -> openWechatSearch(root, pending)
            OutboundStage.ENTER_SEARCH -> enterSearchContact(root, pending)
            OutboundStage.SELECT_CONTACT -> selectSearchResult(root, pending)
            OutboundStage.OPEN_CALL_MENU -> openCallMenu(root, pending)
            OutboundStage.OPEN_MEDIA_MENU -> openMediaMenu(root, pending)
            OutboundStage.SELECT_CALL_TYPE -> selectCallType(root, pending)
        }
    }

    private fun openWechatSearch(
        root: AccessibilityNodeInfo,
        pending: PendingOutboundCall,
    ): OutboundStepResult {
        val texts = AccessibilityNodeUtils.collectTexts(root)
        if (!OutboundUiPolicy.isWeChatHome(texts)) {
            return OutboundStepResult(false, "wechat_home_not_confirmed")
        }

        if (!clickFirstExact(root, SEARCH_LABELS, "outbound_click_search", pending)) {
            return OutboundStepResult(false, "search_button_not_found")
        }
        advanceOutboundStage(pending, OutboundStage.ENTER_SEARCH)
        return OutboundStepResult(true, "search_opened")
    }

    private fun enterSearchContact(
        root: AccessibilityNodeInfo,
        pending: PendingOutboundCall,
    ): OutboundStepResult {
        val editor = AccessibilityNodeUtils.findEditableNodeByLabels(root, SEARCH_LABELS)
            ?: return OutboundStepResult(false, "search_input_not_confirmed")
        val set = AccessibilityNodeUtils.setText(editor, pending.contactName)
        LocalActionLogger.append(
            applicationContext,
            if (set) "outbound_set_search_text" else "outbound_set_search_text_failed",
            "contact=${pending.contactName}",
        )
        if (!set) return OutboundStepResult(false, "search_text_set_failed")

        advanceOutboundStage(pending, OutboundStage.SELECT_CONTACT)
        return OutboundStepResult(true, "search_text_set")
    }

    private fun selectSearchResult(
        root: AccessibilityNodeInfo,
        pending: PendingOutboundCall,
    ): OutboundStepResult {
        val texts = AccessibilityNodeUtils.collectTexts(root)
        val hasSearchContext = AccessibilityNodeUtils.findEditableNodeByLabels(root, SEARCH_LABELS) != null ||
            OutboundUiPolicy.hasExactLabel(texts, SEARCH_LABELS)
        if (!hasSearchContext) {
            return OutboundStepResult(false, "search_results_not_confirmed")
        }
        if (!OutboundUiPolicy.isTargetVisible(texts, pending.contactName)) {
            return OutboundStepResult(false, "target_result_not_visible_exact")
        }
        if (!clickFirstExact(root, listOf(pending.contactName), "outbound_click_contact", pending)) {
            return OutboundStepResult(false, "target_result_not_clickable")
        }

        advanceOutboundStage(pending, OutboundStage.OPEN_CALL_MENU)
        return OutboundStepResult(true, "target_result_opened")
    }

    private fun openCallMenu(
        root: AccessibilityNodeInfo,
        pending: PendingOutboundCall,
    ): OutboundStepResult {
        val texts = AccessibilityNodeUtils.collectTexts(root)
        if (!OutboundUiPolicy.isTargetChat(texts, pending.contactName)) {
            return OutboundStepResult(false, "target_chat_not_confirmed")
        }
        if (clickFinalCall(root, pending)) {
            return OutboundStepResult(true, "final_call_clicked")
        }
        if (clickFirstExact(root, MEDIA_CALL_MENU_LABELS, "outbound_click_media_menu", pending)) {
            advanceOutboundStage(pending, OutboundStage.SELECT_CALL_TYPE)
            return OutboundStepResult(true, "media_menu_opened")
        }
        if (clickFirstExact(root, MORE_MENU_LABELS, "outbound_click_more_menu", pending)) {
            advanceOutboundStage(pending, OutboundStage.OPEN_MEDIA_MENU)
            return OutboundStepResult(true, "more_menu_opened")
        }
        return OutboundStepResult(false, "call_menu_action_not_found")
    }

    private fun openMediaMenu(
        root: AccessibilityNodeInfo,
        pending: PendingOutboundCall,
    ): OutboundStepResult {
        val texts = AccessibilityNodeUtils.collectTexts(root)
        if (!OutboundUiPolicy.isTargetChat(texts, pending.contactName)) {
            return OutboundStepResult(false, "target_chat_not_confirmed_after_more")
        }
        if (!clickFirstExact(root, MEDIA_CALL_MENU_LABELS, "outbound_click_media_menu", pending)) {
            return OutboundStepResult(false, "media_menu_not_found")
        }

        advanceOutboundStage(pending, OutboundStage.SELECT_CALL_TYPE)
        return OutboundStepResult(true, "media_menu_opened")
    }

    private fun selectCallType(
        root: AccessibilityNodeInfo,
        pending: PendingOutboundCall,
    ): OutboundStepResult {
        val texts = AccessibilityNodeUtils.collectTexts(root)
        if (!OutboundUiPolicy.isTargetChat(texts, pending.contactName)) {
            return OutboundStepResult(false, "target_context_not_confirmed_for_call_type")
        }
        return if (clickFinalCall(root, pending)) {
            OutboundStepResult(true, "final_call_clicked")
        } else {
            OutboundStepResult(false, "call_type_button_not_found")
        }
    }

    private fun clickFinalCall(root: AccessibilityNodeInfo, pending: PendingOutboundCall): Boolean {
        val labels = if (pending.callType == "video") VIDEO_CALL_LABELS else VOICE_CALL_LABELS
        if (!clickFirstExact(root, labels, "outbound_click_final_call", pending)) return false

        pendingOutbound = null
        TtsSpeaker.speak("已尝试发起微信通话。")
        return true
    }

    private fun advanceOutboundStage(pending: PendingOutboundCall, next: OutboundStage) {
        pending.stage = next
        pending.failures = 0
    }

    private fun clickFirstExact(
        root: AccessibilityNodeInfo,
        labels: List<String>,
        category: String,
        pending: PendingOutboundCall,
    ): Boolean {
        val node = AccessibilityNodeUtils.findClickableByExactLabels(root, labels) ?: return false
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

        private val SEARCH_LABELS = listOf("搜索", "搜索按钮", "Search", "Search button")
        private val MORE_MENU_LABELS = listOf("更多功能按钮", "更多功能", "更多", "+")
        private val MEDIA_CALL_MENU_LABELS = listOf("音视频通话", "语音和视频通话", "Voice/Video Call")
        private val VIDEO_CALL_LABELS = listOf("视频通话", "Video Call")
        private val VOICE_CALL_LABELS = listOf("语音通话", "Voice Call")

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

        fun requestMakeWeChatCall(context: Context, contactName: String, callType: String): Boolean {
            val normalizedName = contactName.trim()
            val normalizedCallType = callType.trim().lowercase()
            if (normalizedName.isBlank()) {
                LocalActionLogger.append(context, "outbound_rejected", "reason=blank_contact")
                return false
            }
            if (normalizedCallType !in ALLOWED_CALL_TYPES) {
                LocalActionLogger.append(
                    context,
                    "outbound_rejected",
                    "reason=unsupported_call_type callType=$normalizedCallType",
                )
                return false
            }
            if (!LocalWhitelistStore.isAllowed(context, normalizedName)) {
                LocalActionLogger.append(
                    context,
                    "outbound_rejected",
                    "reason=contact_not_in_local_whitelist contact=$normalizedName",
                )
                return false
            }
            if (instance?.get() == null) {
                LocalActionLogger.append(context, "outbound_failed", "reason=accessibility_service_not_connected")
                TtsSpeaker.speak("无障碍服务未连接，无法一键拨出。")
                return false
            }
            if (pendingOutbound != null) {
                LocalActionLogger.append(context, "outbound_rejected", "reason=outbound_already_pending")
                TtsSpeaker.speak("已有一键拨出任务，请先停止。")
                return false
            }
            val launchIntent = context.packageManager.getLaunchIntentForPackage(WECHAT_PACKAGE)
            if (launchIntent == null) {
                LocalActionLogger.append(context, "outbound_failed", "reason=wechat_launch_intent_not_found")
                TtsSpeaker.speak("未找到微信，无法一键拨出。")
                return false
            }
            pendingOutbound = PendingOutboundCall(
                contactName = normalizedName,
                callType = normalizedCallType,
                startedAtMs = SystemClock.elapsedRealtime(),
            )
            launchIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            try {
                context.startActivity(launchIntent)
            } catch (error: RuntimeException) {
                pendingOutbound = null
                LocalActionLogger.append(
                    context,
                    "outbound_failed",
                    "reason=wechat_launch_failed error=${error.javaClass.simpleName}",
                )
                TtsSpeaker.speak("打开微信失败，无法一键拨出。")
                return false
            }
            LocalActionLogger.append(
                context,
                "outbound_launch_wechat",
                "contact=$normalizedName callType=$normalizedCallType",
            )
            return true
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

        internal fun cancelPendingOutboundForIncoming(context: Context) {
            val pending = pendingOutbound ?: return
            pendingOutbound = null
            LocalActionLogger.append(
                context,
                "outbound_cancelled",
                "contact=${pending.contactName} callType=${pending.callType} reason=incoming_call_detected",
            )
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

        private val ALLOWED_CALL_TYPES = setOf("voice", "video")
    }

    private data class PendingOutboundCall(
        val contactName: String,
        val callType: String,
        val startedAtMs: Long,
        var lastActionAtMs: Long = 0L,
        var failures: Int = 0,
        var stage: OutboundStage = OutboundStage.OPEN_SEARCH,
    )

    private data class OutboundStepResult(
        val acted: Boolean,
        val reason: String,
    )

    private enum class OutboundStage {
        OPEN_SEARCH,
        ENTER_SEARCH,
        SELECT_CONTACT,
        OPEN_CALL_MENU,
        OPEN_MEDIA_MENU,
        SELECT_CALL_TYPE,
    }
}
