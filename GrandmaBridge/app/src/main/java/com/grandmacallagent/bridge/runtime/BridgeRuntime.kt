package com.grandmacallagent.bridge.runtime

import android.content.Context
import com.grandmacallagent.bridge.accessibility.GrandmaAccessibilityService
import com.grandmacallagent.bridge.config.BridgeConfig
import com.grandmacallagent.bridge.model.ActionResultPayload
import com.grandmacallagent.bridge.model.BridgeCommand
import com.grandmacallagent.bridge.model.BridgeEvent
import com.grandmacallagent.bridge.network.BridgeWebSocketClient
import com.grandmacallagent.bridge.speech.TtsSpeaker
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.delay
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.contentOrNull
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import kotlinx.serialization.json.put

object BridgeRuntime {
    private val json = Json { ignoreUnknownKeys = true }
    private var scope: CoroutineScope = CoroutineScope(SupervisorJob() + Dispatchers.Default)
    private var heartbeatJob: Job? = null
    private var client: BridgeWebSocketClient? = null
    private lateinit var appContext: Context
    @Volatile private var started = false

    fun start(context: Context) {
        appContext = context.applicationContext
        if (started) return
        started = true
        TtsSpeaker.start(appContext)
        connect()
        startHeartbeat()
    }

    fun restart(context: Context) {
        stop()
        started = false
        start(context)
    }

    fun stop() {
        heartbeatJob?.cancel()
        client?.close()
        scope.cancel()
        scope = CoroutineScope(SupervisorJob() + Dispatchers.Default)
    }

    fun sendEvent(type: String, payload: JsonObject) {
        if (!started) return
        val event = BridgeEvent(
            type = type,
            deviceId = BridgeConfig.deviceId(appContext),
            payload = payload,
        )
        client?.send(event)
    }

    fun reportActionResult(commandId: String, taskId: String?, success: Boolean, reason: String) {
        val payloadString = json.encodeToString(
            ActionResultPayload(
                commandId = commandId,
                taskId = taskId,
                success = success,
                reason = reason,
            ),
        )
        sendEvent("action_result", json.parseToJsonElement(payloadString).jsonObject)
    }

    private fun connect() {
        val deviceId = BridgeConfig.deviceId(appContext)
        val baseUrl = BridgeConfig.serverBaseUrl(appContext)
        client = BridgeWebSocketClient(
            serverBaseUrl = baseUrl,
            deviceId = deviceId,
            onCommand = ::handleCommand,
        )
        client?.connect()
    }

    private fun startHeartbeat() {
        heartbeatJob = scope.launch {
            while (isActive) {
                sendHeartbeat()
                delay(30_000)
            }
        }
    }

    private fun sendHeartbeat() {
        val status = DeviceStatusReader.read(appContext)
        sendEvent(
            "heartbeat",
            buildJsonObject {
                put("model", status.model)
                put("android_sdk", status.androidSdk)
                put("battery_percent", status.batteryPercent)
                put("accessibility_enabled", status.accessibilityEnabled)
                put("notification_listener_enabled", status.notificationListenerEnabled)
            },
        )
    }

    private fun handleCommand(command: BridgeCommand) {
        when (command.type) {
            "accept_call" -> {
                val contactName = command.payload["contact_name"]?.jsonPrimitive?.contentOrNull
                GrandmaAccessibilityService.requestAcceptWeChatCall(
                    contactName = contactName,
                    commandId = command.commandId,
                    taskId = command.taskId,
                )
            }
            "safety_denied" -> {
                val reason = command.payload["reason"]?.jsonPrimitive?.contentOrNull ?: "安全校验未通过"
                TtsSpeaker.speak("来电未自动接听，原因：$reason")
            }
        }
    }
}
