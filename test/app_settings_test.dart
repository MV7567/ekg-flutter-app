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
}
