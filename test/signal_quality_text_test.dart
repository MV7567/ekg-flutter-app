import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ecg_ble_app/l10n/app_localizations.dart';
import 'package:ecg_ble_app/signal_quality.dart';
import 'package:ecg_ble_app/widgets/signal_quality_text.dart';

void main() {
  test('every state has a text in every language', () {
    for (Locale locale in AppLocalizations.supportedLocales) {
      AppLocalizations t = lookupAppLocalizations(locale);
      for (SignalQuality q in SignalQuality.values) {
        expect(SignalQualityText.text(t, q), isNotEmpty);
      }
    }
  });

  test('colors: green only for good, red when there is no usable signal', () {
    expect(SignalQualityText.look(SignalQuality.good).$2, Colors.green);
    expect(SignalQualityText.look(SignalQuality.noisy).$2, Colors.orange);
    expect(SignalQualityText.look(SignalQuality.electrodeOff).$2, Colors.red);
    expect(SignalQualityText.look(SignalQuality.flat).$2, Colors.red);
  });

  testWidgets('the text changes with the value, a long one fits on a narrow phone', (tester) async {
    tester.view.physicalSize = const Size(320 * 3, 640 * 3);   // a small phone
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    ValueNotifier<SignalQuality> quality = ValueNotifier(SignalQuality.checking);
    addTearDown(quality.dispose);

    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('pl'),
      home: Scaffold(body: Center(child: SignalQualityText(quality: quality))),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Sprawdzam sygnał…'), findsOneWidget);

    quality.value = SignalQuality.noisy;   // the longest text
    await tester.pump();
    expect(find.textContaining('Zaszumiony'), findsOneWidget);
    expect(tester.takeException(), isNull);   // no overflow
  });
}
