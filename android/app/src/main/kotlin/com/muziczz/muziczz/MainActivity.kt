package com.muziczz.muziczz

import android.app.NotificationManager
import android.content.Context
import android.os.Build
import android.os.Bundle
import io.flutter.embedding.engine.FlutterEngine
import com.muziczz.muziczz.musicvisual.poc.AndroidVisualizerPocPlugin
import com.ryanheise.audioservice.AudioServiceFragmentActivity

class MainActivity : AudioServiceFragmentActivity() {
    private var androidVisualizerPoc: AndroidVisualizerPocPlugin? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        removeLegacyDownloaderState()
    }

    override fun onDestroy() {
        androidVisualizerPoc?.dispose()
        androidVisualizerPoc = null
        super.onDestroy()
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
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
