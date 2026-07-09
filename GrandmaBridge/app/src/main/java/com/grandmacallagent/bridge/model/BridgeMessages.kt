package com.grandmacallagent.bridge.model

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.buildJsonObject

@Serializable
data class BridgeEvent(
    val type: String,
    @SerialName("device_id") val deviceId: String,
    val timestamp: Long = System.currentTimeMillis(),
    val payload: JsonObject = buildJsonObject { },
)

@Serializable
data class BridgeCommand(
    @SerialName("command_id") val commandId: String,
    val type: String,
    @SerialName("task_id") val taskId: String? = null,
    val payload: JsonObject = buildJsonObject { },
)

@Serializable
data class ActionResultPayload(
    @SerialName("command_id") val commandId: String,
    @SerialName("task_id") val taskId: String? = null,
    val success: Boolean,
    val reason: String,
)
