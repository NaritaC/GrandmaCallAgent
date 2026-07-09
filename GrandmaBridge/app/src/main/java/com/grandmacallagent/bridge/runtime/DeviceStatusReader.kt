package com.grandmacallagent.bridge.runtime

import android.accessibilityservice.AccessibilityServiceInfo
import android.content.Context
import android.os.BatteryManager
import android.os.Build
import android.provider.Settings
import android.view.accessibility.AccessibilityManager

data class DeviceStatus(
    val model: String,
    val androidSdk: Int,
    val batteryPercent: Int,
    val accessibilityEnabled: Boolean,
    val notificationListenerEnabled: Boolean,
)

object DeviceStatusReader {
    fun read(context: Context): DeviceStatus {
        return DeviceStatus(
            model = "${Build.MANUFACTURER} ${Build.MODEL}",
            androidSdk = Build.VERSION.SDK_INT,
            batteryPercent = readBatteryPercent(context),
            accessibilityEnabled = isAccessibilityEnabled(context),
            notificationListenerEnabled = isNotificationListenerEnabled(context),
        )
    }

    private fun readBatteryPercent(context: Context): Int {
        val batteryManager = context.getSystemService(Context.BATTERY_SERVICE) as BatteryManager
        return batteryManager.getIntProperty(BatteryManager.BATTERY_PROPERTY_CAPACITY)
    }

    private fun isAccessibilityEnabled(context: Context): Boolean {
        val manager = context.getSystemService(Context.ACCESSIBILITY_SERVICE) as AccessibilityManager
        return manager.getEnabledAccessibilityServiceList(AccessibilityServiceInfo.FEEDBACK_ALL_MASK)
            .any { it.resolveInfo.serviceInfo.packageName == context.packageName }
    }

    private fun isNotificationListenerEnabled(context: Context): Boolean {
        val flat = Settings.Secure.getString(context.contentResolver, "enabled_notification_listeners")
        return flat?.contains(context.packageName) == true
    }
}
