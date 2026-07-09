package com.grandmacallagent.bridge.notification

import android.app.Notification
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import com.grandmacallagent.bridge.v0.V0AutomationRuntime

class WeChatNotificationListener : NotificationListenerService() {
    override fun onListenerConnected() {
        super.onListenerConnected()
        V0AutomationRuntime.start(applicationContext)
    }

    override fun onNotificationPosted(sbn: StatusBarNotification) {
        if (sbn.packageName != WECHAT_PACKAGE) return
        val extras = sbn.notification.extras
        val title = extras.getCharSequence(Notification.EXTRA_TITLE)?.toString()
        val text = extras.getCharSequence(Notification.EXTRA_TEXT)?.toString()
        val bigText = extras.getCharSequence(Notification.EXTRA_BIG_TEXT)?.toString()
        val fullText = listOfNotNull(title, text, bigText).joinToString(" ")

        if (!CallNotificationParser.isIncomingWeChatCall(fullText)) return

        V0AutomationRuntime.onIncomingWeChatCall(
            context = applicationContext,
            contactName = CallNotificationParser.inferContactName(title, text),
            callType = CallNotificationParser.inferCallType(fullText),
            source = "notification",
        )
    }

    companion object {
        private const val WECHAT_PACKAGE = "com.tencent.mm"
    }
}
