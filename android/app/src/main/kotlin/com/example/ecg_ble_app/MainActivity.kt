package com.example.ecg_ble_app

import android.media.AudioManager
import android.media.MediaScannerConnection
import android.media.ToneGenerator
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    // makes the "beep" on every heart beat, created at the first beep, freed when the app closes
    private var toneGenerator: ToneGenerator? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // channel used by the app to register a finished recording in the Android media database,
        // without it some file managers (e.g. MIUI) and the PC over USB don't show the new file
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "ecg_ble_app/media_scanner")
            .setMethodCallHandler { call, result ->
                if (call.method == "scanFile") {
                    val path = call.argument<String>("path")
                    if (path == null) {
                        result.error("NO_PATH", "path is missing", null)
                    } else {
                        MediaScannerConnection.scanFile(this, arrayOf(path), arrayOf("text/csv"), null)
                        result.success(null)
                    }
                } else {
                    result.notImplemented()
                }
            }

        // channel for the short beep on every heart beat (like a hospital monitor),
        // ToneGenerator plays a built-in tone at once, no sound file and no extra package needed
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "ecg_ble_app/beep")
            .setMethodCallHandler { call, result ->
                if (call.method == "beep") {
                    try {
                        // STREAM_MUSIC: the volume buttons (media volume) change how loud it is
                        // 80 = 80 % of that volume
                        val tones = toneGenerator ?: ToneGenerator(AudioManager.STREAM_MUSIC, 80)
                        toneGenerator = tones
                        tones.startTone(ToneGenerator.TONE_PROP_BEEP, 80)   // 80 ms, shorter than the shortest RR (300 ms)
                        result.success(null)
                    } catch (e: RuntimeException) {
                        // the phone has no free audio channel right now, no beep, the app goes on
                        result.error("NO_TONE", e.message, null)
                    }
                } else {
                    result.notImplemented()
                }
            }
    }

    override fun onDestroy() {
        toneGenerator?.release()   // gives the audio channel back to the system
        toneGenerator = null
        super.onDestroy()
    }
}
