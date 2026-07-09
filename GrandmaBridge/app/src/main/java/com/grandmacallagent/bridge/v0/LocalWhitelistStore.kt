package com.grandmacallagent.bridge.v0

import android.content.Context

object LocalWhitelistStore {
    private const val PREFS = "grandma_bridge_v0"
    private const val KEY_WHITELIST = "whitelist_names"

    fun list(context: Context): List<String> {
        val raw = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .getString(KEY_WHITELIST, "")
            .orEmpty()
        return raw.split('\n', ',', '，', ';', '；')
            .map { it.trim() }
            .filter { it.isNotBlank() }
            .distinctBy { normalize(it) }
    }

    fun save(context: Context, names: String) {
        val normalized = names.split('\n', ',', '，', ';', '；')
            .map { it.trim() }
            .filter { it.isNotBlank() }
            .distinctBy { normalize(it) }
            .joinToString("\n")
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .edit()
            .putString(KEY_WHITELIST, normalized)
            .apply()
    }

    fun isAllowed(context: Context, contactName: String?): Boolean {
        val target = normalize(contactName)
        if (target.isBlank()) return false
        return list(context).any { normalize(it) == target }
    }

    fun displayText(context: Context): String = list(context).joinToString("\n")

    private fun normalize(value: String?): String {
        return value.orEmpty().filterNot { it.isWhitespace() }.lowercase()
    }
}
