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
        return texts.firstOrNull { text ->
            val trimmed = text.trim()
            trimmed.isNotBlank() &&
                CALL_KEYWORDS.none { trimmed.contains(it, ignoreCase = true) } &&
                ACCEPT_KEYWORDS.none { trimmed.contains(it, ignoreCase = true) } &&
                trimmed.length <= 32
        }?.trim()
    }

    private val CALL_KEYWORDS = listOf("语音通话", "视频通话", "邀请你", "voice call", "video call")
    private val ACCEPT_KEYWORDS = listOf("接听", "接受", "接通", "Answer", "Accept")
}
