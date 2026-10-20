package com.muziczz.muziczz

import android.content.Intent
import android.media.MediaRouter2
import android.provider.Settings
import io.flutter.plugin.common.MethodChannel
import android.app.NotificationManager
import android.content.Context
import android.os.Build
import android.os.Bundle
import android.icu.text.Transliterator
import android.view.WindowManager
import java.util.concurrent.Executors
import io.flutter.embedding.engine.FlutterEngine
import com.muziczz.muziczz.musicvisual.poc.AndroidVisualizerPocPlugin
import com.ryanheise.audioservice.AudioServiceFragmentActivity

class MainActivity : AudioServiceFragmentActivity() {
    private var androidVisualizerPoc: AndroidVisualizerPocPlugin? = null
    private val lyricsExecutor = Executors.newSingleThreadExecutor()

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        removeLegacyDownloaderState()
    }

    override fun onDestroy() {
        androidVisualizerPoc?.dispose()
        androidVisualizerPoc = null
        lyricsExecutor.shutdownNow()
        super.onDestroy()
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "muzicz/lyrics")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "readAiConfig", "writeAiConfig" -> {
                        lyricsExecutor.execute {
                            try {
                                val vault = LyricsSettingsVault(this)
                                val value = if (call.method == "readAiConfig") vault.read() else {
                                    vault.write(call.arguments as? String)
                                    null
                                }
                                runOnUiThread { result.success(value) }
                            } catch (error: Exception) {
                                runOnUiThread { result.error("lyrics_vault", "Unable to access encrypted AI settings", null) }
                            }
                        }
                    }
                    "romanize" -> {
                        val text = call.arguments as? String ?: ""
                        lyricsExecutor.execute {
                            try {
                                val roman = Transliterator.getInstance("Any-Latin; Latin-ASCII").transliterate(text.take(50000))
                                runOnUiThread { result.success(roman) }
                            } catch (error: Exception) {
                                runOnUiThread { result.error("romanize", error.message, null) }
                            }
                        }
                    }
                    "keepScreenOn" -> {
                        if (call.arguments == true) window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                        else window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "muzicz/audio_output")
            .setMethodCallHandler { call, result ->
                if (call.method != "showOutputSwitcher") {
                    result.notImplemented()
                } else {
                    try {
                        // Public output-switcher API; older devices use system Bluetooth settings.
                        val shown = Build.VERSION.SDK_INT >= 34 &&
                            MediaRouter2.getInstance(this).showSystemOutputSwitcher()
                        if (!shown) startActivity(Intent(Settings.ACTION_BLUETOOTH_SETTINGS))
                        result.success(null)
                    } catch (error: Exception) {
                        result.error("audio_output", error.message, null)
                    }
                }
            }
        androidVisualizerPoc = AndroidVisualizerPocPlugin.register(
            flutterEngine.dartExecutor.binaryMessenger
        )
    }

    private fun removeLegacyDownloaderState() {
        val downloadPreferences = getSharedPreferences(
            "download_foreground_service",
            Context.MODE_PRIVATE
        )
        if (downloadPreferences.contains("tasks")) {
            downloadPreferences.edit().remove("tasks").apply()
        }

        val appPreferences = getSharedPreferences(
            "FlutterSharedPreferences",
            Context.MODE_PRIVATE
        )
        if (appPreferences.contains("flutter.download_path")) {
            appPreferences.edit().remove("flutter.download_path").apply()
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val notificationManager = getSystemService(NotificationManager::class.java)
            if (notificationManager.getNotificationChannel("muzicz_download_progress") != null) {
                notificationManager.deleteNotificationChannel("muzicz_download_progress")
            }
        }
    }
}
