import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ecg_ble_app/l10n/app_localizations.dart';
import 'package:ecg_ble_app/widgets/ekg_chart.dart';

void main() {
  // lookupAppLocalizations gives the texts of one language without a running app
  AppLocalizations en = lookupAppLocalizations(const Locale('en'));
  AppLocalizations pl = lookupAppLocalizations(const Locale('pl'));

  test('scale label shows all digits, without zeros at the end', () {
    expect(EkgChart.scaleLabel(en, 0.2, 0.5), '1 square: 0.2 s × 0.5 mV');
    expect(EkgChart.scaleLabel(en, 0.2, 0.25), '1 square: 0.2 s × 0.25 mV');
    expect(EkgChart.scaleLabel(en, 0.2, 0.125), '1 square: 0.2 s × 0.125 mV');   // was 0.13
    expect(EkgChart.scaleLabel(en, 0.2, 1), '1 square: 0.2 s × 1 mV');
  });

  test('scale label in Polish', () {
    expect(EkgChart.scaleLabel(pl, 0.2, 0.25), '1 kratka: 0.2 s × 0.25 mV');
  });
}
