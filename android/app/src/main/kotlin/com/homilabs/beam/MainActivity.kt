package com.homilabs.beam

import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var torch: TorchEngine? = null
    private var events: EventChannel.EventSink? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val messenger = flutterEngine.dartExecutor.binaryMessenger
        val engine = TorchEngine(applicationContext) { state -> events?.success(state) }
        torch = engine

        EventChannel(messenger, "beam/torch_events").setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, sink: EventChannel.EventSink) {
                events = sink
                sink.success(engine.state())
            }
            override fun onCancel(arguments: Any?) { events = null }
        })

        MethodChannel(messenger, "beam/torch").setMethodCallHandler { call, result ->
            when (call.method) {
                "info" -> result.success(engine.info())
                "state" -> result.success(engine.state())
                "setTorch" -> {
                    engine.setTorch(call.argument<Boolean>("on") == true, call.argument<Int>("strength"))
                    result.success(null)
                }
                "setStrength" -> {
                    engine.setStrength(call.argument<Int>("strength") ?: 1)
                    result.success(null)
                }
                "playPattern" -> {
                    val durations = call.argument<List<Int>>("durations") ?: emptyList()
                    engine.playPattern(durations, call.argument<Boolean>("repeat") == true, call.argument<Int>("strength"))
                    result.success(null)
                }
                "stopPattern" -> { engine.stopPattern(); result.success(null) }
                else -> result.notImplemented()
            }
        }

        MethodChannel(messenger, "beam/screen").setMethodCallHandler { call, result ->
            when (call.method) {
                // -1 restores the user's system brightness; 0..1 overrides it for this window only.
                "setBrightness" -> {
                    val value = (call.argument<Double>("value") ?: -1.0).toFloat()
                    window.attributes = window.attributes.apply {
                        screenBrightness = if (value < 0f) WindowManager.LayoutParams.BRIGHTNESS_OVERRIDE_NONE
                        else value.coerceIn(0.01f, 1f)
                    }
                    result.success(null)
                }
                "keepOn" -> {
                    if (call.argument<Boolean>("on") == true) window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                    else window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onStop() {
        super.onStop()
        // A strobe must never keep running unseen in the background.
        // A steady torch deliberately stays on, like the system quick-setting.
        torch?.let { if (it.patternRunning) it.stopPattern() }
    }

    override fun onDestroy() {
        // Swiping the app away turns the light off rather than leaving it orphaned.
        torch?.shutdown(turnOff = isFinishing)
        torch = null
        super.onDestroy()
    }
}
