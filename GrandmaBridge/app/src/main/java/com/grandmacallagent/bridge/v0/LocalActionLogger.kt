package com.grandmacallagent.bridge.v0

import android.content.Context
import java.io.File
import java.time.OffsetDateTime
import java.time.format.DateTimeFormatter

object LocalActionLogger {
    private const val FILE_NAME = "v0_actions.log"
    private const val MAX_LINES = 300

    @Synchronized
    fun append(context: Context, category: String, message: String) {
        val line = "${timestamp()} [$category] ${message.replace('\n', ' ')}"
        val file = logFile(context)
        file.parentFile?.mkdirs()
        val lines = if (file.exists()) file.readLines(Charsets.UTF_8) else emptyList()
        val next = (lines + line).takeLast(MAX_LINES)
        file.writeText(next.joinToString("\n") + "\n", Charsets.UTF_8)
    }

    @Synchronized
    fun read(context: Context): String {
        val file = logFile(context)
        return if (file.exists()) file.readText(Charsets.UTF_8) else "暂无 V0 本地日志。"
    }

    @Synchronized
    fun clear(context: Context) {
        logFile(context).writeText("", Charsets.UTF_8)
    }

    private fun logFile(context: Context): File {
        return File(context.filesDir, FILE_NAME)
    }

    private fun timestamp(): String {
        return OffsetDateTime.now().format(DateTimeFormatter.ISO_OFFSET_DATE_TIME)
    }
}
