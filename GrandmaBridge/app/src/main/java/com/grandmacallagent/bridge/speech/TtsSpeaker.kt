package com.grandmacallagent.bridge.speech

import android.content.Context
import android.speech.tts.TextToSpeech
import java.util.Locale

object TtsSpeaker {
    private var tts: TextToSpeech? = null

    fun start(context: Context) {
        if (tts != null) return
        tts = TextToSpeech(context.applicationContext) { status ->
            if (status == TextToSpeech.SUCCESS) {
                tts?.language = Locale.CHINESE
            }
        }
    }

    fun speak(text: String) {
        tts?.speak(text, TextToSpeech.QUEUE_FLUSH, null, "grandma-bridge")
    }
}
