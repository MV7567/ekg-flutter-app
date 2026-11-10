import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ecg_ble_app/l10n/app_localizations.dart';
import 'package:ecg_ble_app/screens/device_screen.dart';
import 'package:ecg_ble_app/screens/instructions_screen.dart';

void main() {
  test('recording length labels', () {
    expect(DeviceScreen.durationLabel(0), 'Manual');
    expect(DeviceScreen.durationLabel(10), '10 s');
    expect(DeviceScreen.durationLabel(60), '1 min');
    expect(DeviceScreen.durationLabel(300), '5 min');
    expect(DeviceScreen.durationLabel(90), '1:30');
  });

  // the screen with the translations, Polish because its texts are the longest
  Future<void> pumpInstructions(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('pl'),
      theme: ThemeData(brightness: Brightness.dark),
      home: const InstructionsScreen(),
    ));
    await tester.pumpAndSettle();   // translations load asynchronously
  }

  testWidgets('instructions show the 3 electrodes', (tester) async {
    // a very tall screen: ListView builds only what is visible, here everything is
    await pumpInstructions(tester, const Size(1080, 8000));
    expect(find.text('RA'), findsOneWidget);
    expect(find.text('LA'), findsOneWidget);
    expect(find.text('LL'), findsOneWidget);
  });

  testWidgets('instructions fit in landscape, dark, Polish', (tester) async {
    await pumpInstructions(tester, const Size(2400, 1080));
    expect(tester.takeException(), isNull);   // no overflow
  });
}
