package com.monora.monora

import android.content.Intent
import android.provider.Settings
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

// AudioServiceActivity is required by just_audio_background / audio_service:
// it wires media button routing and the foreground service into the activity.
class MainActivity : AudioServiceActivity() {
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
