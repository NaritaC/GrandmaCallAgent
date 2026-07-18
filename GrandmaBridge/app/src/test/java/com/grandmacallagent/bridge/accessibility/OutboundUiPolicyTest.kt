package com.grandmacallagent.bridge.accessibility

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class OutboundUiPolicyTest {
    @Test
    fun `wechat home requires at least three exact tab labels`() {
        assertTrue(OutboundUiPolicy.isWeChatHome(listOf("微信", "通讯录", "发现", "搜索")))
        assertFalse(OutboundUiPolicy.isWeChatHome(listOf("微信支付", "通讯录助手", "发现页")))
    }

    @Test
    fun `target matching rejects longer similar display names`() {
        assertTrue(OutboundUiPolicy.isTargetVisible(listOf("可信联系人"), "可信 联系人"))
        assertFalse(OutboundUiPolicy.isTargetVisible(listOf("可信联系人二"), "可信联系人"))
    }

    @Test
    fun `target chat requires exact target and chat screen signal`() {
        assertTrue(OutboundUiPolicy.isTargetChat(listOf("可信联系人", "更多功能按钮"), "可信联系人"))
        assertFalse(OutboundUiPolicy.isTargetChat(listOf("可信联系人", "通讯录"), "可信联系人"))
        assertFalse(OutboundUiPolicy.isTargetChat(listOf("可信联系人二", "更多功能按钮"), "可信联系人"))
    }

    @Test
    fun `exact label matching ignores case and whitespace only`() {
        assertTrue(OutboundUiPolicy.hasExactLabel(listOf(" Search "), listOf("search")))
        assertFalse(OutboundUiPolicy.hasExactLabel(listOf("Search contacts"), listOf("search")))
    }
}
