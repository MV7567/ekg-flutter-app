import 'package:flutter/foundation.dart';   // debugPrint
import 'package:flutter/services.dart';     // MethodChannel, PlatformException

// the short "beep" on every heart beat, like a hospital monitor
// the sound itself is made by Android (ToneGenerator in MainActivity.kt), this only asks for it
class BeatBeep {
  static const MethodChannel _channel = MethodChannel('ecg_ble_app/beep');

  // not awaited by the caller: the beep must never slow down the processing of the samples
  static Future<void> play() async {
    try {
      await _channel.invokeMethod('beep');
    } on PlatformException catch (e) {
      debugPrint("Beep error: ${e.message}");   // no free audio channel, no beep this time
    } on MissingPluginException {
      // no Android behind it (tests, another platform): silently no beep
    }
  }
}
