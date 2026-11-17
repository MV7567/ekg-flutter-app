import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:ecg_ble_app/l10n/app_localizations.dart';
import 'package:ecg_ble_app/screens/device_screen.dart';
import 'package:ecg_ble_app/widgets/ekg_chart.dart';

void main() {
  // no phone in a test: the settings are "saved" in memory instead
  SharedPreferencesAsyncPlatform.instance = InMemorySharedPreferencesAsync.empty();

  // the test signal screen: no ESP32 needed, the generator sends the packets
  testWidgets('preview: the chart gets the signal, no recording, stop ends it', (tester) async {
    // wide: the test font draws every letter as a wide square, "Length: Manual (until STOP)" needs room
    tester.view.physicalSize = const Size(1600, 3200);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const DeviceScreen.testSignal(),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('PREVIEW'));
    await tester.pump();
    expect(find.text('STOP PREVIEW'), findsOneWidget);
    expect(find.textContaining('nothing is saved'), findsOneWidget);
    expect(find.text('START'), findsOneWidget);       // START is still there: records from the preview
    expect(find.textContaining('Mark event'), findsNothing);   // no recording = no events

    await tester.pump(const Duration(seconds: 3));    // 3 s of the test signal
    EkgChart chart = tester.widget(find.byType(EkgChart));
    expect(chart.buffer.length, greaterThan(0));      // the chart got samples

    await tester.tap(find.text('STOP PREVIEW'));
    await tester.pump();
    expect(find.text('PREVIEW'), findsOneWidget);
    expect(find.textContaining('nothing is saved'), findsNothing);
    await tester.pump(const Duration(seconds: 1));    // the generator really stopped: no timer left
  });
}
