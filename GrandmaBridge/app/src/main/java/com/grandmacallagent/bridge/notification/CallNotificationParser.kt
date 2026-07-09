package com.grandmacallagent.bridge.notification

object CallNotificationParser {
    fun isIncomingWeChatCall(text: String): Boolean {
        val hasCall = CALL_KEYWORDS.any { text.contains(it, ignoreCase = true) }
        val hasIncoming = INCOMING_KEYWORDS.any { text.contains(it, ignoreCase = true) }
        return hasCall && hasIncoming
    }

    fun inferCallType(text: String): String {
        return when {
            text.contains("视频", ignoreCase = true) -> "video"
            text.contains("video", ignoreCase = true) -> "video"
            text.contains("语音", ignoreCase = true) -> "voice"
            text.contains("voice", ignoreCase = true) -> "voice"
            else -> "unknown"
        }
    }

    fun inferContactName(title: String?, text: String?): String? {
        val candidates = listOfNotNull(title, text)
        candidates.firstNotNullOfOrNull { extractContactFromCallText(it) }?.let { return it }
        return candidates.firstOrNull { candidate ->
            val normalized = candidate.trim()
            looksLikeContactName(normalized)
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
        if (INCOMING_KEYWORDS.any { value.contains(it, ignoreCase = true) }) return false
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

    private val CALL_KEYWORDS = listOf("语音通话", "视频通话", "voice call", "video call")
    private val INCOMING_KEYWORDS = listOf("邀请", "来电", "incoming", "calling")
    private val CONTACT_MARKERS = listOf("邀请你", "正在邀请", "来电", "calling", "invites you")
    private val NOISE_TEXTS = listOf("微信", "WeChat", "语音通话", "视频通话")
}
