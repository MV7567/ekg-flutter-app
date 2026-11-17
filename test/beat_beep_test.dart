import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ecg_ble_app/beat_beep.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const MethodChannel channel = MethodChannel('ecg_ble_app/beep');
  TestDefaultBinaryMessenger messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  test('play() asks Android for a "beep"', () async {
    List<String> calls = [];
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call.method);
      return null;
    });
    await BeatBeep.play();
    expect(calls, ['beep']);
  });

  test('an Android error (no free audio channel) does not crash', () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      throw PlatformException(code: 'NO_TONE', message: 'no audio');
    });
    await BeatBeep.play();   // must simply finish
  });

  test('no Android behind it (no handler) does not crash', () async {
    await BeatBeep.play();
  });
}
