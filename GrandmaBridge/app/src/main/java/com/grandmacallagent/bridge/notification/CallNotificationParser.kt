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
        return candidates.firstOrNull { candidate ->
            val normalized = candidate.trim()
            normalized.isNotBlank() &&
                normalized != "微信" &&
                CALL_KEYWORDS.none { normalized.contains(it, ignoreCase = true) } &&
                INCOMING_KEYWORDS.none { normalized.contains(it, ignoreCase = true) } &&
                normalized.length <= 32
        }?.trim()
    }

    private val CALL_KEYWORDS = listOf("语音通话", "视频通话", "voice call", "video call")
    private val INCOMING_KEYWORDS = listOf("邀请", "来电", "incoming", "calling")
}
