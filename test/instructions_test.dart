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
    // the roles, not the letters on the cable: red "-", yellow "+", green the reference
    expect(find.text('−'), findsOneWidget);
    expect(find.text('+'), findsOneWidget);
    expect(find.text('REF'), findsOneWidget);
    expect(find.text('Minus (−): pod prawym obojczykiem'), findsOneWidget);
    expect(find.text('Plus (+): pod lewym obojczykiem'), findsOneWidget);
    // the other two tested sets and the rule that keeps them apart
    expect(find.textContaining('Wariant 2'), findsOneWidget);
    expect(find.textContaining('Wariant 3, nadgarstki'), findsOneWidget);
    expect(find.textContaining('czerwona zawsze u góry po prawej'), findsOneWidget);
    expect(find.textContaining('zamień miejscami czerwoną i żółtą'), findsOneWidget);
    // the leads of the kit's cable, under every electrode (the screen is in Polish)
    expect(find.text('zielony przewód, napis R'), findsOneWidget);
    expect(find.text('czerwony przewód, bez napisu'), findsOneWidget);
    expect(find.text('żółty przewód, napis L'), findsOneWidget);
  });

  test('readable letters on every lead color', () {
    expect(InstructionsScreen.textOn(InstructionsScreen.leftLegColor), Colors.black);   // on yellow
    expect(InstructionsScreen.textOn(InstructionsScreen.leftArmColor), Colors.white);   // on red
  });

  testWidgets('instructions fit in landscape, dark, Polish', (tester) async {
    await pumpInstructions(tester, const Size(2400, 1080));
    expect(tester.takeException(), isNull);   // no overflow
  });
}
