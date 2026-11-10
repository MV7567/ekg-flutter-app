import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ecg_ble_app/l10n/app_localizations.dart';
import 'package:ecg_ble_app/widgets/heart_rate_text.dart';

void main() {
  testWidgets('the heart jumps on a beat and comes back to its size', (tester) async {
    ValueNotifier<int?> bpm = ValueNotifier(72);
    ValueNotifier<int> beats = ValueNotifier(0);
    addTearDown(bpm.dispose);
    addTearDown(beats.dispose);

    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: HeartRateText(bpm: bpm, beats: beats)),
    ));
    await tester.pumpAndSettle();

    // the size of the heart = the ScaleTransition around the heart icon
    double heartScale() => tester
        .widget<ScaleTransition>(find.ancestor(
          of: find.byIcon(Icons.favorite),
          matching: find.byType(ScaleTransition),
        ))
        .scale
        .value;

    expect(find.text('72 bpm'), findsOneWidget);
    expect(heartScale(), 1.0);

    beats.value++;                                            // a beat
    await tester.pump();                                      // the animation starts
    await tester.pump(const Duration(milliseconds: 75));      // the top of the jump (30 % of 250 ms)
    expect(heartScale(), greaterThan(1.3));

    await tester.pumpAndSettle();                             // the animation ends
    expect(heartScale(), 1.0);
  });

  testWidgets('without beats the heart stands still', (tester) async {
    ValueNotifier<int?> bpm = ValueNotifier(null);
    addTearDown(bpm.dispose);
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: HeartRateText(bpm: bpm)),
    ));
    await tester.pumpAndSettle();
    expect(find.text('-- bpm'), findsOneWidget);
  });
}
