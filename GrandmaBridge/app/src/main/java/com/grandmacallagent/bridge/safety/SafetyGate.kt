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
        "voice call",
        "video call",
    )
    private val acceptCallKeywords = listOf(
        "接听",
        "接受",
        "接通",
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
        val hasAcceptSignal = visibleTexts.any { text ->
            acceptCallKeywords.any { normalize(text) == normalize(it) }
        }
        if (!hasIncomingCallSignal || !hasAcceptSignal) {
            return LocalSafetyDecision(false, "local_reject_not_incoming_call_window")
        }

        val contact = normalize(expectedContactName.orEmpty())
        if (contact.isBlank()) {
            return LocalSafetyDecision(false, "local_reject_blank_expected_contact")
        }
        if (visibleTexts.none { containsExpectedContact(it, contact) }) {
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

    private fun containsExpectedContact(text: String, normalizedContact: String): Boolean {
        val normalizedText = normalize(text)
        if (normalizedText == normalizedContact) return true
        return contactPrefixes.any { prefix ->
            contactContextMarkers.any { marker ->
                normalizedText.startsWith(normalize(prefix) + normalizedContact + normalize(marker))
            }
        }
    }

    private fun normalize(value: String): String {
        return value.filterNot { it.isWhitespace() }.lowercase()
    }

    private val contactContextMarkers = listOf(
        "邀请你",
        "正在邀请",
        "来电",
        "calling",
        "invites you",
    )
    private val contactPrefixes = listOf("", "来自", "from")
}
