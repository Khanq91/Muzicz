package com.muziczz.muziczz.musicvisual.poc

import android.media.audiofx.Visualizer
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import kotlin.math.abs
import kotlin.math.sqrt

/**
 * Phase-3 Android-only POC. This is intentionally registered by the app rather
 * than merged into the production music_visual controller.
 */
class AndroidVisualizerPocPlugin private constructor(
    messenger: BinaryMessenger,
) : MethodChannel.MethodCallHandler, EventChannel.StreamHandler {
    companion object {
        private const val METHOD_CHANNEL =
            "muziczz/music_visual/android_visualizer_poc/methods"
        private const val EVENT_CHANNEL =
            "muziczz/music_visual/android_visualizer_poc/events"

        fun register(messenger: BinaryMessenger): AndroidVisualizerPocPlugin =
            AndroidVisualizerPocPlugin(messenger)
    }

    private val methodChannel = MethodChannel(messenger, METHOD_CHANNEL)
    private val eventChannel = EventChannel(messenger, EVENT_CHANNEL)
    private val mainHandler = Handler(Looper.getMainLooper())
    private var eventSink: EventChannel.EventSink? = null
    private var visualizer: Visualizer? = null
    private var attachedSessionId: Int? = null
    private var sequence = 0L

    init {
        methodChannel.setMethodCallHandler(this)
        eventChannel.setStreamHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "attach" -> {
                val sessionId = call.argument<Int>("audioSessionId")
                if (sessionId == null || sessionId <= 0) {
                    result.error("INVALID_SESSION", "audioSessionId must be positive", null)
                    return
                }
                try {
                    attach(sessionId)
                    result.success(null)
                } catch (security: SecurityException) {
                    releaseVisualizer()
                    result.error(
                        "RECORD_AUDIO_REQUIRED",
                        "Android Visualizer requires RECORD_AUDIO",
                        security.message,
                    )
                } catch (exception: Exception) {
                    releaseVisualizer()
                    result.error("ATTACH_FAILED", exception.message, null)
                }
            }

            "detach" -> {
                releaseVisualizer()
                result.success(null)
            }

            else -> result.notImplemented()
        }
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
        eventSink = events
    }

    override fun onCancel(arguments: Any?) {
        eventSink = null
        releaseVisualizer()
    }

    fun dispose() {
        releaseVisualizer()
        eventSink = null
        methodChannel.setMethodCallHandler(null)
        eventChannel.setStreamHandler(null)
    }

    private fun attach(sessionId: Int) {
        if (attachedSessionId == sessionId && visualizer?.enabled == true) return

        releaseVisualizer()
        val instance = Visualizer(sessionId)
        try {
            val captureRange = Visualizer.getCaptureSizeRange()
            instance.captureSize = 1024.coerceIn(captureRange[0], captureRange[1])
            val captureRate = (Visualizer.getMaxCaptureRate() / 2).coerceAtLeast(1)
            instance.setDataCaptureListener(
                object : Visualizer.OnDataCaptureListener {
                    override fun onWaveFormDataCapture(
                        visualizer: Visualizer,
                        waveform: ByteArray,
                        samplingRate: Int,
                    ) {
                        emitPacket(sessionId, waveform, samplingRate)
                    }

                    override fun onFftDataCapture(
                        visualizer: Visualizer,
                        fft: ByteArray,
                        samplingRate: Int,
                    ) = Unit
                },
                captureRate,
                true,
                false,
            )
            instance.enabled = true
            visualizer = instance
            attachedSessionId = sessionId
        } catch (exception: Exception) {
            runCatching { instance.enabled = false }
            instance.release()
            throw exception
        }
    }

    private fun emitPacket(sessionId: Int, waveform: ByteArray, samplingRateMilliHz: Int) {
        if (waveform.isEmpty()) return

        var squaredSum = 0.0
        var peak = 0.0
        for (sample in waveform) {
            // Visualizer waveform is unsigned 8-bit PCM centered at 128.
            val normalized = ((sample.toInt() and 0xff) - 128) / 128.0
            squaredSum += normalized * normalized
            peak = maxOf(peak, abs(normalized))
        }
        val rms = sqrt(squaredSum / waveform.size).coerceIn(0.0, 1.0)
        val packet = hashMapOf<String, Any>(
            "sequence" to sequence++,
            "timestampUs" to SystemClock.elapsedRealtimeNanos() / 1_000L,
            "sessionId" to sessionId,
            "sampleRateHz" to samplingRateMilliHz / 1_000,
            "rms" to rms,
            "peak" to peak.coerceIn(0.0, 1.0),
        )
        mainHandler.post { eventSink?.success(packet) }
    }

    private fun releaseVisualizer() {
        val current = visualizer
        visualizer = null
        attachedSessionId = null
        if (current != null) {
            runCatching { current.enabled = false }
            current.release()
        }
    }
}
