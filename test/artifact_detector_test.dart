import 'dart:math';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:ecg_ble_app/artifact_detector.dart';
import 'package:ecg_ble_app/ekg_test_signal.dart';
import 'package:ecg_ble_app/filters/biquad_filter.dart';
import 'package:ecg_ble_app/heart_rate_detector.dart';
import 'package:ecg_ble_app/rr_stats.dart';

const int fs = 250;

// [seconds] of the test EKG (72 bpm, ~1 mV QRS) + [extra](t), filtered like in the app
Float32List ekg(double seconds, {double Function(double t)? extra}) {
  EkgDisplayFilter filter = EkgDisplayFilter(fs.toDouble());
  return Float32List.fromList([
    for (int i = 0; i < seconds * fs; i++)
      filter.process(EkgTestSignal.millivoltsAt(i / fs) + (extra == null ? 0 : extra(i / fs))),
  ]);
}

// is there an artifact over the time [from, to] (in seconds)
bool covers(List<Artifact> artifacts, double from, double to) =>
    artifacts.any((a) => a.start <= from * fs && a.end >= to * fs);

void main() {
  test('a clean recording: no disturbance', () {
    Float32List mv = ekg(60);
    expect(ArtifactDetector.find(mv, HeartRateDetector.findBeats(mv, fs), fs), isEmpty);
  });

  test('a cough: big slow swings between the beats for 1.5 s', () {
    // 20.0 - 21.5 s: 1.5 mV swings at 3 Hz (a cough / a movement of the cable)
    Float32List mv = ekg(60, extra: (t) => t >= 20 && t < 21.5 ? 1.5 * sin(2 * pi * 3 * t) : 0);
    List<Artifact> found = ArtifactDetector.find(mv, HeartRateDetector.findBeats(mv, fs), fs);
    expect(found.length, 1);
    expect(covers(found, 20.2, 21.3), isTrue);
    expect(found.single.end - found.single.start, lessThan(3 * fs));   // not much more than the cough
  });

  test('muscle noise: fast wiggling for 2 s', () {
    Random random = Random(1);
    Float32List mv = ekg(60, extra: (t) => t >= 30 && t < 32 ? 0.5 * (random.nextDouble() - 0.5) : 0);   // 0.5 mV peak to peak
    List<Artifact> found = ArtifactDetector.find(mv, HeartRateDetector.findBeats(mv, fs), fs);
    expect(covers(found, 30.3, 31.7), isTrue);
  });

  test('a premature beat (early and tall) is no disturbance, an impossible extra "beat" is', () {
    // the R waves of the clean test EKG, an extra narrow beat 60 % of the interval after one of them
    Float32List clean = ekg(60);
    List<int> r = HeartRateDetector.findBeats(clean, fs);
    double rr = (r[31] - r[30]) / fs;
    double early = r[30] / fs + 0.6 * rr;   // like a ventricular premature beat: early ...
    double spike(double t, double at, double mv) => mv * exp(-pow((t - at) / 0.012, 2).toDouble());
    // ... and 1.8 x taller than the usual R wave (2026-11-25: such beats were "disturbances")
    Float32List premature = ekg(60, extra: (t) => spike(t, early, 1.8));
    List<int> beats = HeartRateDetector.findBeats(premature, fs);
    expect(beats.any((b) => (b / fs - early).abs() < 0.05), isTrue);   // the detector finds it
    expect(ArtifactDetector.find(premature, beats, fs), isEmpty);
    // the same 0.2 s after an R wave: no heart beats that fast (300 bpm), so it is the disturbance
    double tooSoon = r[30] / fs + 0.2;
    Float32List impossible = ekg(60, extra: (t) => spike(t, tooSoon, 1.8));
    List<Artifact> found = ArtifactDetector.find(impossible, HeartRateDetector.findBeats(impossible, fs), fs);
    expect(found.any((a) => a.contains((tooSoon * fs).round())), isTrue);
  });

  test('the first 3 s are not checked (settling, the detector is learning)', () {
    Float32List mv = ekg(30, extra: (t) => t < 2 ? 2 * sin(2 * pi * 2 * t) : 0);
    expect(ArtifactDetector.find(mv, HeartRateDetector.findBeats(mv, fs), fs), isEmpty);
  });

  test('label: start and length', () {
    expect(artifactLabel(const Artifact(123 * fs, 125 * fs), fs), '2:03 (2 s)');
    expect(artifactLabel(const Artifact(5 * fs, 5 * fs + 50), fs), '0:05 (1 s)');   // at least 1 s
  });

  test('HRV: intervals with a beat inside a disturbance are left out', () {
    List<int> beats = [for (int k = 0; k < 30; k++) fs + k * 200];   // steady 75 bpm
    RrStats clean = RrStats.fromBeats(beats, fs)!;
    RrStats withArtifact = RrStats.fromBeats(beats, fs, artifacts: [Artifact(beats[10] - 10, beats[11] + 10)])!;
    expect(clean.excludedIntervals, 0);
    expect(withArtifact.excludedIntervals, 3);   // 9-10, 10-11, 11-12 touch the beats 10 and 11
    expect(withArtifact.tachogram.length, clean.tachogram.length - 3);
  });
}
