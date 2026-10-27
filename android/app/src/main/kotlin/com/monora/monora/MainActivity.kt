package com.monora.monora

import android.content.Intent
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "monora/system")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "openSoundSettings" -> {
                        try {
                            val intent = Intent(Settings.ACTION_SOUND_SETTINGS)
                            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            startActivity(intent)
                            result.success(null)
                        } catch (e: Exception) {
                            result.error("UNAVAILABLE", "Could not open sound settings", null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
