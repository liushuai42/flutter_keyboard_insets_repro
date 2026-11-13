package com.example.keyboard_insets_repro

import android.graphics.Rect
import android.os.Build
import android.os.Bundle
import android.util.Log
import android.view.WindowInsets
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.ArrayDeque

class MainActivity : FlutterActivity() {
    companion object {
        private const val TAG = "KeyboardInsetsRepro"
        private const val METHOD_CHANNEL = "keyboard_insets_repro/methods"
        private const val MAX_EVENTS = 120
    }

    private val eventHistory = ArrayDeque<Map<String, Any?>>()
    private var methodChannel: MethodChannel? = null
    private var lifecycleState = "initialized"

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        lifecycleState = "created"
        record("onCreate")
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        methodChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            METHOD_CHANNEL,
        ).also { channel ->
            channel.setMethodCallHandler { call, result ->
                when (call.method) {
                    "snapshot" -> result.success(buildSnapshot("dart snapshot"))
                    "history" -> result.success(eventHistory.toList())
                    "requestApplyInsets" -> {
                        window.decorView.requestApplyInsets()
                        window.decorView.post {
                            record("requestApplyInsets post")
                        }
                        result.success(buildSnapshot("requestApplyInsets"))
                    }
                    else -> result.notImplemented()
                }
            }
        }
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        methodChannel?.setMethodCallHandler(null)
        methodChannel = null
        super.cleanUpFlutterEngine(flutterEngine)
    }

    override fun onStart() {
        super.onStart()
        lifecycleState = "started"
        record("onStart")
    }

    override fun onResume() {
        super.onResume()
        lifecycleState = "resumed"
        record("onResume")
    }

    override fun onPause() {
        lifecycleState = "paused"
        record("onPause before super")
        super.onPause()
    }

    override fun onStop() {
        lifecycleState = "stopped"
        record("onStop before super")
        super.onStop()
    }

    override fun onWindowFocusChanged(hasFocus: Boolean) {
        super.onWindowFocusChanged(hasFocus)
        record("onWindowFocusChanged($hasFocus)")
    }

    private fun record(reason: String): Map<String, Any?> {
        val snapshot = buildSnapshot(reason)
        if (eventHistory.size >= MAX_EVENTS) {
            eventHistory.removeFirst()
        }
        eventHistory.addLast(snapshot)
        Log.d(TAG, snapshot.toString())
        return snapshot
    }

    private fun buildSnapshot(reason: String): Map<String, Any?> {
        val decorView = window.decorView
        val visibleFrame = Rect()
        decorView.getWindowVisibleDisplayFrame(visibleFrame)

        var imeVisible: Boolean? = null
        var imeBottom: Int? = null
        var systemBarsBottom: Int? = null
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            decorView.rootWindowInsets?.let { insets ->
                imeVisible = insets.isVisible(WindowInsets.Type.ime())
                imeBottom = insets.getInsets(WindowInsets.Type.ime()).bottom
                systemBarsBottom = insets.getInsets(WindowInsets.Type.systemBars()).bottom
            }
        }

        return linkedMapOf(
            "timestampMs" to System.currentTimeMillis(),
            "reason" to reason,
            "lifecycle" to lifecycleState,
            "windowFocus" to decorView.hasWindowFocus(),
            "imeVisible" to imeVisible,
            "imeBottom" to imeBottom,
            "systemBarsBottom" to systemBarsBottom,
            "decorWidth" to decorView.width,
            "decorHeight" to decorView.height,
            "visibleFrameTop" to visibleFrame.top,
            "visibleFrameBottom" to visibleFrame.bottom,
            "visibleFrameHeight" to visibleFrame.height(),
            "softInputMode" to window.attributes.softInputMode,
            "sdkInt" to Build.VERSION.SDK_INT,
            "device" to "${Build.MANUFACTURER} ${Build.MODEL}",
        )
    }
}
