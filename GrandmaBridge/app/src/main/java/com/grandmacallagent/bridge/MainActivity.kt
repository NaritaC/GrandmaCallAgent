package com.grandmacallagent.bridge

import android.app.Activity
import android.content.Intent
import android.os.Bundle
import android.provider.Settings
import android.view.Gravity
import android.widget.Button
import android.widget.CheckBox
import android.widget.EditText
import android.widget.LinearLayout
import android.widget.ScrollView
import android.widget.TextView
import android.widget.Toast
import com.grandmacallagent.bridge.v0.LocalActionLogger
import com.grandmacallagent.bridge.v0.LocalV0Settings
import com.grandmacallagent.bridge.v0.LocalWhitelistStore
import com.grandmacallagent.bridge.v0.V0AutomationRuntime

class MainActivity : Activity() {
    private lateinit var autoAnswerCheckBox: CheckBox
    private lateinit var whitelistInput: EditText
    private lateinit var outboundInput: EditText
    private lateinit var logView: TextView

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        V0AutomationRuntime.start(applicationContext)
        setContentView(buildContent())
    }

    override fun onResume() {
        super.onResume()
        if (::logView.isInitialized) {
            refreshLogs()
        }
    }

    private fun buildContent(): ScrollView {
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
            text = "V0：本地自动化脚本验证。只处理微信通话白名单接听和用户主动触发的一键拨出。"
            textSize = 15f
        }
        autoAnswerCheckBox = CheckBox(this).apply {
            text = "启用白名单来电自动接听（测试时再打开）"
            isChecked = LocalV0Settings.isAutoAnswerEnabled(this@MainActivity)
            setOnCheckedChangeListener { _, checked ->
                LocalV0Settings.setAutoAnswerEnabled(this@MainActivity, checked)
                LocalActionLogger.append(this@MainActivity, "settings", "auto_answer_enabled=$checked")
                Toast.makeText(
                    this@MainActivity,
                    if (checked) "自动接听已启用" else "自动接听已关闭",
                    Toast.LENGTH_SHORT,
                ).show()
            }
        }
        whitelistInput = EditText(this).apply {
            hint = "白名单联系人，每行一个微信显示名"
            minLines = 3
            setText(LocalWhitelistStore.displayText(this@MainActivity))
        }
        val saveWhitelistButton = Button(this).apply {
            text = "保存本地白名单"
            setOnClickListener {
                LocalWhitelistStore.save(this@MainActivity, whitelistInput.text.toString())
                LocalActionLogger.append(this@MainActivity, "settings", "local_whitelist_saved")
                Toast.makeText(this@MainActivity, "白名单已保存", Toast.LENGTH_SHORT).show()
            }
        }
        outboundInput = EditText(this).apply {
            hint = "一键拨出联系人，必须在白名单内"
            setSingleLine(true)
        }
        val voiceButton = Button(this).apply {
            text = "一键拨出微信语音"
            setOnClickListener { startOutbound("voice") }
        }
        val videoButton = Button(this).apply {
            text = "一键拨出微信视频"
            setOnClickListener { startOutbound("video") }
        }
        val accessibilityButton = Button(this).apply {
            text = "打开无障碍服务设置"
            setOnClickListener { startActivity(Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS)) }
        }
        val notificationButton = Button(this).apply {
            text = "打开通知使用权设置"
            setOnClickListener { startActivity(Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS)) }
        }
        val refreshLogButton = Button(this).apply {
            text = "刷新本地日志"
            setOnClickListener { refreshLogs() }
        }
        val clearLogButton = Button(this).apply {
            text = "清空本地日志"
            setOnClickListener {
                LocalActionLogger.clear(this@MainActivity)
                refreshLogs()
            }
        }
        logView = TextView(this).apply {
            textSize = 12f
            text = LocalActionLogger.read(this@MainActivity)
        }

        listOf(
            title,
            description,
            autoAnswerCheckBox,
            whitelistInput,
            saveWhitelistButton,
            outboundInput,
            voiceButton,
            videoButton,
            accessibilityButton,
            notificationButton,
            refreshLogButton,
            clearLogButton,
            logView,
        ).forEach {
            root.addView(
                it,
                LinearLayout.LayoutParams(
                    LinearLayout.LayoutParams.MATCH_PARENT,
                    LinearLayout.LayoutParams.WRAP_CONTENT,
                ).apply { bottomMargin = padding / 2 },
            )
        }
        return ScrollView(this).apply { addView(root) }
    }

    private fun startOutbound(callType: String) {
        val started = V0AutomationRuntime.startOutboundCall(
            context = this,
            contactName = outboundInput.text.toString(),
            callType = callType,
        )
        if (started) {
            Toast.makeText(this, "已打开微信并尝试拨出，请观察日志", Toast.LENGTH_SHORT).show()
        }
        refreshLogs()
    }

    private fun refreshLogs() {
        logView.text = LocalActionLogger.read(this)
    }
}
