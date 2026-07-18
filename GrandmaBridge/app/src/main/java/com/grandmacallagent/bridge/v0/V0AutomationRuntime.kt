package com.grandmacallagent.bridge.v0

import android.content.Context
import com.grandmacallagent.bridge.accessibility.GrandmaAccessibilityService
import com.grandmacallagent.bridge.speech.TtsSpeaker

object V0AutomationRuntime {
    private val allowedCallTypes = setOf("voice", "video")

    fun start(context: Context) {
        TtsSpeaker.start(context.applicationContext)
        LocalActionLogger.append(context, "runtime", "V0 local automation runtime started")
    }

    fun onIncomingWeChatCall(
        context: Context,
        contactName: String?,
        callType: String,
        source: String,
    ) {
        val normalizedCallType = callType.trim().lowercase()
        LocalActionLogger.append(
            context,
            "incoming_detected",
            "source=$source contact=${contactName.orEmpty()} callType=$normalizedCallType",
        )
        GrandmaAccessibilityService.cancelPendingOutboundForIncoming(context)

        if (!LocalV0Settings.isAutoAnswerEnabled(context)) {
            LocalActionLogger.append(context, "incoming_rejected", "reason=auto_answer_disabled")
            return
        }

        if (normalizedCallType !in allowedCallTypes) {
            LocalActionLogger.append(context, "incoming_rejected", "reason=unsupported_call_type callType=$normalizedCallType")
            return
        }

        if (!LocalWhitelistStore.isAllowed(context, contactName)) {
            LocalActionLogger.append(
                context,
                "incoming_rejected",
                "reason=contact_not_in_local_whitelist contact=${contactName.orEmpty()}",
            )
            TtsSpeaker.speak("非白名单联系人，未自动接听。")
            return
        }

        LocalActionLogger.append(context, "incoming_allowed", "contact=${contactName.orEmpty()} callType=$normalizedCallType")
        GrandmaAccessibilityService.requestAcceptWeChatCallLocal(
            context = context,
            contactName = contactName,
            source = source,
        )
    }

    fun startOutboundCall(context: Context, contactName: String, callType: String): Boolean {
        val normalizedName = contactName.trim()
        val normalizedCallType = callType.trim().lowercase()
        if (normalizedName.isBlank()) {
            LocalActionLogger.append(context, "outbound_rejected", "reason=blank_contact")
            TtsSpeaker.speak("请先输入白名单联系人。")
            return false
        }
        if (normalizedCallType !in allowedCallTypes) {
            LocalActionLogger.append(context, "outbound_rejected", "reason=unsupported_call_type callType=$normalizedCallType")
            return false
        }
        if (!LocalWhitelistStore.isAllowed(context, normalizedName)) {
            LocalActionLogger.append(context, "outbound_rejected", "reason=contact_not_in_local_whitelist contact=$normalizedName")
            TtsSpeaker.speak("联系人不在白名单，不能一键拨出。")
            return false
        }

        LocalActionLogger.append(context, "outbound_requested", "contact=$normalizedName callType=$normalizedCallType")
        return GrandmaAccessibilityService.requestMakeWeChatCall(
            context = context,
            contactName = normalizedName,
            callType = normalizedCallType,
        )
    }

    fun cancelOutboundCall(context: Context): Boolean {
        LocalActionLogger.append(context, "outbound_cancel_requested", "source=main_activity")
        return GrandmaAccessibilityService.cancelPendingOutbound(
            context = context,
            reason = "user_requested",
        )
    }
}
