package com.grandmacallagent.bridge.accessibility

object WeChatCallParser {
    fun looksLikeIncomingCall(texts: List<String>): Boolean {
        val joined = texts.joinToString(" ")
        val hasCall = CALL_KEYWORDS.any { joined.contains(it, ignoreCase = true) }
        val hasAccept = ACCEPT_KEYWORDS.any { joined.contains(it, ignoreCase = true) }
        return hasCall && hasAccept
    }

    fun inferCallType(texts: List<String>): String {
        val joined = texts.joinToString(" ")
        return when {
            joined.contains("视频", ignoreCase = true) -> "video"
            joined.contains("video", ignoreCase = true) -> "video"
            joined.contains("语音", ignoreCase = true) -> "voice"
            joined.contains("voice", ignoreCase = true) -> "voice"
            else -> "unknown"
        }
    }

    fun inferContactName(texts: List<String>): String? {
        texts.firstNotNullOfOrNull { extractContactFromCallText(it) }?.let { return it }
        return texts.firstOrNull { text ->
            val trimmed = text.trim()
            looksLikeContactName(trimmed)
        }?.trim()
    }

    private fun extractContactFromCallText(text: String): String? {
        val trimmed = text.trim()
        val markerIndex = CONTACT_MARKERS
            .map { trimmed.indexOf(it, ignoreCase = true) }
            .filter { it >= 0 }
            .minOrNull()
            ?: return null
        val beforeMarker = trimmed.substring(0, markerIndex).trimNameCandidate()
        return beforeMarker.takeIf { looksLikeContactName(it) }
    }

    private fun looksLikeContactName(value: String): Boolean {
        if (value.isBlank() || value.length > 32) return false
        if (NOISE_TEXTS.any { value.equals(it, ignoreCase = true) }) return false
        if (CALL_KEYWORDS.any { value.contains(it, ignoreCase = true) }) return false
        if (ACCEPT_KEYWORDS.any { value.contains(it, ignoreCase = true) }) return false
        if (CONTACT_MARKERS.any { value.contains(it, ignoreCase = true) }) return false
        return true
    }

    private fun String.trimNameCandidate(): String {
        return trim()
            .trim('：', ':', '-', '—', ' ', '\t', '\n', '\r')
            .removePrefix("来自")
            .removePrefix("from")
            .trim()
    }

    private val CALL_KEYWORDS = listOf("语音通话", "视频通话", "邀请你", "voice call", "video call")
    private val ACCEPT_KEYWORDS = listOf("接听", "接受", "接通", "Answer", "Accept")
    private val CONTACT_MARKERS = listOf("邀请你", "正在邀请", "来电", "calling", "invites you")
    private val NOISE_TEXTS = listOf(
        "微信",
        "WeChat",
        "拒绝",
        "挂断",
        "取消",
        "返回",
        "更多",
        "摄像头",
        "麦克风",
    )
}
