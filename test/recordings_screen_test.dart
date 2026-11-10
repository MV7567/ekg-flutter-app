import 'package:flutter/material.dart';
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
}
