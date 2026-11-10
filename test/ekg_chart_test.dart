import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ecg_ble_app/ekg_buffer.dart';
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

  // which chart colors a screen in the given theme gets, and the chart draws in it without errors
  Future<EkgChartColors> colorsIn(WidgetTester tester, Brightness brightness) async {
    EkgBuffer buffer = EkgBuffer(1250)..addAll(List.filled(1250, 0.5));
    addTearDown(buffer.dispose);
    late EkgChartColors colors;
    await tester.pumpWidget(MaterialApp(
      theme: ThemeData(brightness: brightness),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(builder: (context) {
        colors = EkgChartColors.of(context);
        return EkgChart(buffer: buffer, sampleRateHz: 250);
      }),
    ));
    await tester.pumpAndSettle();
    return colors;
  }

  testWidgets('light theme: pink paper', (tester) async {
    expect(await colorsIn(tester, Brightness.light), same(EkgChartColors.paper));
  });

  testWidgets('dark theme: dark monitor', (tester) async {
    expect(await colorsIn(tester, Brightness.dark), same(EkgChartColors.monitor));
  });

  test('paper and monitor: the line and the buttons stand out from the background', () {
    for (EkgChartColors c in [EkgChartColors.paper, EkgChartColors.monitor]) {
      double bg = c.background.computeLuminance();
      // the difference in brightness, light paper -> dark line, dark monitor -> bright line
      expect((c.line.computeLuminance() - bg).abs(), greaterThan(0.3));
      expect((c.controls.computeLuminance() - bg).abs(), greaterThan(0.3));
    }
  });
}
