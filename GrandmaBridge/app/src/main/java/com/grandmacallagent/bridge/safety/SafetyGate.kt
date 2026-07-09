package com.grandmacallagent.bridge.safety

data class LocalSafetyDecision(
    val allowed: Boolean,
    val reason: String,
)

object SafetyGate {
    private const val WECHAT_PACKAGE = "com.tencent.mm"
    private val blockedKeywords = listOf(
        "支付",
        "付款",
        "转账",
        "收款",
        "红包",
        "银行卡",
        "验证码",
        "删除",
        "清空聊天记录",
        "撤回",
        "payment",
        "transfer",
        "delete",
    )
    private val incomingCallKeywords = listOf(
        "语音通话",
        "视频通话",
        "接听",
        "接受",
        "Answer",
        "Accept",
    )

    fun canClickAcceptWeChatCall(
        packageName: String?,
        expectedContactName: String?,
        visibleTexts: List<String>,
    ): LocalSafetyDecision {
        canOperateWeChatWindow(packageName, visibleTexts).let {
            if (!it.allowed) return it
        }

        val joined = visibleTexts.joinToString(" ")
        val hasIncomingCallSignal = incomingCallKeywords.any { joined.contains(it, ignoreCase = true) }
        if (!hasIncomingCallSignal) {
            return LocalSafetyDecision(false, "local_reject_not_incoming_call_window")
        }

        val contact = expectedContactName?.trim().orEmpty()
        if (contact.isNotBlank() && visibleTexts.none { it.contains(contact, ignoreCase = true) }) {
            return LocalSafetyDecision(false, "local_reject_contact_not_visible")
        }

        return LocalSafetyDecision(true, "local_allowed")
    }

    fun canOperateWeChatWindow(packageName: String?, visibleTexts: List<String>): LocalSafetyDecision {
        if (packageName != WECHAT_PACKAGE) {
            return LocalSafetyDecision(false, "local_reject_non_wechat_window")
        }

        val joined = visibleTexts.joinToString(" ")
        blockedKeywords.firstOrNull { joined.contains(it, ignoreCase = true) }?.let {
            return LocalSafetyDecision(false, "local_reject_high_risk_keyword:$it")
        }

        return LocalSafetyDecision(true, "local_allowed_wechat_window")
    }
}
