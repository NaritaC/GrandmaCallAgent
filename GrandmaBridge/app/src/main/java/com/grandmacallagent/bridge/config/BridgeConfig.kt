package com.grandmacallagent.bridge.config

import android.content.Context
import android.provider.Settings
import java.util.UUID

object BridgeConfig {
    private const val PREFS = "grandma_bridge"
    private const val KEY_SERVER_BASE_URL = "server_base_url"
    private const val KEY_DEVICE_ID = "device_id"
    private const val DEFAULT_SERVER_BASE_URL = "ws://10.0.2.2:8000"

    fun serverBaseUrl(context: Context): String {
        return context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .getString(KEY_SERVER_BASE_URL, DEFAULT_SERVER_BASE_URL)
            ?: DEFAULT_SERVER_BASE_URL
    }

    fun saveServerBaseUrl(context: Context, value: String) {
        val normalized = value.trim().ifBlank { DEFAULT_SERVER_BASE_URL }
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .edit()
            .putString(KEY_SERVER_BASE_URL, normalized)
            .apply()
    }

    fun deviceId(context: Context): String {
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        prefs.getString(KEY_DEVICE_ID, null)?.let { return it }

        val androidId = Settings.Secure.getString(context.contentResolver, Settings.Secure.ANDROID_ID)
        val generated = androidId?.takeIf { it.isNotBlank() } ?: UUID.randomUUID().toString()
        prefs.edit().putString(KEY_DEVICE_ID, generated).apply()
        return generated
    }
}
