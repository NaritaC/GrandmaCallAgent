package com.grandmacallagent.bridge.accessibility

object OutboundUiPolicy {
    private val chineseHomeLabels = listOf("微信", "通讯录", "发现", "我")
    private val englishHomeLabels = listOf("WeChat", "Contacts", "Discover", "Me")
    private val chatScreenLabels = listOf(
        "按住说话",
        "切换到键盘",
        "切换到语音",
        "发送",
        "表情",
        "更多功能按钮",
        "输入",
        "Hold to Talk",
    )

    fun isWeChatHome(texts: List<String>): Boolean {
        return countExact(texts, chineseHomeLabels) >= 3 || countExact(texts, englishHomeLabels) >= 3
    }

    fun isTargetVisible(texts: List<String>, contactName: String): Boolean {
        val target = normalize(contactName)
        return target.isNotBlank() && texts.any { normalize(it) == target }
    }

    fun isTargetChat(texts: List<String>, contactName: String): Boolean {
        return isTargetVisible(texts, contactName) && chatScreenLabels.any { label ->
            texts.any { normalize(it) == normalize(label) }
        }
    }

    fun hasExactLabel(texts: List<String>, labels: List<String>): Boolean {
        val visible = texts.map(::normalize).toSet()
        return labels.any { normalize(it) in visible }
    }

    private fun countExact(texts: List<String>, labels: List<String>): Int {
        val visible = texts.map(::normalize).toSet()
        return labels.count { normalize(it) in visible }
    }

    private fun normalize(value: String): String {
        return value.filterNot { it.isWhitespace() }.lowercase()
    }
}
