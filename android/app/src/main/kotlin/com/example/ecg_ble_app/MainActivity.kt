package com.example.ecg_ble_app

import android.media.MediaScannerConnection
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
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
    }
}
