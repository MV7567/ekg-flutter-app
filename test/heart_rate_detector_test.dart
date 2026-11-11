import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:ecg_ble_app/ekg_test_signal.dart';
import 'package:ecg_ble_app/filters/biquad_filter.dart';
import 'package:ecg_ble_app/heart_rate_detector.dart';

const int fs = 250;

// runs [seconds] of a signal through the display filter and the detector, like the app does
// signal(t) gives mV, returns the detector and how many beats it found
(HeartRateDetector, int) run(double Function(double t) signal, double seconds) {
  EkgDisplayFilter filter = EkgDisplayFilter(fs.toDouble());
  HeartRateDetector detector = HeartRateDetector(fs);
  int beats = 0;
  for (int i = 0; i < seconds * fs; i++) {
    if (detector.addSample(i, filter.process(signal(i / fs)))) beats++;
  }
  return (detector, beats);
}

// the test EKG with another heart rate: time stretched or squeezed
double Function(double) ekgAt(double bpm) =>
    (t) => EkgTestSignal.millivoltsAt(t * bpm / EkgTestSignal.beatsPerMinute);

void main() {
  test('test signal 72 bpm, with DC, wander and 50 Hz hum', () {
    var (detector, beats) = run(EkgTestSignal.millivoltsAt, 30);
    expect(detector.bpm, 72);
    // 30 s at 72 bpm = 36 beats, the first 2 s are learning
    expect(beats, inInclusiveRange(32, 36));
  });

  test('slow and fast heart: 45 and 150 bpm', () {
    expect(run(ekgAt(45), 30).$1.bpm, closeTo(45, 1));
    expect(run(ekgAt(150), 30).$1.bpm, closeTo(150, 1));
  });

  test('upside down EKG (RA and LA swapped) gives the same rate', () {
    var (detector, _) = run((t) => -EkgTestSignal.millivoltsAt(t), 30);
    expect(detector.bpm, 72);
  });

  test('T wave is not counted as a second beat', () {
    var (_, beats) = run(EkgTestSignal.millivoltsAt, 60);
    expect(beats, lessThanOrEqualTo(72));   // 72 real beats in 60 s, not ~144
  });

  test('random noise, no EKG: no heart rate', () {
    Random random = Random(1);   // fixed seed, the same "random" numbers every run
    var (detector, _) = run((t) => 0.01 * (random.nextDouble() - 0.5), 10);
    expect(detector.bpm, anyOf(isNull, lessThan(40)));
  });

  test('slow smooth wave (moving, breathing) is not a heart beat', () {
    // 0.5 mV high, regular, 1 per second, but far too slow for a QRS
    var (detector, beats) = run((t) => 0.5 * sin(2 * pi * 1 * t), 20);
    expect(beats, 0);
    expect(detector.bpm, isNull);
  });

  test('flat line after the beats (electrode off): bpm becomes unknown after 3 s', () {
    HeartRateDetector detector = HeartRateDetector(fs);
    EkgDisplayFilter filter = EkgDisplayFilter(fs.toDouble());
    int i = 0;
    for (; i < 10 * fs; i++) {
      detector.addSample(i, filter.process(EkgTestSignal.millivoltsAt(i / fs)));
    }
    expect(detector.bpm, 72);
    for (; i < 15 * fs; i++) {
      detector.addSample(i, filter.process(0));
    }
    expect(detector.bpm, isNull);
  });

  test('reset forgets everything', () {
    var (detector, _) = run(EkgTestSignal.millivoltsAt, 10);
    detector.reset();
    expect(detector.bpm, isNull);
  });

  // ---- whole recordings ----

  test('findBeats: every R wave of a 30 s recording, at the right place', () {
    EkgDisplayFilter filter = EkgDisplayFilter(fs.toDouble());
    List<double> filtered = [for (int i = 0; i < 30 * fs; i++) filter.process(EkgTestSignal.millivoltsAt(i / fs))];
    List<int> beats = HeartRateDetector.findBeats(filtered, fs);
    expect(beats.length, inInclusiveRange(32, 36));
    // the R wave of the test signal is 0.23 s into every beat of 0.833 s
    for (int beat in beats) {
      double intoBeat = (beat / fs) % (60 / 72);
      expect(intoBeat, closeTo(0.23, 0.02));
    }
    expect(HeartRateDetector.averageBpm(beats, fs), 72);
  });

  test('averageBpm: a missed beat (double interval) does not pull it down', () {
    // beats every 250 samples (60 bpm), one missing at 1000
    List<int> beats = [0, 250, 500, 750, 1250, 1500, 1750, 2000];
    expect(HeartRateDetector.averageBpm(beats, fs), 60);
  });

  test('averageBpm: too few beats -> null', () {
    expect(HeartRateDetector.averageBpm([0, 250, 500], fs), isNull);   // only 2 intervals
    expect(HeartRateDetector.averageBpm([], fs), isNull);
  });

  test('bpmBetween: only the beats inside the window', () {
    // 60 bpm for the first 10 s, then 120 bpm
    List<int> beats = [for (int i = 0; i < 10; i++) i * 250, for (int i = 0; i < 20; i++) 2500 + i * 125];
    expect(HeartRateDetector.bpmBetween(beats, 0, 1250, fs), 60);
    expect(HeartRateDetector.bpmBetween(beats, 2500, 3750, fs), 120);
  });
}
