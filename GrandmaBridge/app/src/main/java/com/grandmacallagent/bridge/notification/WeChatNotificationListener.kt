package com.grandmacallagent.bridge.notification

import android.app.Notification
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import com.grandmacallagent.bridge.runtime.BridgeRuntime
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.put

class WeChatNotificationListener : NotificationListenerService() {
    override fun onListenerConnected() {
        super.onListenerConnected()
        BridgeRuntime.start(applicationContext)
    }

    override fun onNotificationPosted(sbn: StatusBarNotification) {
        if (sbn.packageName != WECHAT_PACKAGE) return
        val extras = sbn.notification.extras
        val title = extras.getCharSequence(Notification.EXTRA_TITLE)?.toString()
        val text = extras.getCharSequence(Notification.EXTRA_TEXT)?.toString()
        val bigText = extras.getCharSequence(Notification.EXTRA_BIG_TEXT)?.toString()
        val fullText = listOfNotNull(title, text, bigText).joinToString(" ")

        if (!CallNotificationParser.isIncomingWeChatCall(fullText)) return

        BridgeRuntime.sendEvent(
            "incoming_wechat_call",
            buildJsonObject {
                put("app_package", WECHAT_PACKAGE)
                put("contact_name", CallNotificationParser.inferContactName(title, text))
                put("call_type", CallNotificationParser.inferCallType(fullText))
                put("source", "notification")
            },
        )
    }

    companion object {
        private const val WECHAT_PACKAGE = "com.tencent.mm"
    }
}
