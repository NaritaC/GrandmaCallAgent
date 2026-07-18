package com.grandmacallagent.bridge.notification

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class CallNotificationParserTest {
    @Test
    fun `detects incoming voice notification`() {
        assertTrue(CallNotificationParser.isIncomingWeChatCall("可信联系人邀请你进行语音通话"))
        assertFalse(CallNotificationParser.isIncomingWeChatCall("可信联系人发送了一条消息"))
    }

    @Test
    fun `extracts notification contact and type`() {
        assertEquals(
            "可信联系人",
            CallNotificationParser.inferContactName("微信", "可信联系人正在邀请你进行视频通话"),
        )
        assertEquals("video", CallNotificationParser.inferCallType("可信联系人正在邀请你进行视频通话"))
    }
}
