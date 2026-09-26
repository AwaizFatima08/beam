package com.homilabs.beam

import android.content.Context
import android.hardware.camera2.CameraAccessException
import android.hardware.camera2.CameraCharacteristics
import android.hardware.camera2.CameraManager
import android.os.Build
import android.os.Handler
import android.os.HandlerThread
import android.os.Looper
import android.os.SystemClock
import android.util.Log

/**
 * Owns the camera flash. Everything that touches CameraManager runs on one
 * background thread so strobe timing is not at the mercy of the UI thread.
 *
 * No CAMERA permission is needed: setTorchMode and the strength APIs only
 * need the flash unit, not the camera stream.
 */
class TorchEngine(context: Context, private val onState: (Map<String, Any?>) -> Unit) {
    private val cameraManager = context.getSystemService(Context.CAMERA_SERVICE) as CameraManager
    private val thread = HandlerThread("beam-torch").apply { start() }
    private val worker = Handler(thread.looper)
    private val main = Handler(Looper.getMainLooper())
    private val debuggable = (context.applicationInfo.flags and android.content.pm.ApplicationInfo.FLAG_DEBUGGABLE) != 0

    val cameraId: String? = findFlashCamera()
    val maxStrength: Int = readMaxStrength()
    val defaultStrength: Int = readDefaultStrength()

    @Volatile var torchOn = false
        private set
    @Volatile var strength: Int = defaultStrength
        private set

    // Bumped whenever a pattern starts or stops; a running pattern exits as
    // soon as it sees a generation that is not its own.
    @Volatile private var patternGeneration = 0
    @Volatile var patternRunning = false
        private set

    private val torchCallback = object : CameraManager.TorchCallback() {
        override fun onTorchModeChanged(id: String, enabled: Boolean) {
            if (id != cameraId) return
            torchOn = enabled
            // During a pattern the flash toggles many times a second; the UI
            // only needs the pattern state, not every blink.
            if (!patternRunning) emit()
        }

        override fun onTorchModeUnavailable(id: String) {
            if (id != cameraId) return
            torchOn = false
            emit(error = "unavailable")
        }

        override fun onTorchStrengthLevelChanged(id: String, newStrengthLevel: Int) {
            if (id != cameraId) return
            strength = newStrengthLevel
            if (!patternRunning) emit()
        }
    }

    init {
        cameraManager.registerTorchCallback(torchCallback, worker)
    }

    val hasFlash get() = cameraId != null
    val supportsStrength get() = maxStrength > 1

    fun info(): Map<String, Any?> = mapOf(
        "hasFlash" to hasFlash,
        "maxStrength" to maxStrength,
        "defaultStrength" to defaultStrength,
        "sdkInt" to Build.VERSION.SDK_INT,
    )

    fun state(): Map<String, Any?> = mapOf(
        "on" to torchOn,
        "strength" to strength,
        "patternRunning" to patternRunning,
    )

    /** Steady light. Stops any running pattern first. */
    fun setTorch(on: Boolean, level: Int?) {
        stopPatternInternal()
        worker.post {
            if (on && level != null) applyStrength(level) else setMode(on)
        }
    }

    /** Changes brightness; turns the torch on if it is not already. */
    fun setStrength(level: Int) {
        worker.post { applyStrength(level) }
    }

    /**
     * Plays [durations] (milliseconds, alternating on/off, starting with on).
     * With [repeat] the pattern loops until [stopPattern]. Deadlines are
     * absolute so latency in setTorchMode does not accumulate as drift.
     */
    fun playPattern(durations: List<Int>, repeat: Boolean, level: Int?) {
        if (cameraId == null || durations.isEmpty()) return
        val gen = ++patternGeneration
        patternRunning = true
        emit()
        worker.post {
            var next = SystemClock.uptimeMillis()
            var pass = 0
            try {
                do {
                    var worstLag = 0L
                    for ((i, d) in durations.withIndex()) {
                        if (gen != patternGeneration) return@post
                        val on = i % 2 == 0
                        if (d > 0) {
                            if (on && level != null && supportsStrength) applyStrength(level) else setMode(on)
                        }
                        // How late the switch landed versus its deadline (debug timing check).
                        worstLag = maxOf(worstLag, SystemClock.uptimeMillis() - next)
                        next += d
                        val wait = next - SystemClock.uptimeMillis()
                        if (wait > 0) SystemClock.sleep(wait)
                    }
                    pass++
                    if (debuggable && pass % 10 == 1) Log.d(TAG, "pattern pass $pass: worst switch lag ${worstLag}ms")
                } while (repeat && gen == patternGeneration)
            } finally {
                if (gen == patternGeneration) {
                    setMode(false)
                    patternRunning = false
                    emit(event = "patternDone")
                }
            }
        }
    }

    fun stopPattern() {
        stopPatternInternal()
        worker.post { setMode(false); emit() }
    }

    private fun stopPatternInternal() {
        if (!patternRunning) return
        patternGeneration++
        patternRunning = false
    }

    fun shutdown(turnOff: Boolean) {
        stopPatternInternal()
        if (turnOff) worker.post { setMode(false) }
        worker.post {
            cameraManager.unregisterTorchCallback(torchCallback)
            thread.quitSafely()
        }
    }

    // ---- camera plumbing (worker thread only) ----

    private fun setMode(on: Boolean) {
        val id = cameraId ?: return
        try {
            cameraManager.setTorchMode(id, on)
            torchOn = on
        } catch (e: CameraAccessException) {
            Log.w(TAG, "setTorchMode($on) failed", e)
            emit(error = "cameraInUse")
        } catch (e: IllegalArgumentException) {
            Log.w(TAG, "setTorchMode($on) failed", e)
            emit(error = "noFlash")
        }
    }

    private fun applyStrength(level: Int) {
        val id = cameraId ?: return
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU && supportsStrength) {
            val clamped = level.coerceIn(1, maxStrength)
            try {
                cameraManager.turnOnTorchWithStrengthLevel(id, clamped)
                torchOn = true
                strength = clamped
                return
            } catch (e: Exception) {
                Log.w(TAG, "turnOnTorchWithStrengthLevel($clamped) failed", e)
            }
        }
        setMode(true)
    }

    private fun emit(error: String? = null, event: String? = null) {
        val payload = state().toMutableMap()
        if (error != null) payload["error"] = error
        if (event != null) payload["event"] = event
        main.post { onState(payload) }
    }

    private fun findFlashCamera(): String? = try {
        val ids = cameraManager.cameraIdList
        // Prefer the rear camera's flash; fall back to any camera with one.
        ids.firstOrNull { id ->
            val c = cameraManager.getCameraCharacteristics(id)
            c.get(CameraCharacteristics.FLASH_INFO_AVAILABLE) == true &&
                c.get(CameraCharacteristics.LENS_FACING) == CameraCharacteristics.LENS_FACING_BACK
        } ?: ids.firstOrNull { id ->
            cameraManager.getCameraCharacteristics(id).get(CameraCharacteristics.FLASH_INFO_AVAILABLE) == true
        }
    } catch (e: Exception) {
        Log.w(TAG, "no flash camera", e)
        null
    }

    private fun readMaxStrength(): Int {
        val id = cameraId ?: return 0
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) return 1
        return cameraManager.getCameraCharacteristics(id)
            .get(CameraCharacteristics.FLASH_INFO_STRENGTH_MAXIMUM_LEVEL) ?: 1
    }

    private fun readDefaultStrength(): Int {
        val id = cameraId ?: return 0
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) return 1
        return cameraManager.getCameraCharacteristics(id)
            .get(CameraCharacteristics.FLASH_INFO_STRENGTH_DEFAULT_LEVEL) ?: 1
    }

    companion object { private const val TAG = "BeamTorch" }
}
