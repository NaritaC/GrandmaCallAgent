package com.grandmacallagent.bridge

import android.app.Activity
import android.content.Intent
import android.os.Bundle
import android.provider.Settings
import android.view.Gravity
import android.widget.Button
import android.widget.EditText
import android.widget.LinearLayout
import android.widget.TextView
import com.grandmacallagent.bridge.config.BridgeConfig
import com.grandmacallagent.bridge.runtime.BridgeRuntime

class MainActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        BridgeRuntime.start(applicationContext)
        setContentView(buildContent())
    }

    private fun buildContent(): LinearLayout {
        val padding = (24 * resources.displayMetrics.density).toInt()
        val root = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER_HORIZONTAL
            setPadding(padding, padding, padding, padding)
        }

        val title = TextView(this).apply {
            text = "GrandmaBridge"
            textSize = 24f
        }
        val description = TextView(this).apply {
            text = "第一阶段只处理微信语音/视频来电白名单自动接听。"
            textSize = 15f
        }
        val serverInput = EditText(this).apply {
            hint = "WebSocket 服务地址"
            setSingleLine(true)
            setText(BridgeConfig.serverBaseUrl(this@MainActivity))
        }
        val saveButton = Button(this).apply {
            text = "保存服务地址并重连"
            setOnClickListener {
                BridgeConfig.saveServerBaseUrl(this@MainActivity, serverInput.text.toString())
                BridgeRuntime.restart(applicationContext)
            }
        }
        val accessibilityButton = Button(this).apply {
            text = "打开无障碍服务设置"
            setOnClickListener { startActivity(Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS)) }
        }
        val notificationButton = Button(this).apply {
            text = "打开通知使用权设置"
            setOnClickListener { startActivity(Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS)) }
        }

        listOf(title, description, serverInput, saveButton, accessibilityButton, notificationButton).forEach {
            root.addView(
                it,
                LinearLayout.LayoutParams(
                    LinearLayout.LayoutParams.MATCH_PARENT,
                    LinearLayout.LayoutParams.WRAP_CONTENT,
                ).apply { bottomMargin = padding / 2 },
            )
        }
        return root
    }
}
