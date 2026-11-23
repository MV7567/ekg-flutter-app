import 'dart:io';
import 'package:flutter/material.dart';
import 'package:ecg_ble_app/recording/recording_file.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ecg_ble_app/screens/recordings_screen.dart';
import 'package:ecg_ble_app/l10n/app_localizations.dart';

void main() {
  AppLocalizations en = lookupAppLocalizations(const Locale('en'));
  test('start date with leading zeros', () {
    expect(RecordingsScreen.formatStart(DateTime(2026, 1, 4, 9, 5, 7), en), '2026-01-04 09:05:07');
    expect(RecordingsScreen.formatStart(null, en), 'Unknown date');
    expect(RecordingsScreen.formatStart(null, lookupAppLocalizations(const Locale('pl'))), 'Nieznana data');
  });

  test('duration as m:ss or h:mm:ss', () {
    expect(RecordingsScreen.formatDuration(Duration.zero), '0:00');
    expect(RecordingsScreen.formatDuration(const Duration(seconds: 65)), '1:05');
    expect(RecordingsScreen.formatDuration(const Duration(seconds: 3725)), '1:02:05');
  });

  test('size in B, kB, MB', () {
    expect(RecordingsScreen.formatSize(812), '812 B');
    expect(RecordingsScreen.formatSize(2048), '2.0 kB');
    expect(RecordingsScreen.formatSize(3500000), '3.3 MB');
  });

  // three made up recordings, the files are never read
  List<RecordingInfo> three = [
    for (int k = 1; k <= 3; k++)
      RecordingInfo(file: File('/tmp/ekg_$k.csv'), start: DateTime(2026, 11, 23, 21, k), deviceName: 'ESP32_EKG',
          formatVersion: 1, sizeBytes: 1000, duration: const Duration(minutes: 2)),
  ];
  Widget app() => MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('pl'),
        home: RecordingsScreen(load: () async => three),
      );

  testWidgets('selecting: a long press starts it, taps mark, select all, the X ends it', (tester) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    expect(find.byType(Checkbox), findsNothing);
    expect(find.text('Nagrania'), findsWidgets);

    await tester.longPress(find.text('2026-11-23 21:01:00'));
    await tester.pumpAndSettle();
    expect(find.text('Zaznaczono: 1'), findsOneWidget);
    expect(find.byType(Checkbox), findsNWidgets(3));
    expect(find.byType(PopupMenuButton<String>), findsNothing);   // no ⋮ while selecting

    await tester.tap(find.text('2026-11-23 21:02:00'));   // a tap now marks, does not open
    await tester.pumpAndSettle();
    expect(find.text('Zaznaczono: 2'), findsOneWidget);
    await tester.tap(find.text('2026-11-23 21:02:00'));   // and unmarks
    await tester.pumpAndSettle();
    expect(find.text('Zaznaczono: 1'), findsOneWidget);

    await tester.tap(find.byTooltip('Zaznacz wszystkie'));
    await tester.pumpAndSettle();
    expect(find.text('Zaznaczono: 3'), findsOneWidget);
    expect(find.byTooltip('Udostępnij zaznaczone nagrania'), findsOneWidget);

    await tester.tap(find.byTooltip('Zakończ zaznaczanie'));
    await tester.pumpAndSettle();
    expect(find.byType(Checkbox), findsNothing);
    expect(find.byType(PopupMenuButton<String>), findsNWidgets(3));
  });

  testWidgets('unmarking the last one ends selecting, "Select" in the menu starts it', (tester) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    await tester.tap(find.byType(PopupMenuButton<String>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Zaznacz'));
    await tester.pumpAndSettle();
    expect(find.text('Zaznaczono: 1'), findsOneWidget);
    await tester.tap(find.byType(Checkbox).first);
    await tester.pumpAndSettle();
    expect(find.byType(Checkbox), findsNothing);
  });
}
