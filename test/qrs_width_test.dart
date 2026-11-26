import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:ecg_ble_app/qrs_width.dart';

const int fs = 250;   // 1 sample = 4 ms

// a flat line with one QRS of a known width: straight lines through the points
// (start 0) -> Q -0.1 mV -> R 1 mV -> S -0.25 mV -> (end 0), at fractions of the width
// returns the signal and where R is
(List<double>, int) oneQrs(double widthMs, {int length = 250, int start = 100, double amplitude = 1}) {
  int w = (widthMs / 1000 * fs).round();
  List<(double, double)> points = [(0, 0), (0.2, -0.1), (0.45, 1), (0.75, -0.25), (1, 0)];
  List<double> x = List.filled(length, 0);
  for (int i = 0; i <= w; i++) {
    double f = i / w;
    for (int k = 1; k < points.length; k++) {
      if (f <= points[k].$1) {
        var (f0, y0) = points[k - 1];
        var (f1, y1) = points[k];
        x[start + i] = amplitude * (y0 + (y1 - y0) * (f - f0) / (f1 - f0));
        break;
      }
    }
  }
  return (x, start + (0.45 * w).round());
}

void main() {
  test('a normal QRS of 80 ms and a wide one of 140 ms are measured within one sample', () {
    for (double width in [80, 100, 140]) {
      var (x, r) = oneQrs(width);
      expect(QrsWidth.widthMs(x, r, fs), closeTo(width, 8), reason: '$width ms');
    }
    expect(QrsWidth.widthMs(oneQrs(140).$1, oneQrs(140).$2, fs)!, greaterThanOrEqualTo(QrsWidth.wideMs));
    expect(QrsWidth.widthMs(oneQrs(90).$1, oneQrs(90).$2, fs)!, lessThan(QrsWidth.wideMs));
  });

  test('the size of the QRS does not matter (the limit is relative to its own steepest slope)', () {
    var (x, r) = oneQrs(100, amplitude: 0.2);   // a small QRS, e.g. from the wrists
    expect(QrsWidth.widthMs(x, r, fs), closeTo(100, 8));
  });

  test('a slow T wave after the QRS is not part of it', () {
    var (x, r) = oneQrs(90);
    // a 0.3 mV T wave of 160 ms starting 40 ms after the QRS: its slope is far under 8 %
    int tStart = 100 + 23 + 10;
    for (int i = 0; i < 40; i++) {
      x[tStart + i] += 0.3 * sin(pi * i / 40);
    }
    expect(QrsWidth.widthMs(x, r, fs), closeTo(90, 8));
  });

  test('too close to the start or the end of the recording: not measured', () {
    var (x, r) = oneQrs(90, length: 140, start: 10);
    expect(QrsWidth.measure(x, r, fs), isNull);
  });

  test('the median beat: noise cancels out, one odd beat does not change it', () {
    Random random = Random(1);
    List<double> x = [];
    List<int> beats = [];
    for (int k = 0; k < 15; k++) {
      // beat 7 is wide (an extra beat that was not left out), all others 90 ms
      var (one, r) = oneQrs(k == 7 ? 160 : 90, length: 200, start: 60);
      beats.add(x.length + r);
      x.addAll([for (double v in one) v + 0.03 * (random.nextDouble() - 0.5)]);
    }
    expect(QrsWidth.typicalMs(x, beats, fs), closeTo(90, 8));
    expect(QrsWidth.typicalMs(x, beats.take(4).toList(), fs), isNull);   // fewer than 5 beats
  });

  test('regular beats: no premature beat, no beat next to a gap, nothing given in skip', () {
    // intervals 200 samples, the beat at index 5 comes early (130 + 270)
    List<int> beats = [0];
    for (int rr in [200, 200, 200, 200, 130, 270, 200, 200, 200, 600, 200, 200]) {
      beats.add(beats.last + rr);
    }
    List<int> regular = QrsWidth.regularBeats(beats);
    expect(regular, isNot(contains(beats[5])));    // the early one
    expect(regular, isNot(contains(beats[4])));    // before it: its next interval is short
    expect(regular, isNot(contains(beats[6])));    // after it: the pause
    expect(regular, isNot(contains(beats[9])));    // before the gap (a missed beat)
    expect(regular, contains(beats[2]));
    expect(QrsWidth.regularBeats(beats, skip: {beats[2]}), isNot(contains(beats[2])));
    expect(QrsWidth.regularBeats(beats, disturbed: (s) => s == beats[3]), isNot(contains(beats[3])));
  });

  test('summary of a recording: the median beat and the typical width', () {
    // 12 normal beats of 90 ms every 200 samples, beat 8 comes early and is wide (150 ms)
    List<double> x = [];
    List<int> beats = [];
    for (int k = 0; k < 12; k++) {
      var (one, r) = oneQrs(k == 8 ? 150 : 90, length: k == 7 ? 140 : (k == 8 ? 260 : 200), start: 50);
      beats.add(x.length + r);
      x.addAll(one);
    }
    QrsSummary s = QrsSummary.analyze(x, beats, fs, premature: [beats[8]]);
    expect(s.typicalMs(fs), closeTo(90, 8));
    expect(s.medianBeat, isNotNull);
    expect(s.beatCount, greaterThanOrEqualTo(QrsWidth.minBeats));

    // too few beats: no median beat
    QrsSummary none = QrsSummary.analyze(x, beats.take(3).toList(), fs);
    expect(none.medianBeat, isNull);
    expect(none.typicalMs(fs), isNull);
  });

  test('beats of changing shape (like lead III with deep breathing): no QRS width, no QT', () {
    // 12 beats every 200 samples; every other one with a much smaller R and a deeper S
    // (the shape turns over with the breathing): the median of such beats is no real beat
    List<double> same = [], changing = [];
    List<int> beats = [];
    for (int k = 0; k < 12; k++) {
      var (one, r) = oneQrs(90, length: 200, start: 50);
      beats.add(same.length + r);
      same.addAll(one);
      changing.addAll(k.isOdd ? [for (double v in one) v < 0 ? 3 * v : 0.2 * v] : one);
    }
    QrsSummary ok = QrsSummary.analyze(same, beats, fs);
    expect(ok.variableShape, isFalse);
    expect(ok.typicalMs(fs), closeTo(90, 8));
    QrsSummary bad = QrsSummary.analyze(changing, beats, fs);
    expect(bad.variableShape, isTrue);
    expect(bad.typicalMs(fs), isNull);
    expect(QrsWidth.shapeAgreement(changing, beats.sublist(1, 11), bad.medianBeat!, bad.r, fs)!,
        lessThan(QrsWidth.minShapeAgreement));
  });
}
