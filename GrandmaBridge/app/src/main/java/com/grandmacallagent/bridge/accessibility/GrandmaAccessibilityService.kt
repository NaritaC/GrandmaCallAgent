package com.grandmacallagent.bridge.accessibility

import android.accessibilityservice.AccessibilityService
import android.os.Handler
import android.os.Looper
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityNodeInfo
import com.grandmacallagent.bridge.runtime.BridgeRuntime
import com.grandmacallagent.bridge.safety.SafetyGate
import com.grandmacallagent.bridge.speech.TtsSpeaker
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.put
import java.lang.ref.WeakReference

class GrandmaAccessibilityService : AccessibilityService() {
    private val mainHandler = Handler(Looper.getMainLooper())

    override fun onServiceConnected() {
        super.onServiceConnected()
        instance = WeakReference(this)
        BridgeRuntime.start(applicationContext)
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        if (event?.packageName?.toString() != WECHAT_PACKAGE) return
        val root = rootInActiveWindow ?: return
        val texts = AccessibilityNodeUtils.collectTexts(root)
        if (!WeChatCallParser.looksLikeIncomingCall(texts)) return

        BridgeRuntime.sendEvent(
            "incoming_wechat_call",
            buildJsonObject {
                put("app_package", WECHAT_PACKAGE)
                put("contact_name", WeChatCallParser.inferContactName(texts))
                put("call_type", WeChatCallParser.inferCallType(texts))
                put("source", "accessibility")
            },
        )
    }

    override fun onInterrupt() = Unit

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

    companion object {
        private const val WECHAT_PACKAGE = "com.tencent.mm"
        private var instance: WeakReference<GrandmaAccessibilityService>? = null

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
    }
}
