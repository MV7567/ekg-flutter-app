import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ecg_ble_app/l10n/app_localizations.dart';
import 'package:ecg_ble_app/widgets/signal_strength_text.dart';

void main() {
  test('strength: the usual BLE limits', () {
    expect(SignalStrengthText.strength(-40), SignalStrength.strong);
    expect(SignalStrengthText.strength(-70), SignalStrength.strong);   // the border is still strong
    expect(SignalStrengthText.strength(-71), SignalStrength.fair);
    expect(SignalStrengthText.strength(-85), SignalStrength.fair);
    expect(SignalStrengthText.strength(-86), SignalStrength.weak);
    expect(SignalStrengthText.strength(-100), SignalStrength.weak);
  });

  testWidgets('nothing before the first read, then the value and the level', (tester) async {
    ValueNotifier<int?> rssi = ValueNotifier(null);
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('pl'),
      home: Scaffold(body: Center(child: SignalStrengthText(rssi: rssi))),
    ));
    expect(find.textContaining('Sygnał BLE'), findsNothing);

    rssi.value = -62;
    await tester.pump();
    expect(find.text('Sygnał BLE: -62 dBm (silny)'), findsOneWidget);
    expect(find.byIcon(Icons.signal_cellular_alt), findsOneWidget);

    rssi.value = -91;
    await tester.pump();
    expect(find.text('Sygnał BLE: -91 dBm (słaby – przysuń telefon bliżej)'), findsOneWidget);
    expect(find.byIcon(Icons.signal_cellular_alt_1_bar), findsOneWidget);
  });

  testWidgets('without the advanced features: only the bars and the level, no dBm', (tester) async {
    ValueNotifier<int?> rssi = ValueNotifier(-62);
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('pl'),
      home: Scaffold(body: Center(child: SignalStrengthText(rssi: rssi, showDbm: false))),
    ));
    expect(find.text('Sygnał BLE: silny'), findsOneWidget);
    expect(find.textContaining('dBm'), findsNothing);
    expect(find.byIcon(Icons.signal_cellular_alt), findsOneWidget);
  });
}
