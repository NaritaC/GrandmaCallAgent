package com.grandmacallagent.bridge.accessibility

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class WeChatCallParserTest {
    @Test
    fun `detects video call only when call and accept signals coexist`() {
        assertTrue(WeChatCallParser.looksLikeIncomingCall(listOf("可信联系人", "视频通话", "接听")))
        assertFalse(WeChatCallParser.looksLikeIncomingCall(listOf("可信联系人", "接受邀请")))
    }

    @Test
    fun `infers call type`() {
        assertEquals("video", WeChatCallParser.inferCallType(listOf("Video Call", "Answer")))
        assertEquals("voice", WeChatCallParser.inferCallType(listOf("语音通话", "接听")))
        assertEquals("unknown", WeChatCallParser.inferCallType(listOf("微信")))
    }

    @Test
    fun `extracts contact before invitation marker`() {
        assertEquals("可信联系人", WeChatCallParser.inferContactName(listOf("可信联系人邀请你进行视频通话", "接听")))
    }
}
