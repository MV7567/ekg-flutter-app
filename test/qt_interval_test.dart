import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ecg_ble_app/filters/biquad_filter.dart';
import 'package:ecg_ble_app/filters/zero_phase_filter.dart';
import 'package:ecg_ble_app/l10n/app_localizations.dart';
import 'package:ecg_ble_app/qrs_width.dart';
import 'package:ecg_ble_app/qt_interval.dart';
import 'package:ecg_ble_app/widgets/median_beat_chart.dart';
import 'package:ecg_ble_app/widgets/recording_stats_card.dart';

const int fs = 250;   // 1 sample = 4 ms

// one beat: flat, a QRS of 90 ms (a triangle up to 1 mV) starting at qrsStart,
// a T wave as a half sine from tStart to tEnd of height tHeight (negative = inverted)
List<double> beatWith({int length = 250, int qrsStart = 70, int tStart = 120, int tEnd = 165, double tHeight = 0.3}) {
  List<double> x = List.filled(length, 0);
  for (int i = 0; i <= 22; i++) {
    x[qrsStart + i] = 1 - (i - 11).abs() / 11;
  }
  for (int i = tStart; i <= tEnd; i++) {
    x[i] += tHeight * sin(pi * (i - tStart) / (tEnd - tStart));
  }
  return x;
}

void main() {
  test('QT on a beat with a known T end: within 20 ms, also with an inverted T', () {
    for (double height in [0.3, -0.3]) {
      List<double> x = beatWith(tHeight: height);
      QtMeasurement? qt = QtInterval.measure(x, 81, (70, 92), 1000, fs);
      expect(qt, isNotNull, reason: 'T $height');
      // the true QT: from the QRS start (70) to the T end (165) = 95 samples = 380 ms
      expect(qt!.qtMs, closeTo(380, 20), reason: 'T $height');
      expect(qt.tHeightMv.sign, height.sign);
    }
  });

  test('a T wave flatter than 20 % of the QRS: not measured', () {
    List<double> x = beatWith(tHeight: 0.15);   // 15 % of the 1 mV QRS
    expect(QtInterval.measure(x, 81, (70, 92), 1000, fs), isNull);
    expect(QtInterval.measure(x, 81, (70, 92), 1000, fs, minTShare: 0.1), isNotNull);
  });

  test('a lowered ST segment right after the QRS is not taken for the T wave', () {
    List<double> x = beatWith(tStart: 135, tEnd: 175, tHeight: 0.25);
    for (int i = 92; i < 130; i++) {
      x[i] -= 0.3 * sin(pi * (i - 92) / 38);   // a deeper dip before the T wave
    }
    QtMeasurement? qt = QtInterval.measure(x, 81, (70, 92), 1000, fs);
    expect(qt, isNotNull);
    expect(qt!.tPeak, greaterThan(140));   // the T top, not the dip
    expect(qt.qtMs, closeTo((175 - 70) * 4, 20));
  });

  test('QTc: Bazett and Fridericia, both = QT at 60 bpm', () {
    expect(const QtMeasurement(0, 0, 0, 400, 1000, 0.3).bazettMs, closeTo(400, 0.01));
    expect(const QtMeasurement(0, 0, 0, 400, 1000, 0.3).fridericiaMs, closeTo(400, 0.01));
    // 94 bpm, RR 640 ms: 400 / 0.8 = 500, 400 / 0.8618 = 464
    expect(const QtMeasurement(0, 0, 0, 400, 640, 0.3).bazettMs, closeTo(500, 0.01));
    expect(const QtMeasurement(0, 0, 0, 400, 640, 0.3).fridericiaMs, closeTo(464.2, 0.1));
  });

  test('the zero phase filter keeps a slow wave symmetric, the live filter bends it', () {
    // a slow hump (like a T wave, 200 ms) in the middle of 4 s
    List<double> x = [for (int i = 0; i < 1000; i++) exp(-pow((i - 500) / 12, 2).toDouble())];
    int top(List<double> v) => [for (int i = 0; i < v.length; i++) i].reduce((a, b) => v[a] >= v[b] ? a : b);
    // how much the two sides of the hump differ (0 = symmetric, like the input)
    double asymmetry(List<double> v) =>
        [for (int k = 1; k <= 60; k++) (v[500 - k] - v[500 + k]).abs()].reduce(max);
    List<double> zero = ZeroPhaseFilter.apply(x, fs.toDouble());
    expect(top(zero), closeTo(500, 1));
    EkgDisplayFilter live = EkgDisplayFilter(fs.toDouble());
    List<double> bent = [for (double v in x) live.process(v)];
    expect(asymmetry(zero), lessThan(0.01));
    expect(asymmetry(bent), greaterThan(5 * asymmetry(zero)));
  });

  test('the summary of a recording: the QRS from the chart signal, the T end from the measurement one', () {
    List<double> x = [];
    List<int> beats = [];
    for (int k = 0; k < 12; k++) {
      beats.add(x.length + 81);
      x.addAll(beatWith());
    }
    QtSummary? s = QtSummary.analyze(x, x, beats, 1000, fs);
    expect(s, isNotNull);
    expect(s!.qrs, isNotNull);
    expect(s.qt!.qtMs, closeTo(380, 20));
    // the QRS start in the long beat is where the QRS really is: 11 samples before R
    expect(s.r - s.qrs!.$1, closeTo(11, 2));
    expect(QtSummary.analyze(x, x, beats.take(3).toList(), 1000, fs), isNull);   // too few beats
    expect(QrsWidth.minBeats, 5);
  });

  test('the texts: not measured, normal, long', () {
    AppLocalizations pl = lookupAppLocalizations(const Locale('pl'));
    expect(RecordingStatsCard.qtLines(pl, null), isEmpty);
    List<double> x = [];
    List<int> beats = [];
    for (int k = 0; k < 12; k++) {
      beats.add(x.length + 81);
      x.addAll(beatWith());
    }
    QtSummary normal = QtSummary.analyze(x, x, beats, 1000, fs)!;
    List<String> lines = RecordingStatsCard.qtLines(pl, normal);
    expect(lines[0], startsWith('QT 3'));
    expect(lines[1], 'QTc w normie (350–460 ms)');
    // the same QT at 100 bpm: QTc (Bazett) ~490 ms
    expect(RecordingStatsCard.qtLines(pl, QtSummary.analyze(x, x, beats, 600, fs)!)[1], startsWith('Wydłużony QTc'));
    List<double> flat = [];
    for (int k = 0; k < 12; k++) {
      flat.addAll(beatWith(tHeight: 0.05));
    }
    expect(RecordingStatsCard.qtLines(pl, QtSummary.analyze(flat, flat, beats, 1000, fs)!),
        [startsWith('QT: nie zmierzono')]);
  });

  testWidgets('the median beat chart with the QT line, also when the label does not fit on the right', (tester) async {
    for (int tEnd in [165, 248]) {
      await tester.pumpWidget(MaterialApp(
        home: SizedBox(width: 300, height: 140,
            child: MedianBeatChart(beat: beatWith(), qrs: (70, 92), tEnd: tEnd, sampleRateHz: fs)),
      ));
      expect(tester.takeException(), isNull);
    }
  });
}
