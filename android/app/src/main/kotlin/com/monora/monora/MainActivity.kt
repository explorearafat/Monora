package com.monora.monora

import android.content.Context
import android.content.Intent
import android.media.AudioDeviceCallback
import android.media.AudioDeviceInfo
import android.media.AudioManager
import android.provider.Settings
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

// AudioServiceActivity is required by audio_service: it wires media button
// routing and the foreground service into the activity.
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
                    "shareImage" -> {
                        try {
                            val path = call.argument<String>("path")
                                ?: throw IllegalArgumentException("path required")
                            val text = call.argument<String>("text")
                            val file = java.io.File(path)
                            val uri = androidx.core.content.FileProvider.getUriForFile(
                                this,
                                "$packageName.fileprovider",
                                file,
                            )
                            val send = Intent(Intent.ACTION_SEND).apply {
                                type = "image/png"
                                putExtra(Intent.EXTRA_STREAM, uri)
                                if (!text.isNullOrEmpty()) {
                                    putExtra(Intent.EXTRA_TEXT, text)
                                }
                                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                            }
                            val chooser = Intent.createChooser(send, "Share via")
                            chooser.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            startActivity(chooser)
                            result.success(null)
                        } catch (e: Exception) {
                            result.error("UNAVAILABLE", "Could not share image", null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }

        // Home screen widget: one-way updates from the player.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "monora/widget")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "update" -> {
                        val title = call.argument<String>("title") ?: "Monora"
                        val artist = call.argument<String>("artist") ?: "Nothing playing"
                        val playing = call.argument<Boolean>("playing") ?: false
                        MonoraWidgetProvider.update(this, title, artist, playing)
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }

        // Headphone/Bluetooth/car connect events. AudioDeviceCallback needs no
        // runtime permission, unlike Bluetooth ACL broadcasts on Android 12+.
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, "monora/audio_devices")
            .setStreamHandler(object : EventChannel.StreamHandler {
                private var audioManager: AudioManager? = null
                private var callback: AudioDeviceCallback? = null

                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    val am = getSystemService(Context.AUDIO_SERVICE) as AudioManager
                    audioManager = am
                    callback = object : AudioDeviceCallback() {
                        override fun onAudioDevicesAdded(addedDevices: Array<out AudioDeviceInfo>) {
                            val relevant = addedDevices.any {
                                it.type == AudioDeviceInfo.TYPE_BLUETOOTH_A2DP ||
                                    it.type == AudioDeviceInfo.TYPE_WIRED_HEADPHONES ||
                                    it.type == AudioDeviceInfo.TYPE_WIRED_HEADSET ||
                                    it.type == AudioDeviceInfo.TYPE_USB_HEADSET
                            }
                            if (relevant) events?.success(mapOf("added" to true))
                        }
                    }
                    am.registerAudioDeviceCallback(callback, null)
                }

                override fun onCancel(arguments: Any?) {
                    val cb = callback
                    val am = audioManager
                    if (cb != null && am != null) {
                        am.unregisterAudioDeviceCallback(cb)
                    }
                    callback = null
                    audioManager = null
                }
            })
    }
}
