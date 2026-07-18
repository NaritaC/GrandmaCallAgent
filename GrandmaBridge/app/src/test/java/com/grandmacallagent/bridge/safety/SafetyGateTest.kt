package com.grandmacallagent.bridge.safety

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class SafetyGateTest {
    @Test
    fun `allows confirmed wechat incoming call for exact contact`() {
        val decision = SafetyGate.canClickAcceptWeChatCall(
            packageName = "com.tencent.mm",
            expectedContactName = "可信联系人",
            visibleTexts = listOf("可信联系人", "视频通话", "接听"),
        )

        assertTrue(decision.allowed)
        assertEquals("local_allowed", decision.reason)
    }

    @Test
    fun `allows combined contact invitation text`() {
        val decision = SafetyGate.canClickAcceptWeChatCall(
            packageName = "com.tencent.mm",
            expectedContactName = "可信联系人",
            visibleTexts = listOf("可信联系人邀请你进行语音通话", "接听"),
        )

        assertTrue(decision.allowed)
    }

    @Test
    fun `allows combined invitation text with source prefix`() {
        val decision = SafetyGate.canClickAcceptWeChatCall(
            packageName = "com.tencent.mm",
            expectedContactName = "可信联系人",
            visibleTexts = listOf("来自可信联系人邀请你进行视频通话", "接听"),
        )

        assertTrue(decision.allowed)
    }

    @Test
    fun `rejects similar but nonexact contact`() {
        val decision = SafetyGate.canClickAcceptWeChatCall(
            packageName = "com.tencent.mm",
            expectedContactName = "可信联系人",
            visibleTexts = listOf("可信联系人二", "语音通话", "接听"),
        )

        assertFalse(decision.allowed)
        assertEquals("local_reject_contact_not_visible", decision.reason)
    }

    @Test
    fun `rejects blank expected contact`() {
        val decision = SafetyGate.canClickAcceptWeChatCall(
            packageName = "com.tencent.mm",
            expectedContactName = null,
            visibleTexts = listOf("可信联系人", "语音通话", "接听"),
        )

        assertFalse(decision.allowed)
        assertEquals("local_reject_blank_expected_contact", decision.reason)
    }

    @Test
    fun `rejects high risk keyword before any call click`() {
        val decision = SafetyGate.canClickAcceptWeChatCall(
            packageName = "com.tencent.mm",
            expectedContactName = "可信联系人",
            visibleTexts = listOf("可信联系人", "视频通话", "接听", "转账"),
        )

        assertFalse(decision.allowed)
        assertTrue(decision.reason.startsWith("local_reject_high_risk_keyword"))
    }

    @Test
    fun `rejects accept text outside incoming call window`() {
        val decision = SafetyGate.canClickAcceptWeChatCall(
            packageName = "com.tencent.mm",
            expectedContactName = "可信联系人",
            visibleTexts = listOf("可信联系人", "接受"),
        )

        assertFalse(decision.allowed)
        assertEquals("local_reject_not_incoming_call_window", decision.reason)
    }

    @Test
    fun `rejects non wechat package`() {
        val decision = SafetyGate.canOperateWeChatWindow("example.other", listOf("语音通话", "接听"))

        assertFalse(decision.allowed)
        assertEquals("local_reject_non_wechat_window", decision.reason)
    }
}
