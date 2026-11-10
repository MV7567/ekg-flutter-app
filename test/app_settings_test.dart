import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ecg_ble_app/settings/app_settings.dart';

void main() {
  test('saved theme text is read back', () {
    expect(AppSettings.parseThemeMode('dark'), ThemeMode.dark);
    expect(AppSettings.parseThemeMode('light'), ThemeMode.light);
    expect(AppSettings.parseThemeMode('system'), ThemeMode.system);
  });

  test('nothing saved or unknown text -> system', () {
    expect(AppSettings.parseThemeMode(null), ThemeMode.system);
    expect(AppSettings.parseThemeMode('purple'), ThemeMode.system);
  });

  test('every theme survives saving as its name', () {
    for (ThemeMode mode in ThemeMode.values) {
      expect(AppSettings.parseThemeMode(mode.name), mode);
    }
  });

  test('recording length: only values from the list, anything else -> manual', () {
    expect(AppSettings.parseRecordingSeconds(30), 30);
    expect(AppSettings.parseRecordingSeconds(300), 300);
    expect(AppSettings.parseRecordingSeconds(null), 0);   // nothing saved yet
    expect(AppSettings.parseRecordingSeconds(45), 0);     // not in the list
  });

  test('language: only a translated one, anything else -> like the phone', () {
    expect(AppSettings.parseLanguageCode('pl', ['en', 'pl']), 'pl');
    expect(AppSettings.parseLanguageCode('de', ['en', 'pl']), '');   // no app_de.arb (yet)
    expect(AppSettings.parseLanguageCode(null, ['en', 'pl']), '');   // nothing saved
  });

  test('every .arb file is a language: en and pl', () {
    expect(AppSettings.supportedLanguageCodes, containsAll(['en', 'pl']));
  });
}
