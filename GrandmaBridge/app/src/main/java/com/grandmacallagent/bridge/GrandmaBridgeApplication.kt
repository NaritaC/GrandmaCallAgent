package com.grandmacallagent.bridge

import android.app.Application
import com.grandmacallagent.bridge.runtime.BridgeRuntime

class GrandmaBridgeApplication : Application() {
    override fun onCreate() {
        super.onCreate()
        BridgeRuntime.start(this)
    }
}
