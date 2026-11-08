package com.softchip.tourchip

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // 訊息、公告、氣泡的翻譯（ML Kit，手機上進行），見 Translator.kt
        ChatTranslatorChannel(flutterEngine.dartExecutor.binaryMessenger)
    }
}
