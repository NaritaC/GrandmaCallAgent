package com.grandmacallagent.bridge.v0

import android.content.Context

object LocalV0Settings {
    private const val PREFS = "grandma_bridge_v0"
    private const val KEY_AUTO_ANSWER_ENABLED = "auto_answer_enabled"

    fun isAutoAnswerEnabled(context: Context): Boolean {
        return context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .getBoolean(KEY_AUTO_ANSWER_ENABLED, false)
    }

    fun setAutoAnswerEnabled(context: Context, enabled: Boolean) {
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .edit()
            .putBoolean(KEY_AUTO_ANSWER_ENABLED, enabled)
            .apply()
    }
}
