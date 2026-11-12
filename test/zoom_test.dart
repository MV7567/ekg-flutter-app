import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ecg_ble_app/ekg_auto_scale.dart';
import 'package:ecg_ble_app/ekg_buffer.dart';
import 'package:ecg_ble_app/l10n/app_localizations.dart';
import 'package:ecg_ble_app/widgets/ekg_chart.dart';
import 'package:ecg_ble_app/widgets/zoom_selector.dart';

void main() {
  AppLocalizations en = lookupAppLocalizations(const Locale('en'));
  const double auto = EkgChart.autoZoom;

  test('full screen zoom button: Auto -> ×1 -> ×2 -> ×4 -> ×8 -> Auto', () {
    expect(ZoomSelector.next(auto), 0.5);
    expect(ZoomSelector.next(0.5), 0.25);
    expect(ZoomSelector.next(0.25), 0.125);
    expect(ZoomSelector.next(0.125), 0.0625);
    expect(ZoomSelector.next(0.0625), auto);
    expect(ZoomSelector.next(0.3), auto);   // unknown value -> the first option
  });

  test('zoom labels', () {
    expect([for (double o in ZoomSelector.options) ZoomSelector.label(o, en)], ['Auto', '×1', '×2', '×4', '×8']);
  });

  test('scale text shows ×8 exactly: 0.0625 mV, not 0.063', () {
    expect(EkgChart.scaleLabel(en, 0.2, 0.0625), '1 square: 0.2 s × 0.0625 mV');
  });

  // ---- Auto ----
  // a phone chart: 200 px high, ~15 px per big square -> ~6.6 squares above the 0 mV line
  const double half = 6.6;

  test('auto: small QRS (0.28 mV, like the first real recordings) -> ×8', () {
    // 0.28 / (6.6 * 0.0625) = 68 % of the half height: fits at ×8
    expect(EkgAutoScale.choose(0.28, half, 0.25), 0.0625);
  });

  test('auto: a normal 1 mV QRS -> ×2, a big 2.5 mV -> ×1', () {
    expect(EkgAutoScale.choose(1.0, half, 0.0625), 0.25);   // zoomed out at once
    expect(EkgAutoScale.choose(2.5, half, 0.25), 0.5);
  });

  test('auto: huge signal that fits nowhere -> ×1', () {
    expect(EkgAutoScale.choose(50, half, 0.125), 0.5);
  });

  test('auto: near the border it does not jump back and forth (hysteresis)', () {
    // 0.5 mV at ×4 takes 0.5 / (6.6 * 0.125) = 61 %: neither over 90 % nor would fit ×8 under 50 %
    expect(EkgAutoScale.choose(0.5, half, 0.125), 0.125);
    // a bit more or less does not change it either
    expect(EkgAutoScale.choose(0.45, half, 0.125), 0.125);
    expect(EkgAutoScale.choose(0.7, half, 0.125), 0.125);
  });

  EkgBuffer bufferOf(List<double> samples) {
    EkgBuffer b = EkgBuffer(samples.length)..addAll(samples);
    addTearDown(b.dispose);
    return b;
  }

  // 5 s with a 0.3 mV "beat" every second
  List<double> beats(double mv) => [for (int i = 0; i < 1250; i++) i % 250 == 100 ? mv : 0.0];

  test('auto peak: the usual beat height, one artifact is ignored', () {
    List<double> s = beats(0.3);
    expect(EkgAutoScale.typicalPeak(bufferOf(s), 250), closeTo(0.3, 1e-6));
    s[600] = 3.0;   // moving the cable once, 10x the beat
    expect(EkgAutoScale.typicalPeak(bufferOf(s), 250), closeTo(0.3, 1e-6));
  });

  test('auto peak: less than 1 s -> nothing decided yet', () {
    expect(EkgAutoScale.typicalPeak(bufferOf(List.filled(200, 0.3)), 250), isNull);
  });

  test('auto update: keeps the step when there is no signal yet', () {
    EkgAutoScale scale = EkgAutoScale();
    double start = scale.current;
    expect(scale.update(bufferOf(List.filled(100, 0.0)), 250, half), start);
  });

  testWidgets('zoom buttons fit on a small phone', (tester) async {
    tester.view.physicalSize = const Size(320 * 3, 640 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    double value = auto;
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Center(
          child: StatefulBuilder(
            builder: (context, setState) => ZoomSelector(value: value, onChanged: (v) => setState(() => value = v)),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);   // no overflow
    await tester.tap(find.text('×8'));
    await tester.pumpAndSettle();
    expect(value, 0.0625);
  });
}
