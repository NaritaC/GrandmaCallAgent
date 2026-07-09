package com.grandmacallagent.bridge

import android.app.Application
import com.grandmacallagent.bridge.v0.V0AutomationRuntime

class GrandmaBridgeApplication : Application() {
    override fun onCreate() {
        super.onCreate()
        V0AutomationRuntime.start(this)
    }
}
