package com.grandmacallagent.bridge.network

import android.os.Handler
import android.os.Looper
import com.grandmacallagent.bridge.model.BridgeCommand
import com.grandmacallagent.bridge.model.BridgeEvent
import kotlinx.serialization.decodeFromString
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.Response
import okhttp3.WebSocket
import okhttp3.WebSocketListener
import java.util.concurrent.TimeUnit

class BridgeWebSocketClient(
    private val serverBaseUrl: String,
    private val deviceId: String,
    private val onCommand: (BridgeCommand) -> Unit,
) {
    private val json = Json { ignoreUnknownKeys = true }
    private val handler = Handler(Looper.getMainLooper())
    private val client = OkHttpClient.Builder()
        .pingInterval(20, TimeUnit.SECONDS)
        .build()
    private var socket: WebSocket? = null
    @Volatile private var closedByUser = false

    fun connect() {
        closedByUser = false
        val url = "${serverBaseUrl.trimEnd('/')}/ws/device/$deviceId"
        val request = Request.Builder().url(url).build()
        socket = client.newWebSocket(request, listener)
    }

    fun send(event: BridgeEvent) {
        socket?.send(json.encodeToString(event))
    }

    fun close() {
        closedByUser = true
        socket?.close(1000, "client closing")
        socket = null
    }

    private val listener = object : WebSocketListener() {
        override fun onMessage(webSocket: WebSocket, text: String) {
            runCatching {
                json.decodeFromString<BridgeCommand>(text)
            }.onSuccess { command ->
                handler.post { onCommand(command) }
            }
        }

        override fun onFailure(webSocket: WebSocket, t: Throwable, response: Response?) {
            scheduleReconnect()
        }

        override fun onClosed(webSocket: WebSocket, code: Int, reason: String) {
            scheduleReconnect()
        }
    }

    private fun scheduleReconnect() {
        if (closedByUser) return
        handler.postDelayed({ connect() }, 5_000)
    }
}
